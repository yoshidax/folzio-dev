import FixtureKit
import Foundation
import Testing

@testable import MediaViewerCore

@Suite("FileSystemWatcher")
struct FileSystemWatcherTests {
    @Test("ファイル追加で監視フォルダのイベントが2秒以内に届く")
    func deliversEventForAddedFile() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        let watcher = FileSystemWatcher()
        watcher.watch([folder])
        let (recorder, collector) = startCollector(watcher)
        defer { collector.cancel() }

        try Data("added".utf8).write(to: folder.appendingPathComponent("a.jpg"))

        let (event, observed) = await recorder.waitForEvent(after: 0)
        #expect(
            event != nil,
            "ファイル追加後2秒以内にイベントが届かなかった。observed: \(describe(observed))"
        )
        if let event {
            #expect(
                containsFolder(event, folder),
                "イベントに監視フォルダが含まれない。event: \(describe(event)), folder: \(folder.path)"
            )
        }

        await stopCollector(collector)
    }

    @Test("ファイル名変更で監視フォルダのイベントが2秒以内に届く")
    func deliversEventForRenamedFile() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        let original = folder.appendingPathComponent("a.jpg")
        try Data("renamed".utf8).write(to: original)

        let watcher = FileSystemWatcher()
        watcher.watch([folder])
        let (recorder, collector) = startCollector(watcher)
        defer { collector.cancel() }

        try FileManager.default.moveItem(
            at: original,
            to: folder.appendingPathComponent("b.jpg")
        )

        let (event, observed) = await recorder.waitForEvent(after: 0)
        #expect(
            event != nil,
            "名前変更後2秒以内にイベントが届かなかった。observed: \(describe(observed))"
        )
        if let event {
            #expect(
                containsFolder(event, folder),
                "イベントに監視フォルダが含まれない。event: \(describe(event)), folder: \(folder.path)"
            )
        }

        await stopCollector(collector)
    }

    @Test("ファイル削除で監視フォルダのイベントが2秒以内に届く")
    func deliversEventForDeletedFile() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        let file = folder.appendingPathComponent("a.jpg")
        try Data("deleted".utf8).write(to: file)

        let watcher = FileSystemWatcher()
        watcher.watch([folder])
        let (recorder, collector) = startCollector(watcher)
        defer { collector.cancel() }

        try FileManager.default.removeItem(at: file)

        let (event, observed) = await recorder.waitForEvent(after: 0)
        #expect(
            event != nil,
            "削除後2秒以内にイベントが届かなかった。observed: \(describe(observed))"
        )
        if let event {
            #expect(
                containsFolder(event, folder),
                "イベントに監視フォルダが含まれない。event: \(describe(event)), folder: \(folder.path)"
            )
        }

        await stopCollector(collector)
    }

    @Test("外部変更を BrowserModel の一覧・選択・プレビューに反映する")
    @MainActor
    func browserModelReflectsExternalChanges() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        let a = folder.appendingPathComponent("a.jpg")
        let b = folder.appendingPathComponent("b.jpg")
        let c = folder.appendingPathComponent("c.jpg")
        try ImageFixtures.jpeg(at: a, width: 32, height: 24)
        try ImageFixtures.jpeg(at: b, width: 32, height: 24)

        let suite = "FileSystemWatcherTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(costLimitBytes: 32 * 1024 * 1024),
            settings: SettingsStore(defaults: defaults)
        )

        await model.selectFolder(folder)
        model.select([a], focused: a)

        let becameImage = await waitUntil(timeout: .seconds(2)) {
            if case .image = model.preview { return true }
            return false
        }
        #expect(
            becameImage,
            "a.jpg のプレビューが画像にならなかった。preview: \(describe(model.preview))"
        )

        let watcher = FileSystemWatcher()
        watcher.watch([folder])
        let (recorder, collector) = startCollector(watcher)
        defer { collector.cancel() }

        try FileManager.default.removeItem(at: a)
        try ImageFixtures.jpeg(at: c, width: 32, height: 24)

        let (event, observed) = await recorder.waitForEvent(after: 0)
        #expect(
            event != nil,
            "外部変更後2秒以内にイベントが届かなかった。observed: \(describe(observed))"
        )
        guard let event else {
            await stopCollector(collector)
            return
        }
        #expect(
            containsFolder(event, folder),
            "イベントに監視フォルダが含まれない。event: \(describe(event)), folder: \(folder.path)"
        )

        await model.handleFileSystemEvent(event)

        let names = model.listing.files.map(\.name)
        #expect(names == ["b.jpg", "c.jpg"], "一覧が更新されていない。actual: \(names)")
        #expect(
            model.selection.focused == nil,
            "削除したファイルがフォーカスに残っている。focused: \(model.selection.focused?.path ?? "nil")"
        )
        #expect(
            model.selection.selected.isEmpty,
            "削除したファイルが選択に残っている。selected: \(model.selection.selected.map(\.path).sorted())"
        )
        let previewIsEmpty: Bool = switch model.preview {
        case .empty: true
        default: false
        }
        #expect(
            previewIsEmpty,
            "削除したファイルのプレビューが残っている。preview: \(describe(model.preview))"
        )

        await stopCollector(collector)
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemWatcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }

    private func startCollector(_ watcher: FileSystemWatcher) -> (EventRecorder, Task<Void, Never>) {
        let recorder = EventRecorder()
        let collector = Task {
            for await event in watcher.events {
                await recorder.record(event)
            }
        }
        return (recorder, collector)
    }

    private func stopCollector(_ collector: Task<Void, Never>) async {
        collector.cancel()
        await collector.value
    }

    private func containsFolder(_ event: Set<URL>, _ folder: URL) -> Bool {
        event.contains { $0.standardizedFileURL == folder.standardizedFileURL }
    }

    private func describe(_ events: [Set<URL>]) -> String {
        guard !events.isEmpty else { return "[]" }
        return events
            .map { describe($0) }
            .joined(separator: " | ")
    }

    private func describe(_ event: Set<URL>) -> String {
        "[" + event.map(\.path).sorted().joined(separator: ", ") + "]"
    }

    private func describe(_ preview: PreviewContent) -> String {
        switch preview {
        case .empty:
            return ".empty"
        case let .loading(url):
            return ".loading(\(url.lastPathComponent))"
        case let .image(image):
            return ".image(\(Int(image.pixelSize.width))x\(Int(image.pixelSize.height)))"
        case let .animatedImage(url):
            return ".animatedImage(\(url.lastPathComponent))"
        case let .animatedImageData(url, data):
            return ".animatedImageData(\(url.lastPathComponent), \(data.count) bytes)"
        case let .video(url):
            return ".video(\(url.lastPathComponent))"
        case let .unavailable(name, reason):
            return ".unavailable(\(name), \(reason))"
        }
    }

    @MainActor
    private func waitUntil(timeout: Duration, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}

private actor EventRecorder {
    private var events: [Set<URL>] = []

    func record(_ event: Set<URL>) {
        events.append(event)
    }

    func waitForEvent(
        after index: Int,
        timeout: Duration = .seconds(2)
    ) async -> (event: Set<URL>?, observed: [Set<URL>]) {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if events.count > index {
                return (events[index], events)
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return (events.count > index ? events[index] : nil, events)
    }
}
