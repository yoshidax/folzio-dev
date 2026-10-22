import Foundation

/// 検索起点以下のすべての階層から、名前が一致する対応メディアファイルを探す（FR-083・085、research.md R36）
public protocol FileNameSearching: Sendable {
    /// 見つかったメディアファイルを小さな配列（バッチ）で流し、全階層を辿り終えたらストリームを終える。
    /// ストリームの終了（取り消し）で列挙を止める
    func search(in root: URL, matching pattern: SearchPattern) -> AsyncStream<[MediaFile]>
}

/// `FileManager` の列挙器でファイル名を検索する（FR-083・085）。
///
/// - 隠しファイル・隠しフォルダ（とその中）・パッケージの中・シンボリックリンクのフォルダの中を辿らない。リンク先がフォルダのリンクも一致の対象にしない
/// - ファイルへのシンボリックリンクは `DirectoryLister` と同じく通常のファイルとして扱い、URL はリンク自身のパスにする
/// - 読み取り権限のないフォルダは飛ばして続ける
/// - UI スレッドで列挙しない。zip の中は開かない（`.zip` は対応メディアに当たらない）
public struct FileNameSearcher: FileNameSearching {
    private let batchSize: Int
    private let batchInterval: Duration

    public init(batchSize: Int = 256, batchInterval: Duration = .milliseconds(100)) {
        self.batchSize = max(1, batchSize)
        self.batchInterval = batchInterval
    }

    public func search(in root: URL, matching pattern: SearchPattern) -> AsyncStream<[MediaFile]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [MediaFile].self)
        let batchSize = batchSize
        let batchInterval = batchInterval

        let task = Task.detached(priority: .userInitiated) {
            defer { continuation.finish() }
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { return }

            let rebase = Self.rebaser(for: root)
            let clock = ContinuousClock()
            var pending: [MediaFile] = []
            var lastYield = clock.now

            func flush() {
                guard !pending.isEmpty else { return }
                continuation.yield(pending)
                pending.removeAll(keepingCapacity: true)
                lastYield = clock.now
            }

            while let next = enumerator.nextObject() {
                if Task.isCancelled { return }
                guard let url = next as? URL else { continue }

                if let file = Self.matchedFile(at: url, pattern: pattern, rebase: rebase) {
                    pending.append(file)
                }
                // 経過時間は列挙の1項目ごとに確かめ、見つかった結果を次の一致や列挙の終わりまで待たせない
                if pending.count >= batchSize || (!pending.isEmpty && clock.now - lastYield >= batchInterval) {
                    flush()
                    // 長い列挙で協調スレッドを占有せず、受け取る側（取り消しを含む）を先に動かす
                    await Task.yield()
                }
            }
            if Task.isCancelled { return }
            flush()
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
        return stream
    }

    /// 列挙器は `/var/...` の起点に `/private/var/...` の URL を返すため、結果の URL を渡された起点の形に組み直す。
    /// 監視（`FileSystemWatching` の subtrees）が流す URL と同じ形にそろえる（R38）
    private static func rebaser(for root: URL) -> @Sendable (URL) -> URL {
        let rootPath = root.standardizedFileURL.path
        guard let resolved = realpath(rootPath, nil) else { return { $0 } }
        let realRootPath = String(cString: resolved)
        free(resolved)
        guard realRootPath != rootPath, realRootPath != "/" else { return { $0 } }
        let prefix = realRootPath + "/"
        return { url in
            let path = url.path
            guard path.hasPrefix(prefix) else { return url }
            return URL(fileURLWithPath: rootPath + "/" + path.dropFirst(prefix.count))
        }
    }

    private static func matchedFile(
        at enumeratedURL: URL,
        pattern: SearchPattern,
        rebase: (URL) -> URL
    ) -> MediaFile? {
        let url = enumeratedURL
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values?.isDirectory == true { return nil }
        guard let kind = MediaKind(fileExtension: url.pathExtension),
              pattern.matches(fileName: url.lastPathComponent) else { return nil }
        if values?.isSymbolicLink == true,
           (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return nil
        }
        return DirectoryLister.mediaFile(at: rebase(url), kind: kind)
    }
}
