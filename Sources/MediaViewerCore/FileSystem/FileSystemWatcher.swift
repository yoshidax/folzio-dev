import CoreServices
import Foundation

public protocol FileSystemWatching: Sendable {
    func watch(_ folders: Set<URL>)
    var events: AsyncStream<Set<URL>> { get }
}

public final class FileSystemWatcher: FileSystemWatching, @unchecked Sendable {
    private static let debounceInterval: CFTimeInterval = 0.3

    private let queue = DispatchQueue(label: "MediaViewerCore.FileSystemWatcher")
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let eventStream: AsyncStream<Set<URL>>
    private let continuation: AsyncStream<Set<URL>>.Continuation

    private var watchedFolders: [String: URL] = [:]
    private var pendingFolders: Set<URL> = []
    private var debounceWorkItem: DispatchWorkItem?
    private var stream: FSEventStreamRef?

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

    public func watch(_ folders: Set<URL>) {
        let normalized = Set(folders.map(\.standardizedFileURL))
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            applyFolders(normalized)
        } else {
            queue.sync {
                applyFolders(normalized)
            }
        }
    }

    // MARK: - State (queue-confined)

    private static func key(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func applyFolders(_ folders: Set<URL>) {
        let mapping = Dictionary(
            folders.map { (Self.key(for: $0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard mapping != watchedFolders else { return }

        watchedFolders = mapping
        pendingFolders.removeAll()
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        rebuildStream()
    }

    private func rebuildStream() {
        stopStream()
        guard !watchedFolders.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let paths = watchedFolders.values.map(\.path) as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        )
        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fileSystemWatcherCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.debounceInterval,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(newStream, queue)
        guard FSEventStreamStart(newStream) else {
            FSEventStreamInvalidate(newStream)
            FSEventStreamRelease(newStream)
            return
        }
        stream = newStream
    }

    private func stopStream() {
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
            let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
            if let watched = watchedFolders[Self.key(for: parent)] {
                changed.insert(watched)
            }
        }
        guard !changed.isEmpty else { return }
        scheduleEmit(changed)
    }

    private func scheduleEmit(_ folders: Set<URL>) {
        pendingFolders.formUnion(folders)
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.emitPending()
        }
        debounceWorkItem = item
        queue.asyncAfter(deadline: .now() + Self.debounceInterval, execute: item)
    }

    private func emitPending() {
        debounceWorkItem = nil
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
