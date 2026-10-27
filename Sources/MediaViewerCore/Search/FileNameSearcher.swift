import Foundation

/// 検索起点以下のすべての階層から、名前が一致する対応メディアファイルとフォルダを探す（FR-083・085・139、research.md R1）
public protocol FileNameSearching: Sendable {
    /// 一致したメディアファイルとフォルダを小さな配列（バッチ）で流し、全階層を辿り終えたらストリームを終える。
    /// ストリームの終了（取り消し）で列挙を止める
    func search(_ request: SearchRequest) -> AsyncStream<[MediaFile]>
}

extension FileNameSearching {
    /// 起点そのものを照合しない検索（`matchesRoot: false`）を、新しい記録で始める
    public func search(in root: URL, matching pattern: SearchPattern) -> AsyncStream<[MediaFile]> {
        search(SearchRequest(root: root, pattern: pattern))
    }
}

/// `FileManager` の列挙器でファイル名とフォルダ名を検索する（FR-083・085・139）。
///
/// - 隠しファイル・隠しフォルダ（とその中）・パッケージの中・シンボリックリンクのフォルダの中を辿らない。リンク先がフォルダのリンクも一致の対象にしない
/// - ファイルへのシンボリックリンクは `DirectoryLister` と同じく通常のファイルとして扱い、URL はリンク自身のパスにする
/// - フォルダは、隠し・パッケージ・フォルダへのリンクでなければ名前（「.」を含んでも全体）で照合し、`DirectoryLister` と同じ値の行を返す
/// - ディレクトリは照合の直前に `SearchRequest.visits` へ記録する（ファイルは記録しない）。`matchesRoot` が true のときだけ
///   起点そのものも記録して照合する（FR-105・EC-94）
/// - 読み取り権限のないフォルダは飛ばして続ける。名前が一致すれば行として返す
/// - UI スレッドで列挙しない。zip の中は開かない（`.zip` は対応メディアにもフォルダにも当たらない）
public struct FileNameSearcher: FileNameSearching {
    private let batchSize: Int
    private let batchInterval: Duration

    public init(batchSize: Int = 256, batchInterval: Duration = .milliseconds(100)) {
        self.batchSize = max(1, batchSize)
        self.batchInterval = batchInterval
    }

    public func search(_ request: SearchRequest) -> AsyncStream<[MediaFile]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [MediaFile].self)
        let batchSize = batchSize
        let batchInterval = batchInterval

        let task = Task.detached(priority: .userInitiated) {
            defer { continuation.finish() }
            let root = request.root
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

            if request.matchesRoot, let row = Self.matchedRoot(request: request) {
                pending.append(row)
            }

            while let next = enumerator.nextObject() {
                if Task.isCancelled { return }
                guard let url = next as? URL else { continue }

                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values?.isDirectory == true, values?.isSymbolicLink != true {
                    // 記録は照合の前に行う。記録がなければ、そのディレクトリはまだ照合されていない（R2）
                    request.visits.record(SearchPath.normalized(rebase(url)))
                    if let row = Self.matchedFolder(at: url, pattern: request.pattern, rebase: rebase) {
                        pending.append(row)
                    }
                } else if let file = Self.matchedFile(
                    at: url,
                    values: values,
                    pattern: request.pattern,
                    rebase: rebase
                ) {
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

    /// 列挙器は起点と違う形（`/var/...` の起点に `/private/var/...`、またはその逆）の URL を返すことがあるため、
    /// 結果の URL を渡された起点の形に組み直す。監視（`FileSystemWatching` の subtrees）が流す URL と同じ形に
    /// そろえ、一覧から開いたときの場所を履歴や結果の整理で同じものとして比べられるようにする（R38）
    private static func rebaser(for root: URL) -> @Sendable (URL) -> URL {
        let rootPath = SearchPath.normalized(root)
        guard rootPath != "/" else { return { $0 } }

        // 起点の形（`/var/...`）と、解決した形（`/private/var/...`）に加え、`/private` の有無を入れ替えた形も受け付ける
        var prefixes: Set<String> = []
        func addForms(of path: String) {
            let variants = [path, path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : "/private" + path]
            for variant in variants where variant != "/" {
                prefixes.insert(variant + "/")
            }
        }
        addForms(of: rootPath)
        if let resolved = realpath(rootPath, nil) {
            addForms(of: String(cString: resolved))
            free(resolved)
        }
        prefixes.remove(rootPath + "/")
        let ordered = prefixes.sorted { $0.count > $1.count }
        guard !ordered.isEmpty else { return { $0 } }

        return { url in
            let path = url.path
            for prefix in ordered where path.hasPrefix(prefix) {
                return URL(fileURLWithPath: rootPath + "/" + path.dropFirst(prefix.count), isDirectory: url.hasDirectoryPath)
            }
            return url
        }
    }

    /// `matchesRoot` が true のときに、起点そのものを同じ規則で照合する。隠し属性とパッケージも確かめる（R3）
    private static func matchedRoot(request: SearchRequest) -> MediaFile? {
        let root = request.root
        let values = try? root.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .isPackageKey]
        )
        guard values?.isDirectory == true, values?.isSymbolicLink != true else { return nil }
        request.visits.record(SearchPath.normalized(root))
        guard values?.isHidden != true,
              values?.isPackage != true,
              request.pattern.matches(fileName: root.lastPathComponent) else { return nil }
        return folderRow(at: root)
    }

    /// 名前が一致したディレクトリの行。パッケージは行にしない（FR-083・A-78）。
    /// 一致しないディレクトリには `isPackage` と作成日を問い合わせない（SC-054）
    private static func matchedFolder(
        at url: URL,
        pattern: SearchPattern,
        rebase: (URL) -> URL
    ) -> MediaFile? {
        guard pattern.matches(fileName: url.lastPathComponent) else { return nil }
        guard (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true else { return nil }
        return folderRow(at: rebase(url))
    }

    private static func folderRow(at url: URL) -> MediaFile {
        let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        return DirectoryLister.folderRow(at: url, creationDate: creationDate)
    }

    private static func matchedFile(
        at enumeratedURL: URL,
        values: URLResourceValues?,
        pattern: SearchPattern,
        rebase: (URL) -> URL
    ) -> MediaFile? {
        let url = enumeratedURL
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
