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

    @Test("10,000 ファイルのフォルダへ戻ったときの最初の項目の表示が 1 秒以内")
    @MainActor
    func historyBackToHugeFolderWithinBudget() async throws {
        // 10,000 ファイルの作成は MainActor の外で行い、並行して走るほかのテストを止めない
        let directory = try await Task.detached(priority: .userInitiated) {
            let directory = try makeTemporaryDirectory()
            try FixtureSets.huge(in: directory, count: 10_000)
            let small = directory.appendingPathComponent("small", isDirectory: true)
            try FileManager.default.createDirectory(at: small, withIntermediateDirectories: true)
            try ImageFixtures.jpeg(at: small.appendingPathComponent("one.jpg"), width: 64, height: 64)
            return directory
        }.value
        defer { try? FileManager.default.removeItem(at: directory) }

        let huge = directory.appendingPathComponent("huge", isDirectory: true)
        let small = directory.appendingPathComponent("small", isDirectory: true)

        let suite = "PerformanceBaselineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(),
            settings: SettingsStore(defaults: defaults)
        )
        model.setNavigationRoots([directory])
        let navigator = HistoryNavigator(model: model)
        let host = PerformanceHistoryHost()
        navigator.presentationHost = host

        await model.selectFolder(huge)
        await model.selectFolder(small)
        #expect(navigator.canGoBack)

        let start = ContinuousClock.now
        navigator.goBack()
        let ready = await waitUntil(timeout: .seconds(10)) {
            model.listing.folder == huge
                && model.listing.state == .loaded
                && !model.listing.files.isEmpty
        }
        let elapsed = ContinuousClock.now - start

        #expect(ready, "10,000 ファイルの一覧が表示されること")
        #expect(
            model.listing.files.filter { $0.kind != .parent }.count == 10_000,
            "10,000 件が一覧にあること (実際: \(model.listing.files.filter { $0.kind != .parent }.count))"
        )
        #expect(
            elapsed < .seconds(1),
            "10,000 ファイルのフォルダへ戻って最初の項目が表示されるまで 1 秒以内 (実測: \(elapsed))"
        )
    }

    @Test("10,000 件への種類フィルタの適用が 0.05 秒以内")
    func mediaTypeFilterOnHugeFolderWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try FixtureSets.huge(in: directory, count: 10_000)
        let folder = directory.appendingPathComponent("huge", isDirectory: true)

        let lister = DirectoryLister()
        let files = try await lister.mediaFiles(in: folder)
        let ordered = sorted(files, by: SortOrder())

        let start = ContinuousClock.now
        let images = MediaTypeFilter(imagesOnly: true).apply(to: ordered)
        let videos = MediaTypeFilter(videosOnly: true).apply(to: ordered)
        let elapsed = ContinuousClock.now - start

        #expect(images.count == 10_000, "画像のみで 10,000 件 (実際: \(images.count))")
        #expect(videos.isEmpty, "動画のみで 0 件 (実際: \(videos.count))")
        #expect(
            elapsed < .milliseconds(50),
            "種類フィルタの適用は 0.05 秒以内 (実測: \(elapsed))"
        )
    }

    @Test("10,000 件（zip ファイルを混ぜる）への zip ファイルの表示の適用が 0.05 秒以内")
    func zipFileVisibilityOnHugeFolderWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try FixtureSets.huge(in: directory, count: 10_000)
        let folder = directory.appendingPathComponent("huge", isDirectory: true)

        let lister = DirectoryLister()
        let files = try await lister.mediaFiles(in: folder)
        let ordered = sorted(files, by: SortOrder())

        // 準備（10件に1件を zip ファイルの行に置き換える）は計測に含めない
        var mixed = ordered
        for index in mixed.indices where index.isMultiple(of: 10) {
            var archive = mixed[index]
            archive.name = String(format: "img_%05d.zip", index + 1)
            archive.url = folder.appendingPathComponent(archive.name)
            archive.kind = .archive
            mixed[index] = archive
        }

        let start = ContinuousClock.now
        let hidden = ZipFileVisibility(showsZipFiles: false).apply(to: mixed)
        let shown = ZipFileVisibility(showsZipFiles: true).apply(to: mixed)
        let elapsed = ContinuousClock.now - start

        #expect(hidden.count == 9_000, "非表示で 9,000 件 (実際: \(hidden.count))")
        #expect(shown.count == 10_000, "表示で 10,000 件 (実際: \(shown.count))")
        print("[perf] ZipFileVisibility.apply 10,000 (hide + show): \(elapsed)")
        #expect(
            elapsed < .milliseconds(50),
            "zip ファイルの表示の適用は 0.05 秒以内 (実測: \(elapsed))"
        )
    }

    @Test("10,000 ファイルのフォルダでの zip ファイルの表示の切り替えが 0.2 秒以内")
    @MainActor
    func toggleZipFileVisibilityOnHugeFolderWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try FixtureSets.huge(in: directory, count: 10_000)
        let folder = directory.appendingPathComponent("huge", isDirectory: true)

        // 準備（10件に1件を zip ファイルに置き換える）は計測に含めない
        let template = directory.appendingPathComponent("template.zip")
        try ZipFixtureWriter.write([], to: template)
        let fileManager = FileManager.default
        for index in stride(from: 0, to: 10_000, by: 10) {
            try fileManager.removeItem(at: folder.appendingPathComponent(String(format: "img_%05d.jpg", index + 1)))
            try fileManager.copyItem(
                at: template,
                to: folder.appendingPathComponent(String(format: "img_%05d.zip", index + 1))
            )
        }

        let suite = "PerformanceBaselineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(),
            settings: SettingsStore(defaults: defaults)
        )

        await model.selectFolder(folder)
        #expect(model.listing.files.count == 9_000, "非表示の既定で 9,000 件 (実際: \(model.listing.files.count))")

        let showStart = ContinuousClock.now
        model.setShowsZipFiles(true)
        let showElapsed = ContinuousClock.now - showStart
        #expect(model.listing.files.count == 10_000, "表示で 10,000 件 (実際: \(model.listing.files.count))")

        let hideStart = ContinuousClock.now
        model.setShowsZipFiles(false)
        let hideElapsed = ContinuousClock.now - hideStart
        #expect(model.listing.files.count == 9_000, "非表示で 9,000 件 (実際: \(model.listing.files.count))")

        print("[perf] setShowsZipFiles 10,000: show \(showElapsed), hide \(hideElapsed)")
        #expect(showElapsed < .milliseconds(200), "表示への切り替えは 0.2 秒以内 (実測: \(showElapsed))")
        #expect(hideElapsed < .milliseconds(200), "非表示への切り替えは 0.2 秒以内 (実測: \(hideElapsed))")
    }

    @Test("10,000 件の検索結果での didRenameFolder が 0.1 秒以内（フォルダの行を含む）")
    @MainActor
    func renameFolderWithHugeSearchResultsWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try FixtureSets.huge(in: directory, count: 10_000)
        // 名前を変えるフォルダ自身の行と、ほかのフォルダの行（100 件）を結果に含める（R4・R9）
        let seeded = directory.appendingPathComponent("huge", isDirectory: true)
        for index in 0 ..< 100 {
            try FileManager.default.createDirectory(
                at: seeded.appendingPathComponent(String(format: "img-folder-%03d", index), isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        let folder = directory.appendingPathComponent("img-huge", isDirectory: true)
        try FileManager.default.moveItem(at: seeded, to: folder)
        let expectedCount = 10_000 + 1 + 100

        let suite = "PerformanceBaselineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(),
            settings: SettingsStore(defaults: defaults)
        )

        // 検索を終えるまでと、ディスク上の名前の変更は計測に含めない
        model.startSearch(try #require(SearchPattern(keyword: "img")), root: directory)
        let finished = await waitUntil(timeout: .seconds(30)) { model.listing.search?.phase == .finished }
        #expect(finished, "検索が終わること")
        #expect(
            model.listing.search?.totalCount == expectedCount,
            "10,101 件 (実際: \(model.listing.search?.totalCount ?? -1))"
        )
        #expect(model.listing.files.filter { $0.kind == .folder }.count == 101, "フォルダの行は 101 件")
        // 負荷の高いマシンでの外れ値で落ちないよう、名前を行き来して3回測り、中央値で判定する
        let names = ["img-huge2", "img-huge", "img-huge2"]
        var current = folder
        var samples: [Duration] = []
        for name in names {
            let next = directory.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.moveItem(at: current, to: next)

            let start = ContinuousClock.now
            model.didRenameFolder(from: current, to: next)
            samples.append(ContinuousClock.now - start)

            let mediaMoved = model.listing.files
                .filter(\.kind.isMedia)
                .allSatisfy { $0.url.deletingLastPathComponent().lastPathComponent == name }
            #expect(mediaMoved, "すべてのメディアの行が新しい場所（\(name)）になること")
            // 名前を変えたフォルダ自身の行は、新しい URL と名前になる
            let renamedRow = model.listing.files.first {
                $0.kind == .folder && $0.url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL
            }
            #expect(renamedRow?.name == name, "フォルダの行の名前が \(name) になること")
            #expect(renamedRow?.url.standardizedFileURL.path == next.standardizedFileURL.path)
            #expect(model.listing.files.filter { $0.kind == .folder }.count == 101, "ほかのフォルダの行は残ること")
            current = next
        }
        let median = samples.sorted()[1]
        print("[perf] didRenameFolder 10,000 search results with folders: \(samples), median \(median)")
        #expect(median < .milliseconds(100), "名前の変更の付け替えは 0.1 秒以内 (中央値: \(median)、実測: \(samples))")
    }

    @Test("サブフォルダのない 10,000 ファイルのフォルダの hasSubfolders が 0.2 秒以内")
    func hasSubfoldersInLargeFolderWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<10_000 {
            let path = directory.appendingPathComponent(String(format: "%05d.jpg", index)).path
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        let lister = DirectoryLister()
        let start = ContinuousClock.now
        let hasSubfolders = try await lister.hasSubfolders(in: directory)
        let elapsed = ContinuousClock.now - start

        #expect(!hasSubfolders, "サブフォルダがないこと")
        #expect(
            elapsed < .milliseconds(200),
            "10,000 ファイルのフォルダのサブフォルダの有無の確認は 0.2 秒以内 (実測: \(elapsed))"
        )
    }

    @Test("10,000 ファイルと 1,000 サブフォルダのフォルダの列挙が 1 秒以内")
    func listsLargeFolderWithSubfoldersWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<10_000 {
            let path = directory.appendingPathComponent(String(format: "%05d.jpg", index)).path
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        for index in 0..<1_000 {
            try FileManager.default.createDirectory(
                at: directory.appendingPathComponent(String(format: "folder-%04d", index), isDirectory: true),
                withIntermediateDirectories: false
            )
        }

        let lister = DirectoryLister()
        let start = ContinuousClock.now
        let files = try await lister.mediaFiles(in: directory)
        let elapsed = ContinuousClock.now - start

        #expect(files.count == 11_000)
        #expect(files.filter { $0.kind == .folder }.count == 1_000)
        print("mediaFiles(in:) 10,000 files + 1,000 folders: \(elapsed)")
        #expect(
            elapsed < .seconds(1),
            "10,000 ファイルと 1,000 サブフォルダの列挙は SC-003 の列挙と同じ 1 秒以内 (実測: \(elapsed))"
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

    @Test("10,000 項目の zip の open と items(in:) の合計が 0.5 秒以内")
    func opensLargeArchiveWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // zip の生成時間は計測に含めない
        let zip = try makeLargeZip(in: directory)

        let reader = ZipArchiveReader()
        let start = ContinuousClock.now
        let index = try await reader.open(zip)
        let items = index.items(in: "")
        let elapsed = ContinuousClock.now - start

        print("ZipArchiveReader.open + items(in:) 10,000 件: \(elapsed)")
        #expect(items.count == 10_000, "10,000 件が列挙されること (実際: \(items.count))")
        #expect(
            elapsed < .milliseconds(500),
            "10,000 項目の zip の open + items は 0.5 秒以内 (実測: \(elapsed))"
        )
    }

    /// `items(in:)` は zip を開いた後に MainActor の `BrowserModel` から呼ばれる。行は `open` のバックグラウンドで
    /// 作っておき、ここでは作らない（SC-015 の 100ms 以上の停止 0 回）
    @Test("10,000 項目の zip を開いた後の items(in:) が 10ms 以内 (SC-015)")
    func archiveItemsAreReadyAfterOpen() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let zip = try makeLargeZip(in: directory)
        let index = try await ZipArchiveReader().open(zip)

        let start = ContinuousClock.now
        let items = index.items(in: "")
        let elapsed = ContinuousClock.now - start

        print("ArchiveIndex.items(in:) 10,000 件: \(elapsed)")
        #expect(items.count == 10_000, "10,000 件が列挙されること (実際: \(items.count))")
        #expect(elapsed < .milliseconds(10), "items(in:) は 10ms 以内 (実測: \(elapsed))")
    }

    /// 小さな JPEG（各 1KB、無圧縮）10,000 個の zip
    private func makeLargeZip(in directory: URL) throws -> URL {
        let zip = directory.appendingPathComponent("large.zip")
        let body = Data(repeating: 0xAB, count: 1024)
        let entries = (0..<10_000).map { index in
            ZipFixtureEntry(
                name: String(format: "img_%05d.jpg", index),
                content: .bytes(body),
                method: .stored
            )
        }
        try ZipFixtureWriter.write(entries, to: zip)
        return zip
    }

    @Test("1GB の deflate 項目の stream 読み出しで phys_footprint の増加が 128MB 以下 (SC-014)")
    func entryStreamReadsStayWithinMemoryBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // ゼロ埋め 1GB を deflate で格納する。zip の生成時間は計測に含めない
        let zip = directory.appendingPathComponent("big-deflated.zip")
        let length: UInt64 = 1 << 30
        try ZipFixtureWriter.write(
            [ZipFixtureEntry(name: "zeros.mp4", content: .zeros(count: length), method: .deflated)],
            to: zip
        )

        let reader = ZipArchiveReader()
        _ = try await reader.open(zip)
        let stream = try await reader.stream(for: ArchiveURL.entry(archive: zip, path: "zeros.mp4"))
        #expect(stream.length == length, "展開後のサイズが 1GB であること (実際: \(stream.length))")

        let chunk = 512 * 1024
        let mebibyte: UInt64 = 1 << 20
        // 先頭から末尾まで 512KB ずつ、続けて 900MB・100MB・10MB の位置（後ろ向き）から各 4MB
        var plan: [(offset: UInt64, count: Int)] = []
        var position: UInt64 = 0
        while position < length {
            plan.append((position, chunk))
            position += UInt64(chunk)
        }
        for startMiB in [UInt64(900), 100, 10] {
            for step in 0..<(4 * 1024 * 1024 / chunk) {
                plan.append((startMiB * mebibyte + UInt64(step * chunk), chunk))
            }
        }

        let baseline = physicalFootprint()
        var maximumIncrease: Int64 = 0
        var readBytes = 0
        let start = ContinuousClock.now
        for (index, step) in plan.enumerated() {
            let data = try stream.read(offset: step.offset, maxLength: step.count)
            readBytes += data.count
            if (index + 1) % 64 == 0 || index == plan.count - 1 {
                maximumIncrease = max(maximumIncrease, Int64(physicalFootprint()) - Int64(baseline))
            }
        }
        let elapsed = ContinuousClock.now - start

        print("ArchiveEntryStream 1GB deflate: 最大増加 \(maximumIncrease / 1_048_576)MB (\(maximumIncrease) bytes), 所要時間 \(elapsed), 読み出し \(plan.count) 回")
        #expect(readBytes > 0)
        #expect(
            maximumIncrease <= 128 * 1024 * 1024,
            "64 回ごとの phys_footprint の最大増加は 128MB 以下 (実測: \(maximumIncrease) bytes)"
        )
    }

    // MARK: - ファイル名の検索（FR-085・SC-016）

    @Test("10,000 ファイルの階層の検索が 3 秒以内（SC-016）")
    func searchingTenThousandFilesWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let templateURL = directory.appendingPathComponent("template.jpg")
        try ImageFixtures.jpeg(at: templateURL, width: 8, height: 8)
        let template = try Data(contentsOf: templateURL)
        try FileManager.default.removeItem(at: templateURL)
        let root = directory.appendingPathComponent("tree", isDirectory: true)
        for folderIndex in 0..<100 {
            let folder = root.appendingPathComponent(String(format: "folder-%03d", folderIndex), isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for fileIndex in 0..<100 {
                let name = fileIndex.isMultiple(of: 2)
                    ? String(format: "cat_%03d.jpg", fileIndex)
                    : String(format: "dog_%03d.jpg", fileIndex)
                try template.write(to: folder.appendingPathComponent(name))
            }
        }

        let pattern = try #require(SearchPattern(keyword: "cat"))
        let start = ContinuousClock.now
        var count = 0
        for await batch in FileNameSearcher().search(in: root, matching: pattern) {
            count += batch.count
        }
        let elapsed = ContinuousClock.now - start

        #expect(count == 5_000, "半数の 5,000 件が見つかること (実際: \(count))")
        #expect(elapsed < .seconds(3), "10,000 ファイルの階層の検索は 3 秒以内 (実測: \(elapsed))")
        print("[perf] search 10,000 files: \(elapsed)")
    }

    @Test("フォルダ名も照合する 10,000 ファイルの階層の検索が 3 秒以内（SC-054）")
    func searchingFoldersAndFilesWithinBudget() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let templateURL = directory.appendingPathComponent("template.jpg")
        try ImageFixtures.jpeg(at: templateURL, width: 8, height: 8)
        let template = try Data(contentsOf: templateURL)
        try FileManager.default.removeItem(at: templateURL)
        // SC-016 と同じ 100 フォルダ × 100 ファイル。フォルダ名の半数（50 個）がキーワードを含む
        let root = directory.appendingPathComponent("tree", isDirectory: true)
        for folderIndex in 0 ..< 100 {
            let folderName = folderIndex.isMultiple(of: 2)
                ? String(format: "cat-folder-%03d", folderIndex)
                : String(format: "folder-%03d", folderIndex)
            let folder = root.appendingPathComponent(folderName, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for fileIndex in 0 ..< 100 {
                let fileName = fileIndex.isMultiple(of: 2)
                    ? String(format: "cat_%03d.jpg", fileIndex)
                    : String(format: "dog_%03d.jpg", fileIndex)
                try template.write(to: folder.appendingPathComponent(fileName))
            }
        }

        let pattern = try #require(SearchPattern(keyword: "cat"))
        let start = ContinuousClock.now
        var folderCount = 0
        var fileCount = 0
        var matchingFolderNames: [String] = []
        for await batch in FileNameSearcher().search(in: root, matching: pattern) {
            for file in batch {
                if file.kind == .folder {
                    folderCount += 1
                    matchingFolderNames.append(file.name)
                } else if file.kind.isMedia {
                    fileCount += 1
                }
            }
        }
        let elapsed = ContinuousClock.now - start

        #expect(folderCount == 50, "一致するフォルダは 50 件 (実際: \(folderCount))")
        #expect(fileCount == 5_000, "一致するファイルは 5,000 件 (実際: \(fileCount))")
        // folder-%03d は cat を含まないため、SC-016 の検索（ファイルだけの 5,000 件）は変わらない
        #expect(!matchingFolderNames.contains { $0.hasPrefix("folder-") })
        #expect(elapsed < .seconds(3), "フォルダも照合する 10,000 ファイルの検索は 3 秒以内 (実測: \(elapsed))")
        print("[perf] search 10,000 files with folders: \(elapsed), folders \(folderCount), files \(fileCount)")
    }

    @Test("10,000 件への 256 件のマージが 0.05 秒以内（FR-085）")
    @MainActor
    func mergingBatchIntoTenThousandWithinBudget() async throws {
        let order = SortOrder()
        let existing = sorted(syntheticResults(count: 10_000, folders: 1, prefix: "img"), by: order)
        let batch = sorted(syntheticResults(count: 256, folders: 1, prefix: "img", offset: 10_000), by: order)

        let mergeStart = ContinuousClock.now
        let merged = sortedMerge(existing, batch, by: order)
        let mergeElapsed = ContinuousClock.now - mergeStart
        #expect(merged.count == 10_256)
        #expect(mergeElapsed < .milliseconds(50), "sortedMerge は 0.05 秒以内 (実測: \(mergeElapsed))")

        let modelElapsed = try await measureBatch(existing: existing, batch: batch)
        #expect(modelElapsed < .milliseconds(50), "BrowserModel の1バッチの処理は 0.05 秒以内 (実測: \(modelElapsed))")
        print("[perf] merge 256 into 10,000: sortedMerge \(mergeElapsed), BrowserModel \(modelElapsed)")
    }

    @Test("50,000 件への 256 件のバッチの処理が 100ms 未満（FR-085・SC-016）")
    @MainActor
    func processingBatchIntoFiftyThousandWithinBudget() async throws {
        let order = SortOrder()
        let existing = sorted(syntheticResults(count: 50_000, folders: 500, prefix: "photo"), by: order)
        let batch = sorted(syntheticResults(count: 256, folders: 500, prefix: "photo", offset: 50_000), by: order)

        let elapsed = try await measureBatch(existing: existing, batch: batch)
        #expect(elapsed < .milliseconds(100), "50,000 件への1バッチの処理は 100ms 未満 (実測: \(elapsed))")
        print("[perf] batch 256 into 50,000: \(elapsed)")
    }

    /// フェイクの検索器で `existing` を流した後、`batch` を流してから一覧の件数が増えるまでの時間
    @MainActor
    private func measureBatch(existing: [MediaFile], batch: [MediaFile]) async throws -> Duration {
        let suite = "PerformanceBaselineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let searcher = StreamingSearcher()
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(),
            settings: SettingsStore(defaults: defaults),
            searcher: searcher
        )
        model.startSearch(try #require(SearchPattern(keyword: "*")), root: URL(fileURLWithPath: "/r", isDirectory: true))
        searcher.send(existing)
        let loaded = await waitUntil { model.listing.files.count == existing.count }
        #expect(loaded, "既存の結果が一覧に入ること (実際: \(model.listing.files.count))")

        let start = ContinuousClock.now
        searcher.send(batch)
        while model.listing.files.count == existing.count, ContinuousClock.now - start < .seconds(5) {
            await Task.yield()
        }
        let elapsed = ContinuousClock.now - start
        #expect(model.listing.files.count == existing.count + batch.count)
        return elapsed
    }

    /// ディスクを使わない検索結果。`folders` 個のフォルダに分散する
    private func syntheticResults(count: Int, folders: Int, prefix: String, offset: Int = 0) -> [MediaFile] {
        (0..<count).map { index in
            let serial = index + offset
            let folder = "/r/folder-\(serial % folders)"
            let name = "\(prefix)_\((serial * 7_919) % 1_000_003).jpg"
            return MediaFile(
                url: URL(fileURLWithPath: "\(folder)/\(serial)-\(name)"),
                name: name,
                kind: .media(.jpeg),
                typeDescription: "JPEG イメージ",
                creationDate: nil,
                fileSize: 0
            )
        }
    }
}

@Test("10,000 行から 5,000 件を選んだ行番号変換が 100ms 未満（FR-016・SC-003）")
func selectionIndexTenThousandRows() {
    let urls = (0..<10_000).map {
        URL(fileURLWithPath: "/selection/\($0)", isDirectory: true)
    }
    var selected: Set<URL> = []
    selected.reserveCapacity(5_000)
    for index in stride(from: 0, to: urls.count, by: 2) {
        selected.insert(urls[index])
    }

    let start = ContinuousClock.now
    let indexes = SelectionIndex.indexes(of: selected, in: urls)
    let elapsed = ContinuousClock.now - start
    print("[perf] selection index 10,000 rows / 5,000 selected: \(elapsed)")
    #expect(indexes.count == 5_000)
    #expect(indexes.first == 0)
    #expect(indexes.last == 9_998)
    #expect(elapsed < .milliseconds(100), "選択同期が 100ms 以上止まらないこと")
}

/// 現在のプロセスの `phys_footprint`（バイト）。
private func physicalFootprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
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

/// テストから任意の時点で結果を流す検索器
private final class StreamingSearcher: FileNameSearching, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<[MediaFile]>.Continuation?

    func search(_ request: SearchRequest) -> AsyncStream<[MediaFile]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [MediaFile].self)
        lock.withLock { self.continuation = continuation }
        return stream
    }

    func send(_ batch: [MediaFile]) {
        let continuation = lock.withLock { self.continuation }
        continuation?.yield(batch)
    }
}

@MainActor
private final class PerformanceHistoryHost: HistoryPresentationHost {
    var presentation = HistoryPresentation(
        displayMode: .list,
        thumbnailSize: ViewSettings.defaultThumbnailSize,
        paneLayout: .all
    )

    var historyPresentation: HistoryPresentation { presentation }

    func applyHistoryPresentation(_ presentation: HistoryPresentation) {
        self.presentation = presentation
    }
}
