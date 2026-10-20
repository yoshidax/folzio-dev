import CoreGraphics
import Foundation
import Testing
@testable import MediaViewerCore

@Suite("BrowserModel")
struct BrowserModelTests {
    @Test("フォルダを素早く切り替えると最後の一覧だけが残る")
    @MainActor
    func keepsOnlyLastFolder() async {
        let first = URL(fileURLWithPath: "/tmp/first-\(UUID().uuidString)", isDirectory: true)
        let second = URL(fileURLWithPath: "/tmp/second-\(UUID().uuidString)", isDirectory: true)

        let lister = FakeLister(responses: [
            first: .init(files: [file("a.jpg", in: first)], delay: .milliseconds(200)),
            second: .init(files: [file("b.jpg", in: second)], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        let firstTask = Task { await model.selectFolder(first) }
        try? await Task.sleep(for: .milliseconds(20))
        let secondTask = Task { await model.selectFolder(second) }
        await firstTask.value
        await secondTask.value

        #expect(model.listing.folder == second)
        #expect(model.listing.files.map(\.name) == ["b.jpg"])
        #expect(model.listing.state == .loaded)
        #expect(defaults.string(forKey: "view.lastFolderPath") == second.path)
    }

    @Test("空のフォルダと権限なしフォルダの状態を反映する")
    @MainActor
    func reflectsEmptyAndDenied() async {
        let emptyFolder = URL(fileURLWithPath: "/tmp/empty-\(UUID().uuidString)", isDirectory: true)
        let deniedFolder = URL(fileURLWithPath: "/tmp/denied-\(UUID().uuidString)", isDirectory: true)

        let lister = FakeLister(responses: [
            emptyFolder: .init(files: [], delay: .zero),
            deniedFolder: .init(files: [], delay: .zero, error: .accessDenied),
        ])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(emptyFolder)
        #expect(model.listing.state == .empty)
        #expect(model.listing.files.isEmpty)

        await model.selectFolder(deniedFolder)
        #expect(model.listing.state == .denied)
        #expect(model.listing.files.isEmpty)
    }

    @Test("moveFocus は端で止まる")
    @MainActor
    func moveFocusStopsAtEdges() async {
        let folder = URL(fileURLWithPath: "/tmp/move-\(UUID().uuidString)", isDirectory: true)
        let files = [file("a.jpg", in: folder), file("b.jpg", in: folder), file("c.jpg", in: folder)]

        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(folder)
        model.select([files[0].url], focused: files[0].url)
        model.moveFocus(.previous)
        #expect(model.selection.focused == files[0].url)

        model.moveFocus(.next)
        #expect(model.selection.focused == files[1].url)
        model.moveFocus(.next)
        #expect(model.selection.focused == files[2].url)
        model.moveFocus(.next)
        #expect(model.selection.focused == files[2].url)

        model.moveFocus(.previous)
        #expect(model.selection.focused == files[1].url)
    }

    @Test("フォーカスの前後1件をキャッシュに入れる")
    @MainActor
    func prefetchesNeighbors() async {
        let folder = URL(fileURLWithPath: "/tmp/prefetch-\(UUID().uuidString)", isDirectory: true)
        let files = [file("a.jpg", in: folder), file("b.jpg", in: folder), file("c.jpg", in: folder)]
        let cache = DecodedImageCache(costLimitBytes: 10_000_000)

        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder(), cache: cache)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(folder)
        model.select([files[1].url], focused: files[1].url)

        #expect(await waitForCache(cache, files[0].url))
        #expect(await waitForCache(cache, files[2].url))
    }

    @Test("デコード失敗は unavailable になる")
    @MainActor
    func reportsDecodeFailure() async {
        let folder = URL(fileURLWithPath: "/tmp/failure-\(UUID().uuidString)", isDirectory: true)
        let bad = file("bad.jpg", in: folder)

        let lister = FakeLister(responses: [folder: .init(files: [bad], delay: .zero)])
        let decoder = FakeDecoder(failingURLs: [bad.url])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: decoder)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(folder)
        model.select([bad.url], focused: bad.url)

        let isUnavailable = await waitUntil {
            if case let .unavailable(name, _) = model.preview {
                return name == "bad.jpg"
            }
            return false
        }
        #expect(isUnavailable)
    }

    // MARK: - 種類フィルタ

    @MainActor
    private func filterFolder() -> (URL, [MediaFile]) {
        let folder = URL(fileURLWithPath: "/tmp/filter-\(UUID().uuidString)", isDirectory: true)
        let files = ["a.jpg", "b.mov", "c.png", "d.mp4"].map { file($0, in: folder) }
        return (folder, files)
    }

    @MainActor
    private func isImagePreview(_ model: BrowserModel) -> Bool {
        if case .image = model.preview { return true }
        return false
    }

    @MainActor
    private func isLoadingPreview(_ model: BrowserModel) -> Bool {
        if case .loading = model.preview { return true }
        return false
    }

    @MainActor
    private func isEmptyPreview(_ model: BrowserModel) -> Bool {
        if case .empty = model.preview { return true }
        return false
    }

    @Test("種類フィルタの既定は両方オフで全件が表示される")
    @MainActor
    func filterDefaultShowsAll() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(model.mediaTypeFilter == MediaTypeFilter())
        await model.selectFolder(folder)
        #expect(model.listing.files.count == 4)
        #expect(model.listing.state == .loaded)
    }

    @Test("種類フィルタで画像のみ・動画のみ・両方オンを切り替える")
    @MainActor
    func filterSwitchesKinds() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }
        await model.selectFolder(folder)

        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))
        #expect(model.listing.files.map(\.name) == ["a.jpg", "c.png"])

        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))
        #expect(model.listing.files.map(\.name) == ["b.mov", "d.mp4"])

        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true, videosOnly: true))
        #expect(model.listing.files.map(\.name) == ["a.jpg", "b.mov", "c.png", "d.mp4"])

        // US3-13: 両方オンから「画像のみ表示」だけをオフにする
        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))
        #expect(model.listing.files.map(\.name) == ["b.mov", "d.mp4"])
    }

    @Test("該当なしと空のフォルダを区別する")
    @MainActor
    func filterDistinguishesNoMatchesAndEmpty() async {
        let imageFolder = URL(fileURLWithPath: "/tmp/filter-img-\(UUID().uuidString)", isDirectory: true)
        let emptyFolder = URL(fileURLWithPath: "/tmp/filter-empty-\(UUID().uuidString)", isDirectory: true)
        let lister = FakeLister(responses: [
            imageFolder: .init(files: [file("a.jpg", in: imageFolder), file("c.png", in: imageFolder)], delay: .zero),
            emptyFolder: .init(files: [], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(imageFolder)
        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))
        #expect(model.listing.state == .noMatches)
        #expect(model.listing.files.isEmpty)

        model.setMediaTypeFilter(MediaTypeFilter())
        #expect(model.listing.state == .loaded)
        #expect(model.listing.files.count == 2)

        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))
        await model.selectFolder(emptyFolder)
        #expect(model.listing.state == .empty)
        #expect(model.listing.files.isEmpty)
    }

    @Test("フォルダを移動しても種類フィルタが保たれる")
    @MainActor
    func filterPersistsAcrossFolders() async {
        let (folder, files) = filterFolder()
        let other = URL(fileURLWithPath: "/tmp/filter-other-\(UUID().uuidString)", isDirectory: true)
        let otherFiles = ["x.jpg", "y.mov", "z.mp4"].map { file($0, in: other) }
        let lister = FakeLister(responses: [
            folder: .init(files: files, delay: .zero),
            other: .init(files: otherFiles, delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(folder)
        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))
        await model.selectFolder(other)

        #expect(model.mediaTypeFilter.videosOnly)
        #expect(model.listing.files.map(\.name) == ["y.mov", "z.mp4"])
    }

    @Test("絞り込み中の並べ替えは絞り込みを保ち該当なしも維持する")
    @MainActor
    func filterWithSortOrder() async {
        let (folder, files) = filterFolder()
        let imageFolder = URL(fileURLWithPath: "/tmp/filter-img-\(UUID().uuidString)", isDirectory: true)
        let lister = FakeLister(responses: [
            folder: .init(files: files, delay: .zero),
            imageFolder: .init(files: [file("a.jpg", in: imageFolder)], delay: .zero),
        ])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(folder)
        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))
        model.sortOrder = SortOrder(column: .name, ascending: false)
        #expect(model.listing.files.map(\.name) == ["d.mp4", "b.mov"])

        await model.selectFolder(imageFolder)
        #expect(model.listing.state == .noMatches)
        model.sortOrder = SortOrder(column: .name, ascending: true)
        #expect(model.listing.state == .noMatches)
        #expect(model.listing.files.isEmpty)
    }

    @Test("絞り込み中の読み直しで新しいファイルも絞り込まれる")
    @MainActor
    func filterAppliesOnReload() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.selectFolder(folder)
        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))

        await lister.setResponse(
            .init(files: files + [file("e.mov", in: folder)], delay: .zero),
            for: folder
        )
        await model.reloadCurrentFolder()
        #expect(model.listing.files.map(\.name) == ["b.mov", "d.mp4", "e.mov"])
    }

    @Test("フォーカスが隠れると選択が整理されプレビューが切り替わる")
    @MainActor
    func filterRestrictsSelectionWhenFocusHidden() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }
        await model.selectFolder(folder)

        let a = files[0].url
        let b = files[1].url
        model.select([a, b], focused: b)
        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))

        #expect(model.selection.selected == [a])
        #expect(model.selection.focused == a)
        let isImage = await waitUntil { isImagePreview(model) }
        #expect(isImage)
    }

    @Test("フォーカスが表示中のままなら選択だけ差し替えてプレビューを読み直さない")
    @MainActor
    func filterKeepsPreviewWhenFocusVisible() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }
        await model.selectFolder(folder)

        let a = files[0].url
        let b = files[1].url
        model.select([a, b], focused: a)
        let loaded = await waitUntil { isImagePreview(model) }
        #expect(loaded)

        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))

        #expect(model.selection.selected == [a])
        #expect(model.selection.focused == a)
        #expect(!isLoadingPreview(model))
        #expect(isImagePreview(model))
    }

    @Test("選択が残らないときは空になり、絞り込みを戻しても選択は戻らない")
    @MainActor
    func filterClearsSelectionWhenNothingRemains() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }
        await model.selectFolder(folder)

        let b = files[1].url
        model.select([b], focused: b)
        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))

        #expect(model.selection.selected.isEmpty)
        #expect(model.selection.focused == nil)
        #expect(isEmptyPreview(model))

        model.setMediaTypeFilter(MediaTypeFilter())
        #expect(model.selection.selected.isEmpty)
        #expect(model.selection.focused == nil)
    }

    @Test("同じ種類フィルタを再設定しても一覧と選択は変わらない")
    @MainActor
    func filterSameValueIsNoOp() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }
        await model.selectFolder(folder)

        let a = files[0].url
        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))
        model.select([a], focused: a)
        let listingBefore = model.listing
        let selectionBefore = model.selection
        let signalBefore = model.stopPlaybackSignal

        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))

        #expect(model.listing.files.map(\.url) == listingBefore.files.map(\.url))
        #expect(model.listing.state == listingBefore.state)
        #expect(model.listing.folder == listingBefore.folder)
        #expect(model.selection.selected == selectionBefore.selected)
        #expect(model.selection.focused == selectionBefore.focused)
        #expect(model.stopPlaybackSignal == signalBefore)
    }

    @Test("種類フィルタは設定に保存されない")
    @MainActor
    func filterIsNotPersisted() async {
        let (folder, files) = filterFolder()
        let lister = FakeLister(responses: [folder: .init(files: files, delay: .zero)])
        let (model, defaults, suite) = makeModel(lister: lister, decoder: FakeDecoder())
        defer { defaults.removePersistentDomain(forName: suite) }
        await model.selectFolder(folder)

        let keysBefore = Set(defaults.persistentDomain(forName: suite)?.keys.map { $0 } ?? [])
        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))
        model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))
        let keysAfter = Set(defaults.persistentDomain(forName: suite)?.keys.map { $0 } ?? [])

        #expect(keysBefore == keysAfter)
    }

    @MainActor
    private func makeModel(
        lister: FakeLister,
        decoder: FakeDecoder,
        cache: DecodedImageCache = DecodedImageCache(costLimitBytes: 10_000_000)
    ) -> (BrowserModel, UserDefaults, String) {
        let suite = "BrowserModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let model = BrowserModel(
            lister: lister,
            decoder: decoder,
            cache: cache,
            settings: SettingsStore(defaults: defaults)
        )
        return (model, defaults, suite)
    }

    @MainActor
    private func file(_ name: String, in folder: URL) -> MediaFile {
        MediaFile(
            url: folder.appendingPathComponent(name),
            name: name,
            kind: MediaKind(fileExtension: (name as NSString).pathExtension) ?? .jpeg,
            typeDescription: "JPEG イメージ",
            creationDate: nil,
            fileSize: 0
        )
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

    private func waitForCache(_ cache: DecodedImageCache, _ url: URL) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if await cache.get(url) != nil { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}

private actor FakeLister: DirectoryListing {
    struct Response: Sendable {
        var files: [MediaFile]
        var delay: Duration
        var error: ListingError?
    }

    private var responses: [URL: Response]

    init(responses: [URL: Response]) {
        self.responses = responses
    }

    func setResponse(_ response: Response, for folder: URL) {
        responses[folder] = response
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

private struct FakeDecoder: ImageDecoding {
    var animatedURLs: Set<URL> = []
    var failingURLs: Set<URL> = []

    func decode(_ url: URL, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage {
        if failingURLs.contains(url) {
            throw DecodeError.corrupted
        }
        return Self.makeImage()
    }

    func isAnimated(_ url: URL) -> Bool {
        animatedURLs.contains(url)
    }

    private static func makeImage() -> DecodedImage {
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
