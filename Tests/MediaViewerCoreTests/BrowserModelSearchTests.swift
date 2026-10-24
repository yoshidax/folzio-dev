import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("BrowserModel の検索")
@MainActor
struct BrowserModelSearchTests {
    // MARK: - フィクスチャ

    /// 一時フォルダ `root`。`cover.jpg`・`trip/day1/1.jpg`・`trip/day2/`・`empty/` を持つ。
    /// 検索の起点は `SearchRoot.validate` の結果と同じく `/private` を付けない形（`/var/...`）で渡す
    private struct Env {
        let root: URL
        let defaults: UserDefaults
        let suite: String
        let model: BrowserModel
        let searcher: FakeSearcher

        func url(_ path: String) -> URL {
            root.appendingPathComponent(path)
        }

        func folder(_ path: String) -> URL {
            root.appendingPathComponent(path, isDirectory: true)
        }

        /// ディスクに画像（`.mp4`・`.mov` なら空の動画）を作り、検索結果の行を返す
        func makeResult(_ path: String) throws -> MediaFile {
            let url = url(path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let kind = try #require(MediaKind(fileExtension: url.pathExtension))
            if kind.isVideo {
                FileManager.default.createFile(atPath: url.path, contents: Data())
            } else {
                try ImageFixtures.jpeg(at: url, width: 32, height: 24)
            }
            return Self.result(url)
        }

        static func result(_ url: URL) -> MediaFile {
            let kind = MediaKind(fileExtension: url.pathExtension) ?? .jpeg
            return MediaFile(
                url: url,
                name: url.lastPathComponent,
                kind: .media(kind),
                typeDescription: kind.isVideo ? "ムービー" : "JPEG イメージ",
                creationDate: nil,
                fileSize: 0
            )
        }

        var viewSettings: ViewSettings {
            SettingsStore(defaults: defaults).viewSettings
        }

        var lastFolder: URL? {
            SettingsStore(defaults: defaults).viewSettings.lastFolder
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func makeEnv() throws -> Env {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserModelSearchTests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        for path in ["trip/day1", "trip/day2", "empty"] {
            try fileManager.createDirectory(
                at: root.appendingPathComponent(path, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        try ImageFixtures.jpeg(at: root.appendingPathComponent("cover.jpg"), width: 32, height: 24)
        try ImageFixtures.jpeg(at: root.appendingPathComponent("trip/day1/1.jpg"), width: 32, height: 24)

        let suite = "BrowserModelSearchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let searcher = FakeSearcher()
        let model = BrowserModel(
            lister: DirectoryLister(),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(costLimitBytes: 50_000_000),
            settings: SettingsStore(defaults: defaults),
            archiveReader: ZipArchiveReader(),
            searcher: searcher
        )
        model.setNavigationRoots([root])
        return Env(root: root, defaults: defaults, suite: suite, model: model, searcher: searcher)
    }

    private func pattern(_ keyword: String = "a") -> SearchPattern {
        SearchPattern(keyword: keyword)!
    }

    private func path(_ url: URL?) -> String? {
        url?.standardizedFileURL.path
    }

    private func names(_ model: BrowserModel) -> [String] {
        model.listing.files.map(\.name)
    }

    private func isEmptyPreview(_ preview: PreviewContent) -> Bool {
        if case .empty = preview { return true }
        return false
    }

    private func isImagePreview(_ preview: PreviewContent) -> Bool {
        if case .image = preview { return true }
        return false
    }

    private func waitUntil(timeout: Duration = .seconds(3), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    /// バッチを流し、一覧の件数が `count` になるまで待つ
    private func send(_ batch: [MediaFile], _ env: Env, expecting count: Int) async {
        env.searcher.send(batch)
        let arrived = await waitUntil { env.model.listing.search?.totalCount == count }
        #expect(arrived, "バッチが一覧に加わらなかった。totalCount: \(env.model.listing.search?.totalCount ?? -1)")
    }

    private func finish(_ env: Env) async {
        env.searcher.finish()
        let finished = await waitUntil { env.model.listing.search?.phase == .finished }
        #expect(finished)
    }

    // MARK: - 開始

    @Test("検索を始めると、検索前のフォルダ・lastFolder・ツリーの同期を変えずに、選択とプレビューを空にする")
    func startingSearchResetsSelectionOnly() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let day1 = env.folder("trip/day1")
        await env.model.selectFolder(day1)
        let image = try #require(env.model.listing.files.first { $0.name == "1.jpg" })
        env.model.select([image.url], focused: image.url)
        #expect(await waitUntil { isImagePreview(env.model.preview) })
        let lastFolder = env.lastFolder
        let syncRequest = env.model.treeSyncRequest

        env.model.startSearch(pattern(), root: env.root)

        #expect(env.model.isShowingSearchResults)
        let search = try #require(env.model.listing.search)
        #expect(search.keyword == "a")
        #expect(path(search.root) == path(env.root))
        #expect(search.phase == .searching)
        #expect(search.totalCount == 0)
        #expect(env.model.listing.state == .loading)
        #expect(env.model.selection.selected.isEmpty)
        #expect(env.model.selection.focused == nil)
        #expect(isEmptyPreview(env.model.preview))
        #expect(path(env.model.listing.folder) == path(day1))
        #expect(path(env.lastFolder) == path(lastFolder))
        #expect(env.model.treeSyncRequest == syncRequest)
        #expect(env.searcher.requests.count == 1)
    }

    @Test("動画のプレビュー中に検索を始めると再生を止める")
    func startingSearchStopsVideo() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        FileManager.default.createFile(atPath: env.url("clip.mp4").path, contents: Data())
        await env.model.selectFolder(env.root)
        let clip = try #require(env.model.listing.files.first { $0.name == "clip.mp4" })
        env.model.select([clip.url], focused: clip.url)
        guard case .video = env.model.preview else {
            Issue.record("動画のプレビューにならなかった")
            return
        }
        let signal = env.model.stopPlaybackSignal

        env.model.startSearch(pattern(), root: env.root)

        #expect(env.model.stopPlaybackSignal > signal)
    }

    // MARK: - バッチと完了

    @Test("バッチは並べ替え済みでマージされ、選択とフォーカスが保たれ、.. とフォルダの行がない")
    func batchesMergeAndKeepSelection() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.folder("trip"))
        #expect(env.model.listing.files.first?.kind == .parent)
        let b = try env.makeResult("s/b.jpg")
        let d = try env.makeResult("s/d.jpg")
        let a = try env.makeResult("s/a.jpg")
        let c = try env.makeResult("s/c.jpg")

        env.model.startSearch(pattern(), root: env.root)
        await send([b, d], env, expecting: 2)
        #expect(env.model.listing.state == .loaded)
        env.model.select([b.url], focused: b.url)
        #expect(await waitUntil { isImagePreview(env.model.preview) })

        await send([a, c], env, expecting: 4)

        #expect(names(env.model) == ["a.jpg", "b.jpg", "c.jpg", "d.jpg"])
        #expect(env.model.listing.state == .loaded)
        #expect(env.model.selection.selected == [b.url])
        #expect(env.model.selection.focused == b.url)
        #expect(isImagePreview(env.model.preview), "プレビューを読み直した: \(env.model.preview)")
        #expect(!env.model.listing.files.contains { $0.kind == .parent || $0.kind == .folder })
        #expect(env.model.hasEnclosingLevel == false)
    }

    @Test("ストリームが終わると finished。0 件なら empty")
    func finishing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.startSearch(pattern(), root: env.root)
        await finish(env)
        #expect(env.model.listing.state == .empty)

        let a = try env.makeResult("s/a.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([a], env, expecting: 1)
        await finish(env)
        #expect(env.model.listing.state == .loaded)
    }

    @Test("種類フィルタで 0 件なら noMatches で、totalCount は変わらない")
    func filterWithSearchResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let a = try env.makeResult("s/a.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([a], env, expecting: 1)
        await finish(env)

        env.model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))

        #expect(env.model.listing.state == .noMatches)
        #expect(env.model.listing.search?.totalCount == 1)
    }

    // MARK: - 解除と新しい検索

    @Test("フォルダを選ぶと検索を取り消して表示を終え、その後のバッチは加わらない")
    func selectingFolderLeavesSearch() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.folder("trip"))
        let a = try env.makeResult("s/a.jpg")
        env.model.startSearch(pattern(), root: env.root)
        env.model.setNavigationRoots([env.root, env.folder("empty")])
        #expect(!env.model.listing.files.contains { $0.kind == .parent })
        await send([a], env, expecting: 1)
        env.model.setNavigationRoots([env.root])
        #expect(!env.model.listing.files.contains { $0.kind == .parent })

        await env.model.selectFolder(env.folder("trip"))

        #expect(!env.model.isShowingSearchResults)
        #expect(await waitUntil { env.searcher.cancelledCount == 1 })
        env.searcher.send([try env.makeResult("s/z.jpg")])
        try await Task.sleep(for: .milliseconds(100))
        #expect(!names(env.model).contains("z.jpg"))
        #expect(!names(env.model).contains("a.jpg"))
        #expect(names(env.model) == ["..", "day1", "day2"])
    }

    @Test("結果の表示中に新しい検索を始めると、前の検索を取り消して結果を置き換える")
    func newSearchReplacesResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let a = try env.makeResult("s/a.jpg")
        let b = try env.makeResult("s/b.jpg")
        env.model.startSearch(pattern("a"), root: env.root)
        await send([a], env, expecting: 1)

        env.model.startSearch(pattern("b"), root: env.root)

        #expect(await waitUntil { env.searcher.cancelledCount == 1 })
        #expect(env.model.listing.search?.keyword == "b")
        #expect(env.model.listing.files.isEmpty)
        await send([b], env, expecting: 1)
        #expect(names(env.model) == ["b.jpg"])
    }

    @Test("zip の中で検索を始めると zip の状態を捨て、listing.folder は zip を含むフォルダのまま")
    func startingSearchInsideArchive() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        try ZipFixtureWriter.write(
            [ZipFixtureEntry(name: "01.jpg", content: .bytes(Data(count: 16)), method: .stored)],
            to: env.url("photos.zip")
        )
        env.model.setShowsZipFiles(true)
        await env.model.selectFolder(env.root)
        let zip = try #require(env.model.listing.files.first { $0.name == "photos.zip" })
        await env.model.openItem(zip.url)
        #expect(env.model.isBrowsingArchive)

        env.model.startSearch(pattern(), root: env.root)

        #expect(!env.model.isBrowsingArchive)
        #expect(path(env.model.listing.folder) == path(env.root))
    }

    // MARK: - zip ファイルの表示の切り替え（FR-098）

    @Test("検索結果の表示中に zip ファイルの表示を切り替えても、結果・選択・プレビューは変わらず設定だけを保存する")
    func togglingZipVisibilityDuringSearchChangesNothing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let x = try env.makeResult("b/a.jpg")
        let y = try env.makeResult("a/z.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([x, y], env, expecting: 2)
        env.model.select([x.url], focused: x.url)
        #expect(await waitUntil { isImagePreview(env.model.preview) })

        let files = env.model.listing.files.map(\.url)
        let state = env.model.listing.state
        let totalCount = env.model.listing.search?.totalCount
        let keyword = env.model.listing.search?.keyword
        #expect(!env.model.listing.files.contains { $0.kind == .archive })

        for shows in [true, false] {
            env.model.setShowsZipFiles(shows)

            #expect(env.defaults.object(forKey: "view.showsZipFiles") as? Bool == shows)
            #expect(env.model.isShowingSearchResults)
            #expect(env.model.listing.files.map(\.url) == files)
            #expect(env.model.listing.state == state)
            #expect(env.model.listing.search?.totalCount == totalCount)
            #expect(env.model.listing.search?.keyword == keyword)
            #expect(!env.model.listing.files.contains { $0.kind == .archive })
            #expect(env.model.selection.selected == [x.url])
            #expect(env.model.selection.focused == x.url)
            #expect(isImagePreview(env.model.preview))
        }
    }

    // MARK: - 並べ替え

    @Test("検索結果では場所で並べられ、保存されない。表示を終えると保存済みの並べ替えに戻る")
    func locationSortDuringSearch() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let saved = env.viewSettings.sortOrder
        let x = try env.makeResult("b/a.jpg")
        let y = try env.makeResult("a/z.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([x, y], env, expecting: 2)
        #expect(names(env.model) == ["a.jpg", "z.jpg"])

        env.model.sortOrder = SortOrder(column: .location, ascending: true)

        #expect(names(env.model) == ["z.jpg", "a.jpg"])
        #expect(env.viewSettings.sortOrder == saved)

        await env.model.selectFolder(env.root)
        #expect(env.model.sortOrder == saved)

        env.model.startSearch(pattern(), root: env.root)
        env.model.sortOrder = SortOrder(column: .kind, ascending: false)
        await env.model.selectFolder(env.root)
        #expect(env.model.sortOrder == SortOrder(column: .kind, ascending: false))
        #expect(env.viewSettings.sortOrder == SortOrder(column: .kind, ascending: false))
    }

    @Test("通常のフォルダでは場所への代入を受け付けず、設定と一覧を変えない")
    func locationSortRejectedOutsideSearch() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.sortOrder = SortOrder(column: .kind, ascending: false)
        await env.model.selectFolder(env.root)
        let before = env.model.sortOrder
        let files = names(env.model)
        let storedColumn = env.defaults.string(forKey: "view.sort.column")
        let storedAscending = env.defaults.object(forKey: "view.sort.ascending") as? Bool

        for ascending in [true, false] {
            env.model.sortOrder = SortOrder(column: .location, ascending: ascending)

            #expect(env.model.sortOrder == before)
            #expect(env.viewSettings.sortOrder == before)
            #expect(env.defaults.string(forKey: "view.sort.column") == storedColumn)
            #expect(env.defaults.object(forKey: "view.sort.ascending") as? Bool == storedAscending)
            #expect(names(env.model) == files)
        }
    }

    // MARK: - 結果の整理

    @Test("reloadCurrentFolder は消えた結果だけを外し、新しいファイルは加えない")
    func reloadPrunesMissingResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let a = try env.makeResult("s/a.jpg")
        let b = try env.makeResult("s/b.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([a, b], env, expecting: 2)
        env.model.select([a.url], focused: a.url)
        #expect(await waitUntil { isImagePreview(env.model.preview) })

        try FileManager.default.removeItem(at: a.url)
        _ = try env.makeResult("s/new-a.jpg")
        await env.model.reloadCurrentFolder()

        #expect(names(env.model) == ["b.jpg"])
        #expect(env.model.selection.focused == nil)
        #expect(env.model.selection.selected.isEmpty)
        #expect(isEmptyPreview(env.model.preview))
        #expect(env.model.listing.search?.totalCount == 1)
    }

    @Test("didRenameItem は行を差し替えて並べ直し、選択を新しい URL にする。対応メディアでなくなったら外す")
    func renamingResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let cat = try env.makeResult("s/cat.jpg")
        let dog = try env.makeResult("s/dog.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([cat, dog], env, expecting: 2)
        env.model.select([cat.url], focused: cat.url)

        let kitten = env.url("s/kitten.jpg")
        try FileManager.default.moveItem(at: cat.url, to: kitten)
        env.model.didRenameItem(at: cat.url, to: kitten)

        #expect(names(env.model) == ["dog.jpg", "kitten.jpg"])
        let row = try #require(env.model.listing.files.last)
        #expect(row.url == kitten)
        #expect(env.model.selection.selected == [kitten])
        #expect(env.model.selection.focused == kitten)

        let text = env.url("s/kitten.txt")
        try FileManager.default.moveItem(at: kitten, to: text)
        env.model.didRenameItem(at: kitten, to: text)
        #expect(names(env.model) == ["dog.jpg"])
        #expect(env.model.selection.focused == nil)
        #expect(isEmptyPreview(env.model.preview))

        await env.model.selectFolder(env.root)
        let cover = try #require(env.model.listing.files.first { $0.name == "cover.jpg" })
        let before = names(env.model)
        env.model.didRenameItem(at: cover.url, to: env.url("renamed.jpg"))
        #expect(names(env.model) == before)
    }

    @Test("handleFileSystemEvent は届いたフォルダ以下の結果だけを確かめ、検索前のフォルダが消えても親へ移らない")
    func fileSystemEventsPruneUnderFolders() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let day1 = env.folder("trip/day1")
        await env.model.selectFolder(day1)
        let sub = try env.makeResult("s/sub/a.jpg")
        let deep = try env.makeResult("s/sub/deep/b.jpg")
        let other = try env.makeResult("s/other/c.jpg")
        let kept = try env.makeResult("s/other/d.jpg")
        let renameSource = try env.makeResult("s/other/e.jpg")
        env.model.startSearch(pattern(), root: env.folder("s"))
        await send([sub, deep, other, kept, renameSource], env, expecting: 5)

        try FileManager.default.removeItem(at: sub.url)
        try FileManager.default.removeItem(at: other.url)
        await env.model.handleFileSystemEvent([env.folder("s/sub")])
        #expect(Set(names(env.model)) == ["b.jpg", "c.jpg", "d.jpg", "e.jpg"])

        try FileManager.default.removeItem(at: day1)
        await env.model.handleFileSystemEvent([day1])
        #expect(env.model.isShowingSearchResults)
        #expect(path(env.model.listing.folder) == path(day1))

        try FileManager.default.moveItem(at: env.folder("s/sub"), to: env.folder("moved-sub"))
        await env.model.handleFileSystemEvent([env.folder("s")])
        #expect(Set(names(env.model)) == ["d.jpg", "e.jpg"])

        let renamed = env.url("s/other/f.jpg")
        try FileManager.default.moveItem(at: renameSource.url, to: renamed)
        env.model.didRenameItem(at: renameSource.url, to: renamed)
        try FileManager.default.removeItem(at: renamed)
        await env.model.handleFileSystemEvent([env.folder("s/other")])
        #expect(names(env.model) == ["d.jpg"])
    }

    @Test("検索起点そのものが消えると、すべての結果を外して表示は続ける")
    func searchRootDisappears() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let day1 = env.folder("trip/day1")
        await env.model.selectFolder(day1)
        let lastFolder = env.lastFolder
        let syncRequest = env.model.treeSyncRequest
        let clip = try env.makeResult("s/x/clip.mp4")
        let image = try env.makeResult("s/y/a.jpg")
        let searchRoot = env.folder("s")
        env.model.startSearch(pattern(), root: searchRoot)
        await send([clip, image], env, expecting: 2)
        await finish(env)
        env.model.select([clip.url], focused: clip.url)
        let signal = env.model.stopPlaybackSignal

        try FileManager.default.removeItem(at: searchRoot)
        await env.model.handleFileSystemEvent([searchRoot])

        #expect(env.model.listing.files.isEmpty)
        #expect(env.model.listing.state == .empty)
        #expect(env.model.isShowingSearchResults)
        #expect(env.model.listing.search?.keyword == "a")
        #expect(path(env.model.listing.search?.root) == path(searchRoot))
        #expect(path(env.model.listing.folder) == path(day1))
        #expect(path(env.lastFolder) == path(lastFolder))
        #expect(env.model.treeSyncRequest == syncRequest)
        #expect(env.model.stopPlaybackSignal > signal)

        await env.model.reloadCurrentFolder()
        #expect(env.model.listing.files.isEmpty)
        #expect(env.model.listing.state == .empty)
        #expect(env.model.isShowingSearchResults)
    }

    @Test("leaveTrashedFolders は検索前のフォルダの祖先なら親へ移って表示を終え、無関係なら検索結果のまま")
    func trashingAncestorLeavesSearch() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.folder("trip/day1"))
        env.model.startSearch(pattern(), root: env.root)

        #expect(await env.model.leaveTrashedFolders([env.folder("empty")]) == false)
        #expect(env.model.isShowingSearchResults)

        try FileManager.default.removeItem(at: env.folder("trip"))
        #expect(await env.model.leaveTrashedFolders([env.folder("trip")]) == true)
        #expect(!env.model.isShowingSearchResults)
        #expect(path(env.model.listing.folder) == path(env.root))
    }

    // MARK: - フォルダの名前の変更（FR-105、EC-52、R63）

    private func renameFolder(_ env: Env, _ from: String, to newName: String) throws -> (URL, URL) {
        let old = env.folder(from)
        let new = old.deletingLastPathComponent().appendingPathComponent(newName, isDirectory: true)
        try FileManager.default.moveItem(at: old, to: new)
        return (old, new)
    }

    @Test("検索結果の表示中にフォルダの名前を変えると、結果は残って場所・選択が新しい名前になり、プレビューは変わらない")
    func renamingFolderRebasesResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.startSearch(pattern(), root: env.root)
        let photo = env.url("trip/day1/1.jpg")
        await send([Env.result(photo), Env.result(env.url("cover.jpg"))], env, expecting: 2)
        await finish(env)
        env.model.select([photo], focused: photo)
        #expect(await waitUntil { isImagePreview(env.model.preview) })
        let signal = env.model.stopPlaybackSignal

        let (old, new) = try renameFolder(env, "trip", to: "trip2")
        env.model.didRenameFolder(from: old, to: new)

        let moved = env.url("trip2/day1/1.jpg")
        let search = try #require(env.model.listing.search)
        #expect(search.totalCount == 2)
        #expect(env.model.listing.files.contains { path($0.url) == path(moved) })
        #expect(search.location(of: moved) == "\(env.root.lastPathComponent)/trip2/day1")
        #expect(path(env.model.selection.focused) == path(moved))
        #expect(isImagePreview(env.model.preview))
        #expect(env.model.stopPlaybackSignal == signal)
        #expect(env.searcher.requests.count == 1)

        // 外部の変更の確かめ直しでも、新しい場所の結果は外れない
        await env.model.reloadCurrentFolder()
        #expect(env.model.listing.search?.totalCount == 2)
    }

    @Test("「場所」で並べ替え中は、名前を変えた後の場所で並べ直す")
    func renamingFolderResortsByLocation() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let other = try env.makeResult("m/a.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([Env.result(env.url("trip/day1/1.jpg")), other], env, expecting: 2)
        await finish(env)
        env.model.sortOrder = SortOrder(column: .location, ascending: true)
        #expect(names(env.model) == ["a.jpg", "1.jpg"])

        let (old, new) = try renameFolder(env, "trip", to: "a-trip")
        env.model.didRenameFolder(from: old, to: new)

        #expect(names(env.model) == ["1.jpg", "a.jpg"])
    }

    @Test("検索起点そのものの名前を変えると、起点が新しい場所になり、結果は外れない")
    func renamingSearchRoot() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.startSearch(pattern(), root: env.folder("trip"))
        await send([Env.result(env.url("trip/day1/1.jpg"))], env, expecting: 1)
        await finish(env)

        let (old, new) = try renameFolder(env, "trip", to: "trip2")
        env.model.didRenameFolder(from: old, to: new)

        let search = try #require(env.model.listing.search)
        #expect(path(search.root) == path(env.folder("trip2")))
        #expect(search.totalCount == 1)
        #expect(search.location(of: env.url("trip2/day1/1.jpg")) == "trip2/day1")
        #expect(env.searcher.requests.count == 1)
    }

    @Test("検索中に名前を変えると、後から届く古い場所の結果も付け替え、新しい場所を追加で列挙して重複を除く（EC-52）")
    func renamingFolderWhileSearching() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.startSearch(pattern(), root: env.root)
        await send([Env.result(env.url("cover.jpg"))], env, expecting: 1)

        let (old, new) = try renameFolder(env, "trip", to: "trip2")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.searcher.requests.count == 2)
        #expect(path(env.searcher.requests.last?.root) == path(new))

        env.searcher.send([Env.result(env.url("trip/day1/1.jpg"))], to: 0)
        #expect(await waitUntil { env.model.listing.search?.totalCount == 2 })
        #expect(env.model.listing.files.contains { path($0.url) == path(env.url("trip2/day1/1.jpg")) })

        // 追加の列挙が同じファイルを返しても1行だけ
        env.searcher.send([Env.result(env.url("trip2/day1/1.jpg"))], to: 1)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(env.model.listing.search?.totalCount == 2)
        #expect(env.model.listing.files.filter { $0.name == "1.jpg" }.count == 1)

        env.searcher.finish(at: 0)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(env.model.listing.search?.phase == .searching)
        env.searcher.finish(at: 1)
        #expect(await waitUntil { env.model.listing.search?.phase == .finished })
    }

    @Test("検索中に検索起点そのものの名前を変えると、新しい起点を追加で列挙する")
    func renamingSearchRootWhileSearching() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.startSearch(pattern(), root: env.folder("trip"))

        let (old, new) = try renameFolder(env, "trip", to: "trip2")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.searcher.requests.count == 2)
        #expect(path(env.searcher.requests.last?.root) == path(new))
        #expect(path(env.model.listing.search?.root) == path(new))
    }

    @Test("検索中でも、検索起点の外のフォルダの名前を変えたときは追加で列挙しない")
    func renamingFolderOutsideSearchRoot() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.startSearch(pattern(), root: env.folder("trip"))

        let (old, new) = try renameFolder(env, "empty", to: "empty2")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.searcher.requests.count == 1)
        #expect(path(env.model.listing.search?.root) == path(env.folder("trip")))
    }
}

/// 結果をテストから任意の順・時点で流す検索器。取り消された回数を記録する
private final class FakeSearcher: FileNameSearching, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [AsyncStream<[MediaFile]>.Continuation] = []
    private var _requests: [(root: URL, pattern: SearchPattern)] = []
    private var _cancelledCount = 0

    var requests: [(root: URL, pattern: SearchPattern)] {
        lock.withLock { _requests }
    }

    var cancelledCount: Int {
        lock.withLock { _cancelledCount }
    }

    func search(in root: URL, matching pattern: SearchPattern) -> AsyncStream<[MediaFile]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [MediaFile].self)
        continuation.onTermination = { [weak self] reason in
            guard case .cancelled = reason, let self else { return }
            self.lock.withLock { self._cancelledCount += 1 }
        }
        lock.withLock {
            continuations.append(continuation)
            _requests.append((root, pattern))
        }
        return stream
    }

    /// 最後に始めた検索のストリームへバッチを流す
    func send(_ batch: [MediaFile]) {
        let continuation = lock.withLock { continuations.last }
        continuation?.yield(batch)
    }

    func finish() {
        let continuation = lock.withLock { continuations.last }
        continuation?.finish()
    }

    /// `index` 番目に始めた検索のストリームへバッチを流す
    func send(_ batch: [MediaFile], to index: Int) {
        let continuation = lock.withLock { continuations[index] }
        continuation.yield(batch)
    }

    func finish(at index: Int) {
        let continuation = lock.withLock { continuations[index] }
        continuation.finish()
    }
}
