import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("BrowserModel の zip")
@MainActor
struct BrowserModelArchiveTests {
    // MARK: - フィクスチャ

    /// 一時フォルダ。`cover.jpg` と `photos.zip`（`sub/deep/a.jpg`・`b.png`・`anim.gif`・`readme.txt`）を持つ
    private struct Env {
        let root: URL
        let zip: URL
        let defaults: UserDefaults
        let suite: String
        let model: BrowserModel

        func entry(_ path: String) -> URL {
            ArchiveURL.entry(archive: zip, path: path)
        }

        func parentLink(directory: String = "") -> URL {
            ArchiveURL.parentLink(of: ArchiveLocation(archive: zip, directory: directory))
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// `DirectoryLister` は `/private/var/...` の URL を返すため、同じ表記の一時フォルダを作る
    private func makeRootDirectory() throws -> URL {
        var root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserModelArchiveTests-\(UUID().uuidString)", isDirectory: true)
        if root.path.hasPrefix("/var/") {
            root = URL(fileURLWithPath: "/private" + root.path, isDirectory: true)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeEnv(entries: [ZipFixtureEntry]? = nil) throws -> Env {
        let root = try makeRootDirectory()

        try ImageFixtures.jpeg(at: root.appendingPathComponent("cover.jpg"), width: 32, height: 24)

        let zip = root.appendingPathComponent("photos.zip")
        let zipEntries: [ZipFixtureEntry]
        if let entries {
            zipEntries = entries
        } else {
            let work = FileManager.default.temporaryDirectory
                .appendingPathComponent("BrowserModelArchiveTests-work-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: work) }
            let jpeg = work.appendingPathComponent("a.jpg")
            let png = work.appendingPathComponent("b.png")
            let gif = work.appendingPathComponent("anim.gif")
            try ImageFixtures.jpeg(at: jpeg, width: 40, height: 30)
            try ImageFixtures.png(at: png, width: 20, height: 10)
            try ImageFixtures.animatedGIF(at: gif, frames: 3, width: 16, height: 16)
            zipEntries = [
                ZipFixtureEntry(name: "sub/deep/a.jpg", content: .bytes(try Data(contentsOf: jpeg)), method: .deflated),
                ZipFixtureEntry(name: "b.png", content: .bytes(try Data(contentsOf: png))),
                ZipFixtureEntry(name: "anim.gif", content: .bytes(try Data(contentsOf: gif))),
                ZipFixtureEntry(name: "readme.txt", content: .bytes(Data("hello".utf8))),
            ]
        }
        try ZipFixtureWriter.write(zipEntries, to: zip)

        let suite = "BrowserModelArchiveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(costLimitBytes: 50_000_000),
            settings: SettingsStore(defaults: defaults),
            archiveReader: ZipArchiveReader()
        )
        return Env(root: root, zip: zip, defaults: defaults, suite: suite, model: model)
    }

    private func smallJPEG() throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserModelArchiveTests-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try ImageFixtures.jpeg(at: url, width: 8, height: 8)
        return try Data(contentsOf: url)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func isEmptyPreview(_ preview: PreviewContent) -> Bool {
        if case .empty = preview { return true }
        return false
    }

    // MARK: - フォルダの一覧

    @Test("フォルダの一覧に zip ファイルと画像が並ぶ")
    func folderListsArchiveAndImage() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }

        await env.model.selectFolder(env.root)

        #expect(env.model.listing.state == .loaded)
        #expect(env.model.listing.archive == nil)
        #expect(env.model.listing.files.map(\.name) == ["cover.jpg", "photos.zip"])
        #expect(env.model.listing.files.last?.kind == .archive)
        #expect(env.model.isBrowsingArchive == false)
    }

    @Test("zip の行を選ぶとプレビューは空のまま")
    func selectingArchiveRowKeepsPreviewEmpty() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)

        env.model.select([env.zip], focused: env.zip)

        #expect(isEmptyPreview(env.model.preview))
    }

    @Test("動画の再生中に zip の行へ移ると停止の合図が増える")
    func movingFromVideoToArchiveStopsPlayback() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let video = env.root.appendingPathComponent("clip.mp4")
        try Data().write(to: video)
        await env.model.selectFolder(env.root)

        env.model.select([video], focused: video)
        guard case .video = env.model.preview else {
            Issue.record("preview should be video, got \(env.model.preview)")
            return
        }
        let before = env.model.stopPlaybackSignal

        env.model.select([env.zip], focused: env.zip)

        #expect(env.model.stopPlaybackSignal > before)
        #expect(isEmptyPreview(env.model.preview))
    }

    // MARK: - 中への移動

    @Test("zip の行を開くと最上位の一覧になる")
    func openArchiveShowsTopLevel() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        env.model.select([env.zip], focused: env.zip)

        await env.model.openItem(env.zip)

        let model = env.model
        #expect(model.listing.archive == ArchiveLocation(archive: env.zip, directory: ""))
        #expect(model.isBrowsingArchive)
        #expect(model.listing.folder == env.root)
        #expect(model.listing.state == .loaded)
        #expect(model.listing.files[0].kind == .parent)
        #expect(model.listing.files[0].url == env.parentLink())
        // 名前の自然順にディレクトリとメディアが混ざる
        #expect(model.listing.files.dropFirst().map(\.name) == ["anim.gif", "b.png", "sub"])
        #expect(model.listing.files.filter { $0.kind == .parent }.count == 1)
        #expect(model.selection.selected.isEmpty)
        #expect(model.selection.focused == nil)
        #expect(isEmptyPreview(model.preview))
    }

    @Test("並べ替えを変えても ... は先頭に1つだけ")
    func parentRowStaysFirstAfterSort() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)

        env.model.sortOrder = SortOrder(column: .name, ascending: false)

        #expect(env.model.listing.files.map(\.name) == ["..", "sub", "b.png", "anim.gif"])
    }

    @Test("ディレクトリを辿り、戻るたびに直前の行が選ばれる")
    func navigateDownAndUp() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)

        let sub = env.entry("sub/")
        let deep = env.entry("sub/deep/")
        let model = env.model

        await model.openItem(sub)
        #expect(model.listing.archive == ArchiveLocation(archive: env.zip, directory: "sub/"))
        #expect(model.listing.files.map(\.name) == ["..", "deep"])
        #expect(model.selection.selected.isEmpty)

        await model.openItem(deep)
        #expect(model.listing.archive?.directory == "sub/deep/")
        #expect(model.listing.files.map(\.name) == ["..", "a.jpg"])

        await model.goToEnclosingLevel()
        #expect(model.listing.archive?.directory == "sub/")
        #expect(model.selection.selected == [deep])
        #expect(model.selection.focused == deep)

        await model.goToEnclosingLevel()
        #expect(model.listing.archive?.directory == "")
        #expect(model.selection.selected == [sub])
        #expect(model.selection.focused == sub)

        await model.goToEnclosingLevel()
        #expect(model.listing.archive == nil)
        #expect(model.listing.folder == env.root)
        #expect(model.listing.files.map(\.name) == ["cover.jpg", "photos.zip"])
        #expect(model.selection.selected == [env.zip])
        #expect(model.selection.focused == env.zip)

        await model.goToEnclosingLevel()
        #expect(model.listing.archive == nil)
        #expect(model.selection.selected == [env.zip])
    }

    @Test(".. の行を開くと goToEnclosingLevel と同じ結果になる")
    func openParentRowGoesUp() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        await env.model.openItem(env.entry("sub/"))

        await env.model.openItem(env.parentLink(directory: "sub/"))

        #expect(env.model.listing.archive?.directory == "")
        #expect(env.model.selection.selected == [env.entry("sub/")])

        await env.model.openItem(env.parentLink())
        #expect(env.model.listing.archive == nil)
        #expect(env.model.selection.selected == [env.zip])
    }

    @Test("メディアの行と一覧にない URL の openItem は何もしない")
    func openMediaDoesNothing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        let cover = env.root.appendingPathComponent("cover.jpg")

        await env.model.openItem(cover)
        #expect(env.model.listing.archive == nil)
        #expect(env.model.listing.files.map(\.name) == ["cover.jpg", "photos.zip"])

        await env.model.openItem(env.zip)
        let before = env.model.listing.files.map(\.url)
        await env.model.openItem(env.entry("b.png"))
        await env.model.openItem(env.entry("missing/"))
        #expect(env.model.listing.files.map(\.url) == before)
        #expect(env.model.listing.archive?.directory == "")
    }

    @Test("lastFolder は zip に入っても戻っても一時フォルダのまま")
    func lastFolderStaysAtContainingFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        #expect(env.defaults.string(forKey: "view.lastFolderPath") == env.root.path)

        await env.model.openItem(env.zip)
        await env.model.openItem(env.entry("sub/"))
        #expect(env.defaults.string(forKey: "view.lastFolderPath") == env.root.path)

        await env.model.goToEnclosingLevel()
        await env.model.goToEnclosingLevel()
        await env.model.goToEnclosingLevel()
        #expect(env.defaults.string(forKey: "view.lastFolderPath") == env.root.path)
    }

    @Test("zip の中で別のフォルダを選ぶとそのフォルダの一覧になる")
    func selectFolderLeavesArchive() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let other = env.root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try ImageFixtures.png(at: other.appendingPathComponent("x.png"), width: 4, height: 4)
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)

        await env.model.selectFolder(other)

        #expect(env.model.listing.archive == nil)
        #expect(env.model.listing.folder == other)
        #expect(env.model.listing.files.map(\.name) == ["x.png"])
        #expect(env.model.isBrowsingArchive == false)
    }

    // MARK: - プレビュー

    @Test("zip の中の静止画は .image、アニメーション画像は .animatedImageData になる")
    func previewImageAndAnimated() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        let model = env.model

        let png = env.entry("b.png")
        model.select([png], focused: png)
        if case .loading(let url) = model.preview {
            #expect(url == png)
        } else {
            Issue.record("preview should be loading right after select, got \(model.preview)")
        }
        let isImage = await waitUntil {
            if case .image = model.preview { return true }
            return false
        }
        #expect(isImage)

        let gif = env.entry("anim.gif")
        model.select([gif], focused: gif)
        let isAnimated = await waitUntil {
            if case .animatedImageData(let url, let data) = model.preview {
                return url == gif && !data.isEmpty
            }
            return false
        }
        #expect(isAnimated)
    }

    @Test("zip の中のディレクトリと ... を選ぶとプレビューは空になる")
    func previewEmptyForDirectoryAndParent() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        let model = env.model

        let png = env.entry("b.png")
        model.select([png], focused: png)
        _ = await waitUntil {
            if case .image = model.preview { return true }
            return false
        }

        let sub = env.entry("sub/")
        model.select([sub], focused: sub)
        #expect(isEmptyPreview(model.preview))

        model.select([png], focused: png)
        model.select([env.parentLink()], focused: env.parentLink())
        #expect(isEmptyPreview(model.preview))
    }

    @Test("暗号化・非対応方式の画像は unavailable になる")
    func previewEncryptedEntry() async throws {
        let env = try makeEnv(entries: [
            ZipFixtureEntry(name: "secret.jpg", content: .bytes(Data(repeating: 1, count: 32)), encryptedFlag: true),
            ZipFixtureEntry(name: "odd.png", content: .bytes(Data(repeating: 1, count: 32)), method: .raw(99)),
        ])
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        let model = env.model

        let secret = env.entry("secret.jpg")
        model.select([secret], focused: secret)
        let isUnavailable = await waitUntil {
            if case .unavailable(let name, let reason) = model.preview {
                return name == "secret.jpg" && reason == "暗号化されているため表示できません"
            }
            return false
        }
        #expect(isUnavailable)

        let odd = env.entry("odd.png")
        model.select([odd], focused: odd)
        let isUnsupported = await waitUntil {
            if case .unavailable(let name, let reason) = model.preview {
                return name == "odd.png" && reason == "対応していない圧縮方式です"
            }
            return false
        }
        #expect(isUnsupported)
    }

    @Test("フォーカス前後の zip の中の画像を先読みする")
    func prefetchesArchiveNeighbors() async throws {
        let jpeg = try smallJPEG()
        let env = try makeEnv(entries: [
            ZipFixtureEntry(name: "a.jpg", content: .bytes(jpeg)),
            ZipFixtureEntry(name: "b.jpg", content: .bytes(jpeg)),
            ZipFixtureEntry(name: "c.jpg", content: .bytes(jpeg)),
        ])
        defer { env.cleanup() }
        let cache = DecodedImageCache(costLimitBytes: 50_000_000)
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: cache,
            settings: SettingsStore(defaults: env.defaults),
            archiveReader: ZipArchiveReader()
        )
        await model.selectFolder(env.root)
        await model.openItem(env.zip)

        let b = env.entry("b.jpg")
        model.select([b], focused: b)

        var cached = false
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            let a = await cache.get(env.entry("a.jpg"))
            let c = await cache.get(env.entry("c.jpg"))
            if a != nil, c != nil { cached = true; break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(cached)
    }

    // MARK: - 空の判定

    @Test("読める項目のない zip は .empty で ... だけが残る")
    func archiveWithoutMediaIsEmpty() async throws {
        let env = try makeEnv(entries: [
            ZipFixtureEntry(name: "readme.txt", content: .bytes(Data("hi".utf8))),
        ])
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)

        await env.model.openItem(env.zip)

        #expect(env.model.listing.files.map(\.kind) == [.parent])
        #expect(env.model.listing.state == .empty)
    }

    @Test("ディレクトリだけの zip は .loaded")
    func archiveWithOnlyDirectoryIsLoaded() async throws {
        let env = try makeEnv(entries: [
            ZipFixtureEntry(name: "docs/readme.txt", content: .bytes(Data("hi".utf8))),
            ZipFixtureEntry(name: "empty/", isDirectory: true),
        ])
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)

        await env.model.openItem(env.zip)

        #expect(env.model.listing.files.map(\.name) == ["..", "docs", "empty"])
        #expect(env.model.listing.state == .loaded)
    }

    @Test("画像だけの zip を動画のみにすると .noMatches")
    func videosOnlyOnImageArchiveIsNoMatches() async throws {
        let jpeg = try smallJPEG()
        let env = try makeEnv(entries: [
            ZipFixtureEntry(name: "a.jpg", content: .bytes(jpeg)),
            ZipFixtureEntry(name: "dir/b.jpg", content: .bytes(jpeg)),
        ])
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        #expect(env.model.listing.state == .loaded)

        env.model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))

        #expect(env.model.listing.files.map(\.name) == ["..", "dir"])
        #expect(env.model.listing.state == .noMatches)

        env.model.setMediaTypeFilter(MediaTypeFilter())
        #expect(env.model.listing.files.map(\.name) == ["..", "a.jpg", "dir"])
        #expect(env.model.listing.state == .loaded)
    }

    @Test("zip だけのフォルダは .loaded")
    func folderWithOnlyArchiveIsLoaded() async throws {
        let root = try makeRootDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try ZipFixtureWriter.write([ZipFixtureEntry(name: "a.txt")], to: root.appendingPathComponent("only.zip"))
        let suite = "BrowserModelArchiveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(costLimitBytes: 1_000_000),
            settings: SettingsStore(defaults: defaults)
        )

        await model.selectFolder(root)

        #expect(model.listing.files.map(\.name) == ["only.zip"])
        #expect(model.listing.state == .loaded)

        model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))
        #expect(model.listing.files.map(\.name) == ["only.zip"])
        #expect(model.listing.state == .loaded)
    }

    // MARK: - 失敗

    @Test("壊れた zip は .failed で、... から戻れる")
    func brokenArchiveFails() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let broken = env.root.appendingPathComponent("broken.zip")
        try Data("this is not a zip file at all".utf8).write(to: broken)
        await env.model.selectFolder(env.root)

        await env.model.openItem(broken)

        guard case .failed(let message) = env.model.listing.state else {
            Issue.record("state should be failed, got \(env.model.listing.state)")
            return
        }
        #expect(message.hasPrefix("zip を開けません: "))
        #expect(env.model.listing.files.map(\.kind) == [.parent])
        #expect(env.model.listing.archive == ArchiveLocation(archive: broken, directory: ""))

        await env.model.goToEnclosingLevel()

        #expect(env.model.listing.archive == nil)
        #expect(env.model.listing.state == .loaded)
        #expect(env.model.selection.selected == [broken])
    }

    // MARK: - FSEvents・再読み込み

    @Test("zip が書き換えられるとフォルダの一覧に戻る")
    func changedArchiveReturnsToFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        let png = env.entry("b.png")
        env.model.select([png], focused: png)

        try ZipFixtureWriter.write(
            [ZipFixtureEntry(name: "new.png", content: .bytes(Data(repeating: 2, count: 4096)))],
            to: env.zip
        )
        await env.model.handleFileSystemEvent([env.root])

        #expect(env.model.listing.archive == nil)
        #expect(env.model.listing.folder == env.root)
        #expect(env.model.listing.files.map(\.name) == ["cover.jpg", "photos.zip"])
        #expect(env.model.selection.selected.isEmpty)
        #expect(isEmptyPreview(env.model.preview))
    }

    @Test("zip が変わっていなければ zip の中のまま")
    func unchangedArchiveStays() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        await env.model.openItem(env.entry("sub/"))
        let before = env.model.listing.files.map(\.url)

        await env.model.handleFileSystemEvent([env.root])

        #expect(env.model.listing.archive == ArchiveLocation(archive: env.zip, directory: "sub/"))
        #expect(env.model.listing.files.map(\.url) == before)
    }

    @Test("zip が削除されるとフォルダの一覧に戻る")
    func deletedArchiveReturnsToFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)

        try FileManager.default.removeItem(at: env.zip)
        await env.model.handleFileSystemEvent([env.root])

        #expect(env.model.listing.archive == nil)
        #expect(env.model.listing.files.map(\.name) == ["cover.jpg"])
        #expect(isEmptyPreview(env.model.preview))
    }

    @Test("zip の中の reloadCurrentFolder は一覧を変えない")
    func reloadInsideArchiveKeepsListing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(env.zip)
        let before = env.model.listing.files.map(\.url)

        await env.model.reloadCurrentFolder()

        #expect(env.model.listing.archive == ArchiveLocation(archive: env.zip, directory: ""))
        #expect(env.model.listing.files.map(\.url) == before)
        #expect(env.model.listing.state == .loaded)
    }
}
