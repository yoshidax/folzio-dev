import Foundation

/// zip の中の項目の任意範囲の読み出し（FR-072、research.md R25）。永続化しない・一時ファイルを作らない。
/// 無圧縮は要求範囲を `pread` で直接読む。deflate は 1MB 単位のチャンクを LRU キャッシュに置き、
/// 無いチャンクは最大 2 本の `InflateCursor` のうち手前にいるものを進めて作る。
/// メモリは項目のサイズに依存しない（キャッシュ 32MB + カーソル 2 本 + 応答中のチャンク）。
/// `ArchiveFile` を保持するので、zip を閉じた後も読み出せる。1回の `read` ごとに `NSLock` で直列化する。
public final class ArchiveEntryStream: @unchecked Sendable {
    private static let chunkSize = 1 << 20
    private static let storedIOChunkSize = 512 * 1024
    private static let maxCursors = 2

    /// 展開後のサイズ
    public let length: UInt64

    private let file: ArchiveFile
    private let dataOffset: UInt64
    private let isStored: Bool
    private let compressedSize: UInt64

    private let lock = NSLock()
    /// 使った順（先頭が最も古い）
    private var cursors: [InflateCursor] = []
    private var chunks: [Int: Data] = [:]
    /// チャンク番号。先頭が最も古い
    private var chunkOrder: [Int] = []
    private var cachedBytes = 0

    init(file: ArchiveFile, dataOffset: UInt64, isStored: Bool, compressedSize: UInt64, uncompressedSize: UInt64) {
        self.file = file
        self.dataOffset = dataOffset
        self.isStored = isStored
        self.compressedSize = compressedSize
        self.length = uncompressedSize
    }

    /// `offset` から最大 `maxLength` バイトを返す。末尾で打ち切り、末尾以降は空の `Data`
    public func read(offset: UInt64, maxLength: Int) throws(ArchiveError) -> Data {
        guard maxLength > 0, offset < length else { return Data() }
        let count = Int(min(UInt64(maxLength), length - offset))
        lock.lock()
        defer { lock.unlock() }
        return isStored ? try readStored(offset: offset, count: count) : try readDeflated(offset: offset, count: count)
    }

    // MARK: - 無圧縮

    private func readStored(offset: UInt64, count: Int) throws(ArchiveError) -> Data {
        var result = Data(count: count)
        try result.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) throws(ArchiveError) in
            var done = 0
            while done < count {
                let piece = min(Self.storedIOChunkSize, count - done)
                let slice = UnsafeMutableRawBufferPointer(rebasing: buffer[done..<done + piece])
                guard try file.read(into: slice, at: dataOffset + offset + UInt64(done)) == piece else {
                    throw .corrupted("項目のデータが途中で終わっています")
                }
                done += piece
            }
        }
        return result
    }

    // MARK: - deflate

    private func readDeflated(offset: UInt64, count: Int) throws(ArchiveError) -> Data {
        var result = Data()
        result.reserveCapacity(count)
        var position = offset
        let end = offset + UInt64(count)
        while position < end {
            let index = Int(position / UInt64(Self.chunkSize))
            let chunk = try chunk(at: index)
            let chunkStart = UInt64(index) * UInt64(Self.chunkSize)
            let from = Int(position - chunkStart)
            let to = Int(min(UInt64(chunk.count), end - chunkStart))
            guard from < to else { throw .corrupted("圧縮データが途中で終わっています") }
            result.append(chunk.subdata(in: from..<to))
            position = chunkStart + UInt64(to)
        }
        return result
    }

    private func chunk(at index: Int) throws(ArchiveError) -> Data {
        if let cached = chunks[index] {
            touch(index)
            return cached
        }
        let start = UInt64(index) * UInt64(Self.chunkSize)
        let size = Int(min(UInt64(Self.chunkSize), length - start))
        let cursor = cursor(forPosition: start)
        try cursor.skip(to: start)
        guard cursor.position == start else { throw .corrupted("圧縮データが途中で終わっています") }

        var data = Data(count: size)
        try data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) throws(ArchiveError) in
            var done = 0
            while done < size {
                let slice = UnsafeMutableRawBufferPointer(rebasing: buffer[done...])
                let produced = try cursor.read(into: slice, maxLength: size - done)
                guard produced > 0 else { throw .corrupted("圧縮データが途中で終わっています") }
                done += produced
            }
        }
        store(data, at: index)
        return data
    }

    /// 位置が `start` 以下で最も近いカーソルを選ぶ。なければ、空きがあれば新しく作り、なければ最も古いものを先頭へ戻す
    private func cursor(forPosition start: UInt64) -> InflateCursor {
        var best: Int?
        for (offset, cursor) in cursors.enumerated() where cursor.position <= start {
            if best == nil || cursor.position > cursors[best!].position { best = offset }
        }
        let cursor: InflateCursor
        if let best {
            cursor = cursors.remove(at: best)
        } else if cursors.count < Self.maxCursors {
            cursor = InflateCursor(file: file, dataOffset: dataOffset, compressedSize: compressedSize)
        } else {
            cursor = cursors.removeFirst()
            cursor.reset()
        }
        cursors.append(cursor)
        return cursor
    }

    // MARK: - チャンクの LRU

    private func touch(_ index: Int) {
        if let position = chunkOrder.firstIndex(of: index) { chunkOrder.remove(at: position) }
        chunkOrder.append(index)
    }

    private func store(_ data: Data, at index: Int) {
        chunks[index] = data
        cachedBytes += data.count
        touch(index)
        while cachedBytes > MemoryLimits.archiveStreamCacheBytes, chunkOrder.count > 1 {
            let oldest = chunkOrder.removeFirst()
            cachedBytes -= chunks.removeValue(forKey: oldest)?.count ?? 0
        }
    }
}
