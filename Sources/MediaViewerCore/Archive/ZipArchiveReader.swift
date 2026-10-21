import Foundation

/// zip の読み取り器（FR-068〜075、research.md R22・R24）
public protocol ArchiveReading: Sendable {
    /// 中央ディレクトリを読んで索引を作る。UI スレッドで呼ばない（R22）
    func open(_ archive: URL) async throws(ArchiveError) -> ArchiveIndex
    /// 項目全体を読む（画像用）。展開後のサイズが limit を超えるなら `.tooLarge`
    func data(for entryURL: URL, limit: Int) async throws(ArchiveError) -> Data
    /// 項目の範囲読み出し（動画用、R25）。暗号化・非対応方式なら失敗する。UI スレッドで呼ばない
    func stream(for entryURL: URL) async throws(ArchiveError) -> ArchiveEntryStream
    /// zip ファイルのいまの同一性。消えていれば nil
    func identity(of archive: URL) -> ArchiveIdentity?
}

/// 自前の zip 読み取り器。ファイル記述子への `pread` だけで読み、zip 全体を読み込まない・メモリマップしない・一時ファイルを作らない。
/// 最後に開いた 2 つの zip の索引と記述子をパスをキーに覚え、`data(for:)` で項目を引く。
public final class ZipArchiveReader: ArchiveReading, @unchecked Sendable {
    /// 覚えておく zip の数
    private static let cacheLimit = 2
    /// 中央ディレクトリとして読み込む大きさの上限。これを超えるものは壊れているとみなす
    private static let maxCentralDirectoryBytes: UInt64 = 256 * 1024 * 1024
    private static let ioChunkSize = 1 << 20
    /// deflate の最大圧縮率（約 1032 倍）より大きく食い違うサイズは壊れているとみなす
    private static let maxInflateRatio: UInt64 = 1100

    private final class State {
        let index: ArchiveIndex
        let file: ArchiveFile
        /// 項目のパス → データの開始位置。初めて読むときに1回だけ求める
        var dataOffsets: [String: UInt64] = [:]

        init(index: ArchiveIndex, file: ArchiveFile) {
            self.index = index
            self.file = file
        }
    }

    private let lock = NSLock()
    /// 新しい順
    private var states: [(key: String, state: State)] = []

    public init() {}

    // MARK: - ArchiveReading

    public func open(_ archive: URL) async throws(ArchiveError) -> ArchiveIndex {
        try await runDetached { [self] () throws(ArchiveError) -> ArchiveIndex in
            try openSynchronously(archive).index
        }
    }

    public func data(for entryURL: URL, limit: Int) async throws(ArchiveError) -> Data {
        try await runDetached { [self] () throws(ArchiveError) -> Data in
            try readEntry(entryURL, limit: limit)
        }
    }

    public func stream(for entryURL: URL) async throws(ArchiveError) -> ArchiveEntryStream {
        try await runDetached { [self] () throws(ArchiveError) -> ArchiveEntryStream in
            try makeStream(entryURL)
        }
    }

    public func identity(of archive: URL) -> ArchiveIdentity? {
        ArchiveFile.currentIdentity(of: archive)
    }

    // MARK: - 実行

    /// 重い処理を UI スレッドの外（デタッチしたタスク）で行う。呼び出し側のキャンセルは処理に伝える
    private func runDetached<T: Sendable>(
        _ work: @escaping @Sendable () throws(ArchiveError) -> T
    ) async throws(ArchiveError) -> T {
        let task = Task.detached(priority: .userInitiated) { () -> Result<T, ArchiveError> in
            do throws(ArchiveError) {
                return .success(try work())
            } catch {
                return .failure(error)
            }
        }
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        return try result.get()
    }

    // MARK: - 開く

    private func openSynchronously(_ archive: URL) throws(ArchiveError) -> State {
        let file = try ArchiveFile.open(archive)
        let fileSize = file.size
        guard fileSize >= UInt64(ZipStructure.endOfCentralDirectorySize) else { throw .notAZip }

        let tailLength = Int(min(fileSize, UInt64(ZipStructure.maxEndSearchBytes)))
        let tail = try file.read(at: fileSize - UInt64(tailLength), length: tailLength)
        guard tail.count == tailLength else { throw .notAZip }
        let end = try ZipStructure.endOfCentralDirectory(inTail: tail, fileSize: fileSize)

        let location = try centralDirectoryLocation(of: end, in: file)
        guard location.size <= Self.maxCentralDirectoryBytes else {
            throw .corrupted("中央ディレクトリが大きすぎます")
        }
        let directory = try file.read(at: location.offset, length: Int(location.size))
        guard UInt64(directory.count) == location.size else { throw .notAZip }

        let entries = try ZipStructure.centralDirectoryEntries(directory, count: location.entryCount)
        let index = ArchiveIndex(archive: archive, identity: file.identity, centralEntries: entries)
        let state = State(index: index, file: file)
        remember(state, forKey: archive.path)
        return state
    }

    /// ZIP64 なら、ロケータから ZIP64 終端レコードを辿って中央ディレクトリの場所を求める
    private func centralDirectoryLocation(
        of end: ZipStructure.EndOfCentralDirectory,
        in file: ArchiveFile
    ) throws(ArchiveError) -> ZipStructure.CentralDirectoryLocation {
        guard end.needsZip64 else { return end.location }

        let locatorSize = UInt64(ZipStructure.zip64LocatorSize)
        var zip64Offset: UInt64?
        if end.recordOffset >= locatorSize {
            let bytes = try file.read(at: end.recordOffset - locatorSize, length: ZipStructure.zip64LocatorSize)
            do throws(ArchiveError) {
                zip64Offset = try ZipStructure.zip64Locator(bytes)
            } catch {
                // ロケータの署名がない: 項目数だけが 0xFFFF の通常の zip かもしれない
                if error != .notAZip { throw error }
            }
        }
        guard let zip64Offset else {
            if end.location.size == 0xFFFF_FFFF || end.location.offset == 0xFFFF_FFFF { throw .notAZip }
            guard end.location.offset + end.location.size <= end.recordOffset else { throw .notAZip }
            return end.location
        }

        let recordSize = UInt64(ZipStructure.zip64EndOfCentralDirectorySize)
        let (recordEnd, overflow) = zip64Offset.addingReportingOverflow(recordSize)
        guard !overflow, recordEnd <= file.size else { throw .notAZip }
        let record = try file.read(at: zip64Offset, length: ZipStructure.zip64EndOfCentralDirectorySize)
        return try ZipStructure.zip64EndOfCentralDirectory(record, fileSize: file.size)
    }

    private func remember(_ state: State, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        states.removeAll { $0.key == key }
        states.insert((key: key, state: state), at: 0)
        if states.count > Self.cacheLimit { states.removeLast(states.count - Self.cacheLimit) }
    }

    /// 覚えている zip を返す。なければ開き直す
    private func state(for archive: URL) throws(ArchiveError) -> State {
        let key = archive.path
        lock.lock()
        if let position = states.firstIndex(where: { $0.key == key }) {
            let found = states.remove(at: position)
            states.insert(found, at: 0)
            lock.unlock()
            return found.state
        }
        lock.unlock()
        return try openSynchronously(archive)
    }

    // MARK: - 項目を読む

    /// URL の項目を索引から引く。暗号化・非対応の方式はここで弾く
    private func locateEntry(_ entryURL: URL) throws(ArchiveError) -> (state: State, entry: ArchiveEntry) {
        guard let parsed = ArchiveURL.parse(entryURL), !parsed.isParentLink else {
            throw .corrupted("項目の場所が不正です")
        }
        let state = try state(for: parsed.archive)
        guard let entry = state.index.entry(at: parsed.path), !entry.isDirectory else {
            throw .corrupted("zip の中に項目が見つかりません")
        }

        switch entry.readability {
        case .encrypted: throw .entryEncrypted
        case .unsupportedMethod: throw .unsupportedMethod(entry.method)
        case .readable: break
        }
        return (state, entry)
    }

    /// 範囲読み出し用のストリームを作る。サイズの食い違いは `data(for:limit:)` と同じ基準で壊れているとみなす
    private func makeStream(_ entryURL: URL) throws(ArchiveError) -> ArchiveEntryStream {
        let (state, entry) = try locateEntry(entryURL)
        try validateSizes(of: entry)
        let start = try dataOffset(of: entry, in: state)
        return ArchiveEntryStream(
            file: state.file, dataOffset: start, isStored: entry.method == 0,
            compressedSize: entry.compressedSize, uncompressedSize: entry.uncompressedSize
        )
    }

    /// 格納方式に対して展開後のサイズが食い違っていないか
    private func validateSizes(of entry: ArchiveEntry) throws(ArchiveError) {
        if entry.method == 0 {
            guard entry.uncompressedSize <= entry.compressedSize else {
                throw .corrupted("項目のサイズが一致しません")
            }
            return
        }
        let (limitBytes, overflow) = entry.compressedSize.multipliedReportingOverflow(by: Self.maxInflateRatio)
        guard overflow || entry.uncompressedSize <= limitBytes + 1024 else {
            throw .corrupted("項目のサイズが一致しません")
        }
    }

    private func readEntry(_ entryURL: URL, limit: Int) throws(ArchiveError) -> Data {
        let (state, entry) = try locateEntry(entryURL)
        guard limit >= 0, entry.uncompressedSize <= UInt64(limit) else { throw .tooLarge }
        guard entry.uncompressedSize > 0 else { return Data() }
        guard entry.uncompressedSize <= UInt64(Int.max) else { throw .tooLarge }
        let expected = Int(entry.uncompressedSize)

        let start = try dataOffset(of: entry, in: state)
        let file = state.file

        if entry.method == 0 {
            try validateSizes(of: entry)
            return try Self.makeData(count: expected) { buffer throws(ArchiveError) in
                var done = 0
                while done < buffer.count {
                    try Self.checkCancellation()
                    let length = min(Self.ioChunkSize, buffer.count - done)
                    let slice = UnsafeMutableRawBufferPointer(rebasing: buffer[done..<done + length])
                    guard try file.read(into: slice, at: start + UInt64(done)) == length else {
                        throw .corrupted("項目のデータが途中で終わっています")
                    }
                    done += length
                }
            }
        }

        try validateSizes(of: entry)
        let cursor = InflateCursor(file: file, dataOffset: start, compressedSize: entry.compressedSize)
        return try Self.makeData(count: expected) { buffer throws(ArchiveError) in
            var done = 0
            while done < buffer.count {
                try Self.checkCancellation()
                let length = min(Self.ioChunkSize, buffer.count - done)
                let slice = UnsafeMutableRawBufferPointer(rebasing: buffer[done..<done + length])
                let produced = try cursor.read(into: slice, maxLength: length)
                guard produced > 0 else { throw .corrupted("圧縮データが途中で終わっています") }
                done += produced
            }
        }
    }

    /// 項目のデータの開始位置。ローカルヘッダを読んで求め、項目ごとに覚える
    private func dataOffset(of entry: ArchiveEntry, in state: State) throws(ArchiveError) -> UInt64 {
        lock.lock()
        let known = state.dataOffsets[entry.path]
        lock.unlock()
        if let known { return known }

        let header = try state.file.read(at: entry.localHeaderOffset, length: ZipStructure.localHeaderSize)
        let start = try ZipStructure.dataOffset(localHeader: header, localHeaderOffset: entry.localHeaderOffset)
        let fileSize = state.file.size
        guard start <= fileSize, entry.compressedSize <= fileSize - start else {
            throw .corrupted("項目のデータがファイルの外にあります")
        }
        lock.lock()
        state.dataOffsets[entry.path] = start
        lock.unlock()
        return start
    }

    private static func checkCancellation() throws(ArchiveError) {
        if Task.isCancelled { throw .corrupted("読み込みを中止しました") }
    }

    /// `count` バイトの領域を用意して `fill` で埋め、`Data` にする（コピーしない）
    private static func makeData(
        count: Int,
        _ fill: (UnsafeMutableRawBufferPointer) throws(ArchiveError) -> Void
    ) throws(ArchiveError) -> Data {
        guard count > 0 else { return Data() }
        guard let pointer = malloc(count) else { throw .tooLarge }
        do {
            try fill(UnsafeMutableRawBufferPointer(start: pointer, count: count))
        } catch {
            free(pointer)
            throw error
        }
        return Data(bytesNoCopy: pointer, count: count, deallocator: .free)
    }
}
