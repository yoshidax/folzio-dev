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

    private let responses: [URL: Response]

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
