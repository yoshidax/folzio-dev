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
