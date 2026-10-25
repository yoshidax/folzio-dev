import CoreGraphics
import Foundation
import Testing
@testable import MediaViewerCore

@Suite("BrowserModel のスライドショー")
struct BrowserModelSlideshowTests {
    @Test("閲覧先の置換は listing と selection を変える前に同期で通知する")
    @MainActor
    func willReplaceLocationIsSynchronous() async {
        let first = folder("first")
        let second = folder("second")
        let a = media("a.jpg", .jpeg, in: first)
        let b = media("b.jpg", .jpeg, in: second)

        let lister = SlideshowFakeLister(responses: [
            first: .init(files: [a], delay: .zero),
            second: .init(files: [b], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(first)
        model.select([a.url], focused: a.url)

        var observed: (folder: URL, focused: URL?)?
        model.onWillReplaceLocation = {
            observed = (model.listing.folder, model.selection.focused)
        }

        await model.selectFolder(second)

        #expect(observed?.folder == first)
        #expect(observed?.focused == a.url)
        #expect(model.listing.folder == second)
        #expect(model.selection.focused == nil)
    }

    @Test("検索の開始も置換の直前に通知し、検索結果の状態へ変わる")
    @MainActor
    func willReplaceLocationOnSearch() async {
        let first = folder("search-first")
        let a = media("a.jpg", .jpeg, in: first)

        let lister = SlideshowFakeLister(responses: [
            first: .init(files: [a], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(first)
        model.select([a.url], focused: a.url)

        var observed: (folder: URL, isSearch: Bool)?
        model.onWillReplaceLocation = {
            observed = (model.listing.folder, model.isShowingSearchResults)
        }

        let pattern = SearchPattern(keyword: "a")!
        model.startSearch(pattern, root: first)

        #expect(observed?.folder == first)
        #expect(observed?.isSearch == false)
        #expect(model.isShowingSearchResults)
    }

    @Test("名前の付け替えは閲覧先の置換ではないので通知しない")
    @MainActor
    func renameDoesNotNotifyReplacement() async {
        let first = folder("rename-old")
        let renamed = folder("rename-new")
        let a = media("a.jpg", .jpeg, in: first)

        let lister = SlideshowFakeLister(responses: [
            first: .init(files: [a], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(first)
        var notified = 0
        model.onWillReplaceLocation = { notified += 1 }

        model.didRenameFolder(from: first, to: renamed)

        #expect(notified == 0)
        #expect(model.listing.folder == renamed)
    }

    @Test("履歴の復元も一覧を置き換える前に同期で通知する")
    @MainActor
    func historyShowNotifiesReplacement() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserModelSlideshowHistory-\(UUID().uuidString)", isDirectory: true)
        let first = root.appendingPathComponent("first", isDirectory: true)
        let second = root.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let a = media("a.jpg", .jpeg, in: first)
        let b = media("b.jpg", .jpeg, in: second)
        let lister = SlideshowFakeLister(responses: [
            first: .init(files: [a], delay: .zero),
            second: .init(files: [b], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(first)
        var observed: (URL, URL?)?
        model.onWillReplaceLocation = {
            observed = (model.listing.folder, model.selection.focused)
        }

        let resolution = await model.resolveHistoryLocation(HistoryLocation(folder: second))
        guard case let .available(resolved) = resolution else {
            Issue.record("履歴の場所を解決できませんでした: \(resolution)")
            return
        }
        model.showHistoryLocation(resolved, focusing: nil)

        #expect(observed?.0 == first)
        #expect(observed?.1 == nil)
    }

    @Test("古い世代の再読み込みは、新しいフォルダの一覧を上書きしない")
    @MainActor
    func staleReloadDoesNotOverwriteNavigation() async {
        let first = folder("slow")
        let second = folder("fast")
        let a = media("a.jpg", .jpeg, in: first)
        let b = media("b.jpg", .jpeg, in: second)

        let lister = SlideshowFakeLister(responses: [
            first: .init(files: [a], delay: .milliseconds(200)),
            second: .init(files: [b], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(first)
        #expect(model.listing.folder == first)

        let reload = Task { await model.reloadCurrentFolder() }
        try? await Task.sleep(for: .milliseconds(20))
        await model.selectFolder(second)
        await reload.value

        #expect(model.listing.folder == second)
        #expect(model.listing.files.map(\.name) == ["b.jpg"])
    }

    @Test("同じ対象の同期はプレビューを読み直さず、選択だけを1件に整理する")
    @MainActor
    func synchronizeSameTargetDoesNotReload() async {
        let targetFolder = folder("same")
        let video = media("v.mp4", .mp4, in: targetFolder)
        let image = media("a.jpg", .jpeg, in: targetFolder)

        let lister = SlideshowFakeLister(responses: [
            targetFolder: .init(files: [video, image], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(targetFolder)
        model.select([video.url], focused: video.url)
        let signal = model.stopPlaybackSignal

        model.synchronizeSlideshowSelection(to: video.url)
        #expect(model.selection.selected == [video.url])
        #expect(model.selection.focused == video.url)
        #expect(model.stopPlaybackSignal == signal)

        model.select([video.url, image.url], focused: video.url)
        #expect(model.selection.selected.count == 2)
        model.synchronizeSlideshowSelection(to: video.url)
        #expect(model.selection.selected == [video.url])
        #expect(model.stopPlaybackSignal == signal)
    }

    @Test("違う対象の同期は通常の選択としてプレビューを切り替える")
    @MainActor
    func synchronizeDifferentTargetSelects() async {
        let targetFolder = folder("different")
        let video = media("v.mp4", .mp4, in: targetFolder)
        let image = media("a.jpg", .jpeg, in: targetFolder)

        let lister = SlideshowFakeLister(responses: [
            targetFolder: .init(files: [video, image], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(targetFolder)
        model.select([video.url], focused: video.url)
        let signal = model.stopPlaybackSignal

        model.synchronizeSlideshowSelection(to: image.url)

        #expect(model.selection.selected == [image.url])
        #expect(model.selection.focused == image.url)
        #expect(model.stopPlaybackSignal == signal + 1)
    }

    @Test("同じ画像の同期ではデコードをやり直さない")
    @MainActor
    func synchronizeSameImageDoesNotDecodeAgain() async {
        let targetFolder = folder("one-image")
        let image = media("only.jpg", .jpeg, in: targetFolder)
        let counter = DecodeCounter()

        let lister = SlideshowFakeLister(responses: [
            targetFolder: .init(files: [image], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: CountingDecoder(counter: counter))
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(targetFolder)
        model.select([image.url], focused: image.url)
        #expect(await waitUntil { counter.value >= 1 })
        let count = counter.value

        model.synchronizeSlideshowSelection(to: image.url)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(counter.value == count)
    }

    private func folder(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/slideshow-model-\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private func media(_ name: String, _ kind: MediaKind, in folder: URL) -> MediaFile {
        MediaFile(
            url: folder.appendingPathComponent(name),
            name: name,
            kind: .media(kind),
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }

    @MainActor
    private func makeModel(
        lister: SlideshowFakeLister,
        decoder: any ImageDecoding = SlideshowFakeDecoder()
    ) -> (BrowserModel, UserDefaults, String) {
        let suite = "BrowserModelSlideshowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let model = BrowserModel(
            lister: lister,
            decoder: decoder,
            cache: DecodedImageCache(costLimitBytes: 10_000_000),
            settings: SettingsStore(defaults: defaults)
        )
        return (model, defaults, suite)
    }

    @MainActor
    private func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}

private actor SlideshowFakeLister: DirectoryListing {
    struct Response: Sendable {
        var files: [MediaFile]
        var delay: Duration
        var error: ListingError?
    }

    private var responses: [URL: Response]

    init(responses: [URL: Response]) {
        self.responses = responses
    }

    func mediaFiles(in folder: URL) async throws(ListingError) -> [MediaFile] {
        guard let response = responses[folder] else {
            throw ListingError.notFound
        }
        if response.delay != .zero {
            try? await Task.sleep(for: response.delay)
        }
        if let error = response.error {
            throw error
        }
        return response.files
    }

    func subfolders(of folder: URL) async throws(ListingError) -> [URL] {
        []
    }
}

private struct SlideshowFakeDecoder: ImageDecoding {
    func decode(_ url: URL, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage {
        Self.makeImage()
    }

    func isAnimated(_ url: URL) -> Bool { false }

    func decode(data: Data, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage {
        Self.makeImage()
    }

    func isAnimated(data: Data) -> Bool { false }

    static func makeImage() -> DecodedImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return DecodedImage(
            cgImage: context.makeImage()!,
            pixelSize: CGSize(width: 2, height: 2),
            originalPixelSize: CGSize(width: 2, height: 2),
            byteCost: 16
        )
    }
}

private final class DecodeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private struct CountingDecoder: ImageDecoding {
    let counter: DecodeCounter

    func decode(_ url: URL, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage {
        counter.increment()
        return SlideshowFakeDecoder.makeImage()
    }

    func isAnimated(_ url: URL) -> Bool { false }

    func decode(data: Data, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage {
        counter.increment()
        return SlideshowFakeDecoder.makeImage()
    }

    func isAnimated(data: Data) -> Bool { false }
}
