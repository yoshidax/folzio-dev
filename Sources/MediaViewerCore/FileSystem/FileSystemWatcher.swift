import CoreServices
import Foundation

public protocol FileSystemWatching: Sendable {
    /// 監視対象を差し替える。`folders` は直下の追加・削除・名前変更が起きたフォルダの URL を流す。
    /// `subtrees` のフォルダは配下のすべての階層を監視し、変更のあったパスの親フォルダを、渡された起点の URL に
    /// 相対の要素をつないだ形で流す。起点自身またはその祖先の削除・移動は起点の URL を流す。配下でも隠しフォルダの中の変更は流さない
    /// （検索結果の整理、FR-087・R38）
    func watch(_ folders: Set<URL>, subtrees: Set<URL>)
    var events: AsyncStream<Set<URL>> { get }
}

extension FileSystemWatching {
    public func watch(_ folders: Set<URL>) {
        watch(folders, subtrees: [])
    }
}

public final class FileSystemWatcher: FileSystemWatching, @unchecked Sendable {
    private static let debounceInterval: CFTimeInterval = 0.3
    /// 変更が続いても、最初の未送出の変更からこの時間で必ず送る（FR-054・042・087 の通知を止めない。R38）
    private static let maxLatency: CFTimeInterval = 1.0

    /// 配下のすべての階層を監視する起点。`url` は渡された形（流すときに使う）、`realComponents` は FSEvents が返す実体のパスの要素
    private struct Subtree: Equatable {
        let url: URL
        let realComponents: [String]
    }

    private let queue = DispatchQueue(label: "MediaViewerCore.FileSystemWatcher")
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let eventStream: AsyncStream<Set<URL>>
    private let continuation: AsyncStream<Set<URL>>.Continuation

    private var watchedFolders: [String: URL] = [:]
    private var watchedSubtrees: [Subtree] = []
    /// `subtrees` の配下のフォルダ（実体のパス）ごとの isHidden。`subtrees` を差し替えたら捨てる
    private var hiddenFolderCache: [String: Bool] = [:]
    private var pendingFolders: Set<URL> = []
    private var pendingSince: DispatchTime?
    private var debounceWorkItem: DispatchWorkItem?
    /// `folders` 用のストリーム。WatchRoot を付けない（bug: fsevents-watchroot-fd-exhaustion）
    private var folderStream: FSEventStreamRef?
    /// `subtrees` 用のストリーム。起点自身と祖先の移動・削除を受け取るため WatchRoot を付ける（R38）
    private var subtreeStream: FSEventStreamRef?

    public init() {
        let (eventStream, continuation) = AsyncStream.makeStream(
            of: Set<URL>.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        self.eventStream = eventStream
        self.continuation = continuation
        queue.setSpecific(key: queueKey, value: 1)
    }

    deinit {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            stopStream()
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
            continuation.finish()
        } else {
            queue.sync {
                stopStream()
                debounceWorkItem?.cancel()
                debounceWorkItem = nil
                continuation.finish()
            }
        }
    }

    public var events: AsyncStream<Set<URL>> {
        eventStream
    }

    public func watch(_ folders: Set<URL>, subtrees: Set<URL>) {
        let normalized = Set(folders.map(\.standardizedFileURL))
        // subtrees は渡された形のまま持つ。standardizedFileURL は存在するパスの /private を外すため使わない（R38）
        let normalizedSubtrees = subtrees
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            applyFolders(normalized, subtrees: normalizedSubtrees)
        } else {
            queue.sync {
                applyFolders(normalized, subtrees: normalizedSubtrees)
            }
        }
    }

    // MARK: - State (queue-confined)

    private static func key(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// 実体のパス（`realpath(3)`。FSEvents が返す `/private/var/...` の形）の要素。失敗したら `key(for:)` のパス。
    /// `standardizedFileURL` は存在するパスの `/private` を外し、消えたパスとの比較が崩れるため通さない
    private static func realComponents(of url: URL) -> [String] {
        let path: String
        if let resolved = realpath(url.path, nil) {
            path = String(cString: resolved)
            free(resolved)
        } else {
            path = key(for: url)
        }
        return URL(fileURLWithPath: path).pathComponents
    }

    private func applyFolders(_ folders: Set<URL>, subtrees: Set<URL>) {
        let mapping = Dictionary(
            folders.map { (Self.key(for: $0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let newSubtrees = subtrees
            .sorted { $0.path < $1.path }
            .map { Subtree(url: $0, realComponents: Self.realComponents(of: $0)) }
        let foldersChanged = mapping != watchedFolders
        let subtreesChanged = newSubtrees != watchedSubtrees
        guard foldersChanged || subtreesChanged else { return }

        watchedFolders = mapping
        if subtreesChanged {
            hiddenFolderCache.removeAll()
        }
        watchedSubtrees = newSubtrees
        pendingFolders.removeAll()
        pendingSince = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        // 変わった側だけを作り直す。ツリーの操作のたびに起点のストリームを作り直さない
        if foldersChanged {
            rebuildFolderStream()
        }
        if subtreesChanged {
            rebuildSubtreeStream()
        }
    }

    /// WatchRoot は監視するパスの祖先ごとにディスクリプタを開く（1パスあたりパスの深さの分）。ツリーで見えている行を
    /// すべて監視する `folders` に付けると、GUI アプリの上限（256）を使い切るため付けない。`folders` の変更は親フォルダの
    /// 変更として届く（bug: fsevents-watchroot-fd-exhaustion）
    private func rebuildFolderStream() {
        Self.stop(&folderStream)
        let paths = Set(watchedFolders.values.map(\.path))
        folderStream = makeStream(paths: paths, watchesRoot: false)
    }

    private func rebuildSubtreeStream() {
        Self.stop(&subtreeStream)
        var paths: Set<String> = []
        for subtree in watchedSubtrees {
            paths.insert(subtree.url.path)
            paths.insert(NSString.path(withComponents: subtree.realComponents))
        }
        // WatchRoot: 起点自身とその祖先の移動・削除も受け取る（R38）
        subtreeStream = makeStream(paths: paths, watchesRoot: true)
    }

    private func makeStream(paths pathSet: Set<String>, watchesRoot: Bool) -> FSEventStreamRef? {
        guard !pathSet.isEmpty else { return nil }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let paths = Array(pathSet) as CFArray
        var flags = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        if watchesRoot {
            flags |= kFSEventStreamCreateFlagWatchRoot
        }
        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fileSystemWatcherCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.debounceInterval,
            FSEventStreamCreateFlags(flags)
        ) else {
            return nil
        }

        FSEventStreamSetDispatchQueue(newStream, queue)
        guard FSEventStreamStart(newStream) else {
            FSEventStreamInvalidate(newStream)
            FSEventStreamRelease(newStream)
            return nil
        }
        return newStream
    }

    private func stopStream() {
        Self.stop(&folderStream)
        Self.stop(&subtreeStream)
    }

    private static func stop(_ stream: inout FSEventStreamRef?) {
        guard let current = stream else { return }
        FSEventStreamStop(current)
        FSEventStreamInvalidate(current)
        FSEventStreamRelease(current)
        stream = nil
    }

    fileprivate func handleEventPaths(_ rawPaths: UnsafeMutableRawPointer, count: Int) {
        guard count > 0 else { return }
        let paths = unsafeBitCast(rawPaths, to: NSArray.self) as? [String] ?? []
        guard !paths.isEmpty else { return }

        var changed: Set<URL> = []
        for path in paths.prefix(count) {
            let eventURL = URL(fileURLWithPath: path)
            let parent = eventURL.deletingLastPathComponent()
            if let watched = watchedFolders[Self.key(for: parent)] {
                changed.insert(watched)
            }
            if !watchedSubtrees.isEmpty {
                changed.formUnion(subtreeFolders(forEventAt: eventURL))
            }
        }
        guard !changed.isEmpty else { return }
        scheduleEmit(changed)
    }

    /// `subtrees` の起点以下のイベントなら、変更のあったパスの親フォルダを、渡された起点の URL に相対の要素をつないで返す。
    /// 起点自身・祖先の変更は起点の URL。起点から親までに隠しフォルダを含むものは捨てる（R38）
    private func subtreeFolders(forEventAt eventURL: URL) -> [URL] {
        // FSEvents のパスは実体のパス（`.`・`..` を含まない）のため、standardizedFileURL を通さずに要素で比べる
        let eventComponents = eventURL.pathComponents
        let parentComponents = Array(eventComponents.dropLast())
        var result: [URL] = []
        for subtree in watchedSubtrees {
            let real = subtree.realComponents
            if real.starts(with: eventComponents) || subtree.url.pathComponents.starts(with: eventComponents) {
                result.append(subtree.url)
                continue
            }
            guard parentComponents.starts(with: real) else { continue }
            let relative = Array(parentComponents.dropFirst(real.count))
            guard !containsHiddenFolder(relative, under: real) else { continue }
            result.append(relative.reduce(subtree.url) { $0.appendingPathComponent($1, isDirectory: true) })
        }
        return result
    }

    private func containsHiddenFolder(_ relative: [String], under real: [String]) -> Bool {
        guard !relative.contains(where: { $0.hasPrefix(".") }) else { return true }
        var components = real
        for name in relative {
            components.append(name)
            let path = NSString.path(withComponents: components)
            let hidden: Bool
            if let cached = hiddenFolderCache[path] {
                hidden = cached
            } else {
                hidden = (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true
                hiddenFolderCache[path] = hidden
            }
            if hidden { return true }
        }
        return false
    }

    private func scheduleEmit(_ folders: Set<URL>) {
        pendingFolders.formUnion(folders)
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.emitPending()
        }
        debounceWorkItem = item
        let now = DispatchTime.now()
        let since = pendingSince ?? now
        pendingSince = since
        let deadline = min(now + Self.debounceInterval, since + Self.maxLatency)
        queue.asyncAfter(deadline: deadline, execute: item)
    }

    private func emitPending() {
        debounceWorkItem = nil
        pendingSince = nil
        let batch = pendingFolders
        pendingFolders.removeAll()
        guard !batch.isEmpty else { return }
        continuation.yield(batch)
    }
}

private func fileSystemWatcherCallback(
    _ stream: ConstFSEventStreamRef,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientInfo else { return }
    let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
    watcher.handleEventPaths(eventPaths, count: numEvents)
}
