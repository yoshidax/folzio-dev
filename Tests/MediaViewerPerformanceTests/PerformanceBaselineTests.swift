import CoreGraphics
import Foundation
import Testing
import FixtureKit
@testable import MediaViewerCore

@Suite("PerformanceBaseline", .serialized)
struct PerformanceBaselineTests {
    @Test("24MP JPEG のデコードが 0.5 秒以内")
    func decodes24MegapixelJPEGWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("24mp.jpg")
        try ImageFixtures.jpeg(at: url, width: 6000, height: 4000)

        let decoder = ImageDecoder()
        let start = ContinuousClock.now
        let image = try await decoder.decode(url, maxPixelSize: 5120)
        let elapsed = ContinuousClock.now - start

        #expect(
            max(image.pixelSize.width, image.pixelSize.height) <= 5120,
            "長辺が maxPixelSize 以下であること (実際: \(image.pixelSize))"
        )
        #expect(
            elapsed < .milliseconds(500),
            "24MP JPEG のデコードは 0.5 秒以内 (実測: \(elapsed))"
        )
    }

    @Test("キャッシュ済みの隣接ファイルへの切替が 0.1 秒以内")
    @MainActor
    func cachedNeighborSwitchWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let names = ["01.jpg", "02.jpg", "03.jpg"]
        for name in names {
            try ImageFixtures.jpeg(
                at: directory.appendingPathComponent(name),
                width: 1600,
                height: 1200
            )
        }

        let suite = "PerformanceBaselineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = DecodedImageCache()
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: cache,
            settings: SettingsStore(defaults: defaults)
        )
        model.screenMaxPixel = 5120

        await model.selectFolder(directory)
        #expect(
            model.listing.files.map(\.name) == names,
            "3 件が名前順に列挙されること (実際: \(model.listing.files.map(\.name)))"
        )
        guard model.listing.files.count == 3 else {
            Issue.record("隣接ファイルの切替を計測するには 3 件必要です")
            return
        }

        let previous = model.listing.files[0]
        let middle = model.listing.files[1]
        let next = model.listing.files[2]

        model.select([middle.url], focused: middle.url)
        let middleVisible = await waitUntil(timeout: .seconds(10)) {
            if case .image = model.preview {
                return model.selection.focused == middle.url
            }
            return false
        }
        #expect(middleVisible, "中央のファイルのプレビューが表示されること")

        let previousCached = await waitForCache(cache, previous.url, timeout: .seconds(10))
        let nextCached = await waitForCache(cache, next.url, timeout: .seconds(10))
        #expect(previousCached, "前のファイルがキャッシュに先読みされていること")
        #expect(nextCached, "次のファイルがキャッシュに先読みされていること")

        let start = ContinuousClock.now
        model.moveFocus(.next)
        let settled = await waitUntil(timeout: .seconds(10)) {
            if case .image = model.preview {
                return model.selection.focused == next.url
            }
            return false
        }
        let elapsed = ContinuousClock.now - start

        #expect(settled, "次のファイルのプレビューが表示されること")
        #expect(model.selection.focused == next.url, "フォーカスが次のファイルに移ること")
        #expect(
            elapsed < .milliseconds(100),
            "キャッシュ済みの隣接ファイルへの切替は 0.1 秒以内 (実測: \(elapsed))"
        )
    }

    @Test("huge(10,000) の列挙と並べ替えが 1 秒以内")
    func hugeFolderListingAndSortingWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try FixtureSets.huge(in: directory, count: 10_000)
        let folder = directory.appendingPathComponent("huge", isDirectory: true)

        let lister = DirectoryLister()
        let start = ContinuousClock.now
        let files = try await lister.mediaFiles(in: folder)
        let ordered = sorted(files, by: SortOrder())
        let elapsed = ContinuousClock.now - start

        #expect(files.count == 10_000, "10,000 件が列挙されること (実際: \(files.count))")
        #expect(ordered.count == 10_000, "10,000 件が並べ替えられること (実際: \(ordered.count))")
        #expect(
            ordered.first?.name == "img_00001.jpg",
            "自然順の先頭が img_00001.jpg であること (実際: \(ordered.first?.name ?? "nil"))"
        )
        #expect(
            elapsed < .seconds(1),
            "10,000 ファイルの列挙と並べ替えは 1 秒以内 (実測: \(elapsed))"
        )
    }

    @Test("100MP グレースケール PNG をデコードしバイトコストを抑える")
    func decodesHundredMegapixelPNGWithinMemoryBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("big.png")
        try ImageFixtures.grayscalePNG(at: url, width: 10_000, height: 10_000)

        let decoder = ImageDecoder()
        let image = try await decoder.decode(url, maxPixelSize: 5120)

        let maximumByteCost = 5120 * 5120 * 4
        let longSide = max(image.pixelSize.width, image.pixelSize.height)

        #expect(
            image.byteCost <= maximumByteCost,
            "byteCost が 5120x5120x4 以下であること (実際: \(image.byteCost))"
        )
        #expect(
            longSide <= 5120,
            "長辺が 5120px 以下であること (実際: \(image.pixelSize))"
        )
        #expect(
            image.originalPixelSize.width == 10_000 && image.originalPixelSize.height == 10_000,
            "元の大きさが 10000x10000 であること (実際: \(image.originalPixelSize))"
        )
    }

    @Test("連続 100 回のフォーカス移動後もプレビューキャッシュが 256MB 以下")
    @MainActor
    func repeatedFocusMovesStayWithinCacheLimit() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let folder = directory.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for index in 1...100 {
            try ImageFixtures.jpeg(
                at: folder.appendingPathComponent(String(format: "img_%03d.jpg", index)),
                width: 1024,
                height: 768
            )
        }

        let suite = "PerformanceBaselineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = DecodedImageCache()
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: cache,
            settings: SettingsStore(defaults: defaults)
        )

        await model.selectFolder(folder)
        #expect(model.listing.files.count == 100, "100 件が列挙されること (実際: \(model.listing.files.count))")
        guard model.listing.files.count == 100 else {
            Issue.record("フォーカス移動を計測するには 100 件必要です")
            return
        }

        let first = model.listing.files[0]
        model.select([first.url], focused: first.url)

        for _ in 0..<100 {
            model.moveFocus(.next)
        }

        let settled = await waitUntil(timeout: .seconds(30)) {
            if case .image = model.preview {
                return true
            }
            return false
        }
        #expect(settled, "100 回の移動後にプレビューが画像として確定すること")

        let isUnavailable: Bool
        if case .unavailable = model.preview {
            isUnavailable = true
        } else {
            isUnavailable = false
        }
        #expect(!isUnavailable, "プレビューがエラー状態のままにならないこと")

        let totalCost = await cache.totalCost
        #expect(
            totalCost <= MemoryLimits.previewCacheBytes,
            "キャッシュの totalCost が 256MB 以下であること (実際: \(totalCost) bytes)"
        )
        #expect(
            model.selection.focused == model.listing.files.last?.url,
            "最後のファイルにフォーカスがあること"
        )
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MediaViewerPerformanceTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(5),
    _ condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

private func waitForCache(
    _ cache: DecodedImageCache,
    _ url: URL,
    timeout: Duration = .seconds(10)
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if await cache.get(url) != nil {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await cache.get(url) != nil
}
