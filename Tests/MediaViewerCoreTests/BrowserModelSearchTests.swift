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

        static func folderResult(_ url: URL) -> MediaFile {
            DirectoryLister.folderRow(at: url, creationDate: nil, kindNames: FixtureKit.kindNames)
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
            kindNames: FixtureKit.kindNames,
            lister: DirectoryLister(kindNames: FixtureKit.kindNames),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(costLimitBytes: 50_000_000),
            settings: SettingsStore(defaults: defaults),
            archiveReader: ZipArchiveReader(kindNames: FixtureKit.kindNames),
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

    @Test("置き換え前の検索のバッチは、後から届いても結果に加わらない")
    func replacedSearchDropsOldBatches() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let a = try env.makeResult("s/a.jpg")
        let b = try env.makeResult("s/b.jpg")
        env.model.startSearch(pattern("a"), root: env.root)
        await send([a], env, expecting: 1)

        env.model.startSearch(pattern("b"), root: env.root)
        #expect(await waitUntil { env.searcher.cancelledCount == 1 })
        env.searcher.send([b], to: 1)
        #expect(await waitUntil { names(env.model) == ["b.jpg"] })
        env.searcher.send([a], to: 0)
        try await Task.sleep(for: .milliseconds(100))
        #expect(names(env.model) == ["b.jpg"], "失効したバッチは捨てる (実際: \(names(env.model)))")
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
        // 起点そのものは列挙の対象にしない（行にならない）
        #expect(env.searcher.requests.last?.matchesRoot == false)
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

    // MARK: - フォルダの行（US15、FR-139）

    /// ディスクにフォルダを作り、通常の一覧と同じ値のフォルダの行を返す
    private func makeFolderResult(_ env: Env, _ path: String) throws -> MediaFile {
        let url = env.folder(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return DirectoryLister.folderRow(
            at: url,
            creationDate: (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
            kindNames: FixtureKit.kindNames
        )
    }

    @Test("件数はフォルダとファイルの合計で、フォルダだけの一致と 0 件を区別する（US15-AS10・EC-32・EC-96）")
    func folderRowsCountTowardsTotal() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder1 = try makeFolderResult(env, "s/2024_Kyoto")
        let folder2 = try makeFolderResult(env, "s/kyoto")
        let image1 = try env.makeResult("s/kyoto_map.jpg")
        let image2 = try env.makeResult("s/a/kyoto_01.jpg")
        let image3 = try env.makeResult("s/b/kyoto_02.jpg")

        env.model.startSearch(pattern("kyoto"), root: env.root)
        await send([folder1, folder2, image1], env, expecting: 3)
        #expect(env.model.listing.search?.totalCount == 3)
        await send([image2, image3], env, expecting: 5)
        await finish(env)

        #expect(env.model.listing.search?.totalCount == 5)
        #expect(env.model.listing.search?.phase == .finished)
        #expect(env.model.listing.state == .loaded)
        #expect(env.model.listing.files.count == 5)

        // フォルダ1件だけの一致では、該当する項目がない旨を出さない
        env.model.startSearch(pattern("kyoto"), root: env.root)
        await send([folder1], env, expecting: 1)
        await finish(env)
        #expect(env.model.listing.state == .loaded)

        env.model.startSearch(pattern("kyoto"), root: env.root)
        await finish(env)
        #expect(env.model.listing.state == .empty)
        #expect(env.model.listing.search?.totalCount == 0)
    }

    @Test("種類フィルタはフォルダの行を隠さず、一致するメディアが残らなければ noMatches、フォルダだけなら loaded")
    func folderRowsWithTypeFilter() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let clips = try makeFolderResult(env, "s/clips")
        let video = try env.makeResult("s/kyoto_clip.mp4")

        env.model.startSearch(pattern("clip"), root: env.root)
        await send([clips, video], env, expecting: 2)
        await finish(env)

        env.model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))

        #expect(names(env.model) == ["clips"])
        #expect(env.model.listing.state == .noMatches)
        #expect(env.model.listing.search?.totalCount == 2)
        #expect(env.model.mediaTypeFilter.emptyState == .imagesOnly)

        // 一致がフォルダだけなら、絞り込み中のメッセージも出さない
        env.model.startSearch(pattern("clip"), root: env.root)
        await send([clips], env, expecting: 1)
        await finish(env)
        #expect(names(env.model) == ["clips"])
        #expect(env.model.listing.state == .loaded)
    }

    @Test("フォルダの行にフォーカスを移すとプレビューが空になり、再生中の動画を止める（US15-AS4）")
    func focusingFolderRowClearsPreviewAndStopsVideo() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeFolderResult(env, "s/kyoto")
        let video = try env.makeResult("s/kyoto_clip.mp4")

        env.model.startSearch(pattern("kyoto"), root: env.root)
        await send([folder, video], env, expecting: 2)
        await finish(env)

        env.model.select([video.url], focused: video.url)
        guard case .video = env.model.preview else {
            Issue.record("動画のプレビューにならなかった")
            return
        }
        let signal = env.model.stopPlaybackSignal

        env.model.select([folder.url], focused: folder.url)

        #expect(isEmptyPreview(env.model.preview))
        #expect(env.model.stopPlaybackSignal > signal)
        #expect(env.model.selection.focused == folder.url)
    }

    @Test("名前・作成日・場所の並べ替えで、フォルダとファイルが区別なく混ざって並ぶ（FR-084・A-25）")
    func folderRowsSortMixedWithMedia() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folderA = try makeFolderResult(env, "s/2024_Kyoto")
        let folderB = try makeFolderResult(env, "s/zzz_Kyoto")
        var image = try env.makeResult("s/m_Kyoto.jpg")
        var video = try env.makeResult("s/n_Kyoto.mp4")

        image.creationDate = Date(timeIntervalSince1970: 1_000)
        video.creationDate = Date(timeIntervalSince1970: 2_000)
        var datedFolderA = folderA
        datedFolderA.creationDate = Date(timeIntervalSince1970: 3_000)
        var datedFolderB = folderB
        datedFolderB.creationDate = Date(timeIntervalSince1970: 4_000)

        env.model.startSearch(pattern("Kyoto"), root: env.root)
        await send([datedFolderA, datedFolderB], env, expecting: 2)
        await send([image, video], env, expecting: 4)
        await finish(env)

        env.model.sortOrder = SortOrder(column: .name, ascending: true)
        #expect(names(env.model) == ["2024_Kyoto", "m_Kyoto.jpg", "n_Kyoto.mp4", "zzz_Kyoto"])

        env.model.sortOrder = SortOrder(column: .creationDate, ascending: true)
        #expect(names(env.model) == ["m_Kyoto.jpg", "n_Kyoto.mp4", "2024_Kyoto", "zzz_Kyoto"])

        env.model.sortOrder = SortOrder(column: .location, ascending: true)
        #expect(names(env.model) == ["2024_Kyoto", "m_Kyoto.jpg", "n_Kyoto.mp4", "zzz_Kyoto"])

        // 種類の並べ替えでもフォルダの行は外れない
        env.model.sortOrder = SortOrder(column: .kind, ascending: true)
        #expect(Set(names(env.model)) == ["2024_Kyoto", "zzz_Kyoto", "m_Kyoto.jpg", "n_Kyoto.mp4"])
        #expect(env.model.listing.state == .loaded)
    }

    @Test("検索結果の一覧の先頭に .. の行はない（FR-084）")
    func searchResultsHaveNoParentRow() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.folder("trip/day1"))
        let folder = try makeFolderResult(env, "s/kyoto")
        let image = try env.makeResult("s/kyoto_map.jpg")

        env.model.startSearch(pattern("kyoto"), root: env.root)
        await send([folder, image], env, expecting: 2)

        #expect(!env.model.listing.files.contains { $0.kind == .parent })
        #expect(!names(env.model).contains(".."))
    }

    // MARK: - フォルダの行を開く（FR-140、US15-AS3、EC-93）

    @Test("検索中にフォルダの行を開くと検索を止め、そのフォルダの一覧にしてツリーと lastFolder を同期し、後から届く結果を捨てる")
    func openingFolderRowDuringSearch() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.folder("trip"))
        let day2 = try makeFolderResult(env, "trip/day2")

        env.model.startSearch(pattern(), root: env.root)
        await send([day2], env, expecting: 1)
        env.model.select([day2.url], focused: day2.url)

        await env.model.openItem(day2.url)

        #expect(await waitUntil { env.searcher.cancelledCount == 1 })
        #expect(!env.model.isShowingSearchResults)
        #expect(env.model.listing.search == nil)
        #expect(path(env.model.listing.folder) == path(day2.url))
        #expect(env.model.listing.files.first?.kind == .parent)
        #expect(path(env.model.treeSyncRequest?.folder) == path(day2.url))
        #expect(path(env.lastFolder) == path(day2.url))

        // 止めた列挙のバッチは一覧に混ざらない
        let late = try env.makeResult("s/late.jpg")
        env.searcher.send([late], to: 0)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!names(env.model).contains("late.jpg"))
        // day2 は空のフォルダ
        #expect(Set(names(env.model)) == [".."])
    }

    @Test("検索が終わった後にフォルダの行を開いても同じ")
    func openingFolderRowAfterSearchFinished() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.folder("trip"))
        let day1 = try makeFolderResult(env, "trip/day1")

        env.model.startSearch(pattern(), root: env.root)
        await send([day1], env, expecting: 1)
        await finish(env)

        await env.model.openItem(day1.url)

        #expect(!env.model.isShowingSearchResults)
        #expect(path(env.model.listing.folder) == path(day1.url))
        #expect(env.model.listing.files.first?.kind == .parent)
        #expect(path(env.lastFolder) == path(day1.url))
        #expect(path(env.model.treeSyncRequest?.folder) == path(day1.url))
    }

    @Test("「場所」で並べ替え中にフォルダの行を開くと、保存済みの並べ替えに戻る")
    func openingFolderRowRestoresSortOrder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let saved = env.viewSettings.sortOrder
        let day1 = try makeFolderResult(env, "trip/day1")
        env.model.startSearch(pattern(), root: env.root)
        await send([day1], env, expecting: 1)
        env.model.sortOrder = SortOrder(column: .location, ascending: true)

        await env.model.openItem(day1.url)

        #expect(env.model.sortOrder == saved)
        #expect(env.viewSettings.sortOrder == saved)
    }

    @Test("メディアの行を開いても何も変わらない")
    func openingMediaRowDoesNothing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let image = try env.makeResult("s/a.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([image], env, expecting: 1)
        let folder = env.model.listing.folder
        let request = env.model.treeSyncRequest

        await env.model.openItem(image.url)

        #expect(env.model.isShowingSearchResults)
        #expect(path(env.model.listing.folder) == path(folder))
        #expect(env.model.treeSyncRequest == request)
        #expect(env.searcher.cancelledCount == 0)
    }

    @Test("検索結果から開いたときだけ openedSearchResultFolder を知らせ、通常の一覧では navigated のまま")
    func openingFolderRowSendsOpenedSearchResultFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        var events: [LocationEvent] = []
        env.model.onLocationEvent = { events.append($0) }

        await env.model.selectFolder(env.folder("trip"))
        let day2 = try makeFolderResult(env, "trip/day2")
        env.model.startSearch(pattern(), root: env.root)
        await send([day2], env, expecting: 1)
        env.model.select([day2.url], focused: day2.url)
        events.removeAll()

        await env.model.openItem(day2.url)

        #expect(events == [.openedSearchResultFolder(leavingFocus: day2.url)])

        // 通常の一覧からフォルダを開いた場合は、従来どおり navigated を知らせる
        await env.model.selectFolder(env.folder("trip"))
        events.removeAll()
        let day1 = try #require(env.model.listing.files.first { $0.name == "day1" })
        await env.model.openItem(day1.url)
        #expect(events.count == 1, "受け取った通知: \(events)")
        #expect(events.first == .navigated(leavingFocus: nil))
    }

    @Test("読み取り権限のないフォルダの行を開くと accessDenied の表示になり、.. で戻れる")
    func openingUnreadableFolderRow() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let locked = try makeFolderResult(env, "s/locked")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.url.path) }

        await env.model.selectFolder(env.folder("trip"))
        env.model.startSearch(pattern(), root: env.root)
        await send([locked], env, expecting: 1)

        await env.model.openItem(locked.url)

        #expect(!env.model.isShowingSearchResults)
        #expect(env.model.listing.state == .denied)
        #expect(env.model.listing.files.first?.kind == .parent)
    }

    // MARK: - ツリー同期の完了（EC-102）

    @Test("検索結果から開いたフォルダの同期完了では、表示可能な祖先を最後のフォルダとして保存する")
    func completeSearchResultTreeSyncSavesVisibleAncestor() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let visible = env.root
        let open = try makeFolderResult(env, ".hidden-parent/search-root/kyoto_open")
        var events: [LocationEvent] = []
        env.model.onLocationEvent = { events.append($0) }

        env.model.startSearch(pattern("kyoto"), root: env.folder(".hidden-parent/search-root"))
        await send([open], env, expecting: 1)
        await env.model.openItem(open.url)
        let request = try #require(env.model.treeSyncRequest)
        let focused = env.model.selection.focused
        events.removeAll()

        env.model.completeSearchResultTreeSync(request, selectedFolder: visible)

        #expect(path(env.lastFolder) == path(visible))
        #expect(path(env.model.listing.folder) == path(open.url))
        #expect(env.model.treeSyncRequest == request)
        #expect(env.model.selection.focused == focused)
        #expect(events.isEmpty)

        // 重複した完了は無視する
        env.model.completeSearchResultTreeSync(request, selectedFolder: env.folder(".hidden-parent"))
        #expect(path(env.lastFolder) == path(visible))
    }

    @Test("同期完了で選択できた場所が開いたフォルダ自身なら、その場所を保存する")
    func completeSearchResultTreeSyncSavesSelectedFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let open = try makeFolderResult(env, ".hidden-parent/search-root/kyoto_open")

        env.model.startSearch(pattern("kyoto"), root: env.folder(".hidden-parent/search-root"))
        await send([open], env, expecting: 1)
        await env.model.openItem(open.url)
        let request = try #require(env.model.treeSyncRequest)

        env.model.completeSearchResultTreeSync(request, selectedFolder: open.url)

        #expect(path(env.lastFolder) == path(open.url))
    }

    @Test("古い依頼・別の依頼・祖先でない場所・通常のナビゲーションの同期は保存先を変えない")
    func completeSearchResultTreeSyncRejectsInvalidRequests() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let open = try makeFolderResult(env, ".hidden-parent/search-root/kyoto_open")
        let sibling = try makeFolderResult(env, ".hidden-parent/search-root/kyoto_open2")

        env.model.startSearch(pattern("kyoto"), root: env.folder(".hidden-parent/search-root"))
        await send([open], env, expecting: 1)
        await env.model.openItem(open.url)
        let request = try #require(env.model.treeSyncRequest)
        let saved = env.lastFolder

        // 古い ID・別の依頼
        env.model.completeSearchResultTreeSync(TreeSyncRequest(folder: open.url, id: request.id - 1), selectedFolder: env.root)
        #expect(path(env.lastFolder) == path(saved))
        env.model.completeSearchResultTreeSync(TreeSyncRequest(folder: open.url, id: request.id + 1), selectedFolder: env.root)
        #expect(path(env.lastFolder) == path(saved))

        // 祖先でない場所（文字列の前方が同じ兄弟も含む）
        env.model.completeSearchResultTreeSync(request, selectedFolder: sibling.url)
        #expect(path(env.lastFolder) == path(saved))
        env.model.completeSearchResultTreeSync(request, selectedFolder: env.folder("trip"))
        #expect(path(env.lastFolder) == path(saved))

        // 通常の一覧から開いた依頼は対象外
        let day1 = try makeFolderResult(env, "trip/day1")
        await env.model.selectFolder(env.root)
        await env.model.openItem(day1.url)
        let normalRequest = try #require(env.model.treeSyncRequest)
        let normalSaved = env.lastFolder
        env.model.completeSearchResultTreeSync(normalRequest, selectedFolder: env.root)
        #expect(path(env.lastFolder) == path(normalSaved))
    }

    @Test("次のナビゲーションの後は、同じフォルダを再表示していても古い同期完了を無視する")
    func completeSearchResultTreeSyncIgnoresAfterNavigation() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let open = try makeFolderResult(env, ".hidden-parent/search-root/kyoto_open")

        env.model.startSearch(pattern("kyoto"), root: env.folder(".hidden-parent/search-root"))
        await send([open], env, expecting: 1)
        await env.model.openItem(open.url)
        let request = try #require(env.model.treeSyncRequest)

        // 別の移動（resetForNavigation）の後に同じフォルダを通常の一覧として表示し直す
        await env.model.selectFolder(env.folder("trip"))
        await env.model.selectFolder(open.url)
        let saved = env.lastFolder

        env.model.completeSearchResultTreeSync(request, selectedFolder: env.root)
        #expect(path(env.lastFolder) == path(saved))
    }

    @Test("見つからなかったフォルダの同期完了では保存しない")
    func completeSearchResultTreeSyncIgnoresNotFound() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let open = try makeFolderResult(env, ".hidden-parent/search-root/kyoto_open")

        env.model.startSearch(pattern("kyoto"), root: env.folder(".hidden-parent/search-root"))
        await send([open], env, expecting: 1)
        try FileManager.default.removeItem(at: open.url)
        await env.model.openItem(open.url)
        let request = try #require(env.model.treeSyncRequest)

        env.model.completeSearchResultTreeSync(request, selectedFolder: env.root)

        #expect(path(env.lastFolder) == path(open.url))
    }

    // MARK: - ファイル操作・外部の変更（US15、FR-087・105、EC-35・36・94・95・101）

    private func location(_ env: Env, of url: URL) -> String? {
        env.model.listing.search?.location(of: url)
    }

    @Test("フォルダの行の名前を変えると、行と中の結果が新しい名前になり、選択・フォーカスが新しい URL で保たれる")
    func renamingFolderRow() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeFolderResult(env, "trip/F")
        let child = try env.makeResult("trip/F/g.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([folder, child], env, expecting: 2)
        await finish(env)
        env.model.select([child.url], focused: child.url)
        #expect(await waitUntil { isImagePreview(env.model.preview) })

        let renamed = env.folder("trip/zzz")
        try FileManager.default.moveItem(at: folder.url, to: renamed)
        env.model.didRenameFolder(from: folder.url, to: renamed)

        let row = try #require(env.model.listing.files.first { $0.kind == .folder })
        #expect(row.name == "zzz")
        #expect(path(row.url) == path(renamed))
        let movedChild = try #require(env.model.listing.files.first { $0.name == "g.jpg" })
        #expect(path(movedChild.url) == path(renamed.appendingPathComponent("g.jpg")))
        #expect(location(env, of: movedChild.url) == "\(env.root.lastPathComponent)/trip/zzz")
        #expect(path(env.model.selection.focused) == path(movedChild.url))
        #expect(env.model.selection.selected == [movedChild.url])
        #expect(isImagePreview(env.model.preview))
        #expect(env.model.listing.search?.totalCount == 2)

        // 「名前」で並べ替え中なら、新しい名前で並べ直す
        env.model.sortOrder = SortOrder(column: .name, ascending: true)
        #expect(names(env.model) == ["g.jpg", "zzz"])
    }

    @Test("フォルダの行の名前を変えた後に削除すると、行と中の結果が両方外れる")
    func renamedFolderRowIsRemovedWithItsResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeFolderResult(env, "trip/F")
        let child = try env.makeResult("trip/F/g.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([folder, child], env, expecting: 2)
        await finish(env)

        let renamed = env.folder("trip/zzz")
        try FileManager.default.moveItem(at: folder.url, to: renamed)
        env.model.didRenameFolder(from: folder.url, to: renamed)
        try FileManager.default.removeItem(at: renamed)

        await env.model.reloadCurrentFolder()

        #expect(env.model.listing.files.isEmpty)
        #expect(env.model.listing.search?.totalCount == 0)
        #expect(env.model.listing.state == .empty)
        #expect(env.model.isShowingSearchResults)
    }

    @Test("中の結果を開いているフォルダを名前の変更の後に削除すると、プレビューが空になり件数が減る")
    func deletingRenamedFolderClearsPreview() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeFolderResult(env, "trip/F")
        let child = try env.makeResult("trip/F/g.jpg")
        let other = try env.makeResult("trip/other.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([folder, child, other], env, expecting: 3)
        await finish(env)

        let renamed = env.folder("trip/zzz")
        try FileManager.default.moveItem(at: folder.url, to: renamed)
        env.model.didRenameFolder(from: folder.url, to: renamed)
        let movedChild = try #require(env.model.listing.files.first { $0.name == "g.jpg" })
        env.model.select([movedChild.url], focused: movedChild.url)
        #expect(await waitUntil { isImagePreview(env.model.preview) })

        try FileManager.default.removeItem(at: renamed)
        await env.model.reloadCurrentFolder()

        #expect(names(env.model) == ["other.jpg"])
        #expect(env.model.listing.search?.totalCount == 1)
        #expect(env.model.selection.focused == nil)
        #expect(isEmptyPreview(env.model.preview))
    }

    @Test("アプリの外でフォルダを移すと行と中の結果が外れ、新しく現れたフォルダは加わらない")
    func externallyMovedFolderIsRemoved() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeFolderResult(env, "trip/F")
        let child = try env.makeResult("trip/F/g.jpg")
        let other = try env.makeResult("trip/a.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([folder, child, other], env, expecting: 3)
        await finish(env)

        let outside = env.folder("moved/F")
        try FileManager.default.createDirectory(at: outside.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: folder.url, to: outside)
        try FileManager.default.createDirectory(at: env.folder("trip/kyoto_new"), withIntermediateDirectories: true)
        await env.model.handleFileSystemEvent([env.folder("trip")])

        #expect(names(env.model) == ["a.jpg"])
        #expect(env.model.listing.search?.totalCount == 1)
        #expect(env.model.isShowingSearchResults)
    }

    @Test("フォルダの行を複製したフォルダは結果に加わらない")
    func copiedFolderIsNotAdded() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeFolderResult(env, "trip/F")
        let child = try env.makeResult("trip/F/g.jpg")
        env.model.startSearch(pattern(), root: env.root)
        await send([folder, child], env, expecting: 2)
        await finish(env)

        try FileManager.default.copyItem(at: folder.url, to: env.folder("trip/F copy"))
        await env.model.reloadCurrentFolder()

        #expect(env.model.listing.search?.totalCount == 2)
        #expect(!names(env.model).contains("F copy"))
    }

    @Test("検索の起点の外にあるフォルダの名前の変更では結果が変わらない")
    func renamingFolderOutsideRootChangesNothing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeFolderResult(env, "trip/F")
        env.model.startSearch(pattern(), root: env.folder("trip"))
        await send([folder], env, expecting: 1)
        await finish(env)
        let before = env.model.listing.files.map(\.url)

        let (old, new) = try renameFolder(env, "empty", to: "empty2")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.model.listing.files.map(\.url) == before)
        #expect(env.searcher.requests.count == 1)
    }

    @Test("検索が終わった後の、行でないフォルダの名前の変更では追加の列挙を始めない（EC-94 の前半）")
    func renamingNonRowFolderAfterSearchDoesNotEnumerate() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let row = try makeFolderResult(env, "trip/F")
        let hidden = try makeFolderResult(env, "trip/zzz-inner")
        env.model.startSearch(pattern(), root: env.folder("trip"))
        await send([row], env, expecting: 1)
        await finish(env)
        let count = env.model.listing.files.count
        let totalCount = env.model.listing.search?.totalCount
        let requests = env.searcher.requests.count

        let (old, new) = try renameFolder(env, "trip/zzz-inner", to: "F-inner")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.searcher.requests.count == requests)
        #expect(env.model.listing.files.count == count)
        #expect(env.model.listing.search?.totalCount == totalCount)
        #expect(!names(env.model).contains("F-inner"))
        _ = hidden
    }

    @Test("検索結果の一覧から検索前のフォルダの祖先をゴミ箱に入れると、表示を続けて行を外す（EC-101）")
    func trashingSearchFolderAncestorFromFileListKeepsResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let day1 = env.folder("trip/day1")
        await env.model.selectFolder(day1)
        let parent = try makeFolderResult(env, "trip")
        let inside = try env.makeResult("trip/trip_photo.jpg")
        var events: [LocationEvent] = []
        env.model.onLocationEvent = { events.append($0) }
        env.model.startSearch(pattern("trip"), root: env.root)
        await send([parent, inside], env, expecting: 2)
        await finish(env)
        let lastFolder = env.lastFolder
        let request = env.model.treeSyncRequest

        try FileManager.default.removeItem(at: env.folder("trip"))

        #expect(await env.model.leaveTrashedFolders([env.folder("trip")], origin: .fileList) == false)
        #expect(env.model.isShowingSearchResults)
        #expect(path(env.model.listing.folder) == path(day1))
        #expect(path(env.lastFolder) == path(lastFolder))
        #expect(env.model.treeSyncRequest == request)
        #expect(events.isEmpty)

        await env.model.reloadCurrentFolder()
        #expect(names(env.model).isEmpty)

        // Esc と同じ経路で検索結果の表示を終えると、検索前のフォルダが見つからないことを知らせる
        let target = env.model.listing.folder
        await env.model.selectFolder(target)
        #expect(!env.model.isShowingSearchResults)
        // 移ろうとした通知の後に、見つからなかったことを知らせる
        #expect(events.last == .notFound(HistoryLocation(folder: day1)), "受け取った通知: \(events)")
    }

    @Test("検索結果の一覧から検索前のフォルダの祖先をゴミ箱に入れた場合も、ツリーからの経路では親へ移る")
    func trashingSearchFolderAncestorFromTreeLeavesSearch() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.folder("trip/day1"))
        let parent = try makeFolderResult(env, "trip")
        env.model.startSearch(pattern("trip"), root: env.root)
        await send([parent], env, expecting: 1)
        await finish(env)

        try FileManager.default.removeItem(at: env.folder("trip"))

        #expect(await env.model.leaveTrashedFolders([env.folder("trip")], origin: .tree) == true)
        #expect(!env.model.isShowingSearchResults)
        #expect(path(env.model.listing.folder) == path(env.root))
    }

    @Test("検索結果の一覧で検索前のフォルダの祖先を移すと行を外し、表示を続ける（EC-101 の移動）")
    func movingSearchFolderAncestorKeepsResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let day1 = env.folder("trip/day1")
        await env.model.selectFolder(day1)
        let parent = try makeFolderResult(env, "trip")
        let inside = try env.makeResult("trip/trip_photo.jpg")
        var events: [LocationEvent] = []
        env.model.onLocationEvent = { events.append($0) }
        env.model.startSearch(pattern("trip"), root: env.root)
        await send([parent, inside], env, expecting: 2)
        await finish(env)
        let lastFolder = env.lastFolder
        let request = env.model.treeSyncRequest

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserModelSearchTests-moved-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: env.folder("trip"), to: destination.appendingPathComponent("trip"))

        await env.model.reloadCurrentFolder()

        #expect(env.model.isShowingSearchResults)
        #expect(env.model.listing.files.isEmpty)
        #expect(path(env.model.listing.folder) == path(day1))
        #expect(path(env.lastFolder) == path(lastFolder))
        #expect(env.model.treeSyncRequest == request)

        await env.model.selectFolder(env.model.listing.folder)
        // 移ろうとした通知の後に、見つからなかったことを知らせる
        #expect(events.last == .notFound(HistoryLocation(folder: day1)), "受け取った通知: \(events)")
    }

    @Test("検索の起点がフォルダの行と中の結果ごと消えても、すべて外して表示を続ける（EC-36）")
    func searchRootDisappearsWithFolderRows() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let day1 = env.folder("trip/day1")
        await env.model.selectFolder(day1)
        let child = try makeFolderResult(env, "s/x")
        let other = try makeFolderResult(env, "s/y")
        let clip = try env.makeResult("s/x/clip.mp4")
        let image = try env.makeResult("s/y/a.jpg")
        let searchRoot = env.folder("s")
        env.model.startSearch(pattern(), root: searchRoot)
        await send([child, other, clip, image], env, expecting: 4)
        await finish(env)
        env.model.select([clip.url], focused: clip.url)
        let signal = env.model.stopPlaybackSignal
        let lastFolder = env.lastFolder
        let request = env.model.treeSyncRequest

        try FileManager.default.removeItem(at: searchRoot)
        await env.model.handleFileSystemEvent([searchRoot])

        #expect(env.model.listing.files.isEmpty)
        #expect(env.model.listing.state == .empty)
        #expect(env.model.isShowingSearchResults)
        #expect(env.model.listing.search?.keyword == "a")
        #expect(path(env.model.listing.search?.root) == path(searchRoot))
        #expect(path(env.model.listing.folder) == path(day1))
        #expect(path(env.lastFolder) == path(lastFolder))
        #expect(env.model.treeSyncRequest == request)
        #expect(env.model.stopPlaybackSignal > signal)
    }

    // MARK: - 検索中の名前の変更（EC-52・EC-94、FR-105）

    private func makeEmptyFolder(_ env: Env, _ path: String) throws -> URL {
        let url = env.folder(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("照合済みのフォルダの名前を変えると、追加の列挙は新しい場所を照合せず、行は加わらない（EC-94 の前半）")
    func renamingVisitedFolderDoesNotRecheckTheFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeEmptyFolder(env, "trip/zzz")
        env.model.startSearch(pattern("b"), root: env.folder("trip"))
        #expect(env.searcher.requests.count == 1)
        // 列挙0は F を照合して記録したが、名前が一致しないため行を流していない
        env.searcher.requests[0].visits.record(folder.path)

        let (old, new) = try renameFolder(env, "trip/zzz", to: "bbb")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.searcher.requests.count == 2)
        #expect(path(env.searcher.requests.last?.root) == path(new))
        #expect(env.searcher.requests.last?.matchesRoot == false)
        #expect(env.model.listing.search?.totalCount == 0)
    }

    @Test("未照合のフォルダの名前を変えると新しい場所を起点として照合し、古い場所の行は捨てる（EC-94 の後半）")
    func renamingUnvisitedFolderRechecksTheFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeEmptyFolder(env, "trip/zzz")
        env.model.startSearch(pattern("b"), root: env.folder("trip"))

        let (old, new) = try renameFolder(env, "trip/zzz", to: "bbb")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.searcher.requests.count == 2)
        #expect(path(env.searcher.requests.last?.root) == path(new))
        #expect(env.searcher.requests.last?.matchesRoot == true)

        // 名前の変更の前に列挙を始めた列挙0から届いた古い場所の行は捨てる
        env.searcher.send([Env.folderResult(old)], to: 0)
        try await Task.sleep(for: .milliseconds(100))
        #expect(env.model.listing.search?.totalCount == 0)

        // 追加の列挙から届いた行だけが新しい名前で残る
        env.searcher.send([Env.folderResult(new)], to: 1)
        #expect(await waitUntil { env.model.listing.search?.totalCount == 1 })
        let row = try #require(env.model.listing.files.first)
        #expect(row.name == "bbb")
        #expect(path(row.url) == path(new))
        #expect(row.kind == .folder)
    }

    @Test("照合済みで一致したフォルダの行は新しい名前で残り、後から届いた中の結果は新しい場所で加わる（EC-52）")
    func renamingVisitedFolderKeepsRowAndReroutesResults() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeEmptyFolder(env, "trip/bbb")
        env.model.startSearch(pattern("b"), root: env.folder("trip"))
        env.searcher.requests[0].visits.record(folder.path)
        await send([Env.folderResult(folder)], env, expecting: 1)

        // キーワードに一致しなくなっても行は外れない
        let (old, new) = try renameFolder(env, "trip/bbb", to: "zzz")
        env.model.didRenameFolder(from: old, to: new)

        let row = try #require(env.model.listing.files.first)
        #expect(row.name == "zzz")
        #expect(path(row.url) == path(new))

        // 名前の変更より前に始めた列挙0から届いた中の結果は、新しい場所で加わる
        let inside = new.appendingPathComponent("b-1.jpg")
        env.searcher.send([Env.result(old.appendingPathComponent("b-1.jpg"))], to: 0)
        #expect(await waitUntil { env.model.listing.search?.totalCount == 2 })
        #expect(env.model.listing.files.contains { path($0.url) == path(inside) }, "一覧: \(names(env.model))")
    }

    @Test("名前の変更の後に届いた照合済みのフォルダの行は、新しい URL と名前で加わる")
    func visitedFolderRowArrivingAfterRenameUsesNewName() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let folder = try makeEmptyFolder(env, "trip/zzz")
        env.model.startSearch(pattern("b"), root: env.folder("trip"))
        env.searcher.requests[0].visits.record(folder.path)

        let (old, new) = try renameFolder(env, "trip/zzz", to: "bbb")
        env.model.didRenameFolder(from: old, to: new)

        env.searcher.send([Env.folderResult(old)], to: 0)

        #expect(await waitUntil { env.model.listing.search?.totalCount == 1 })
        let row = try #require(env.model.listing.files.first)
        #expect(row.name == "bbb")
        #expect(path(row.url) == path(new))
    }
}

/// 結果をテストから任意の順・時点で流す検索器。取り消された回数を記録する
private final class FakeSearcher: FileNameSearching, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [AsyncStream<[MediaFile]>.Continuation] = []
    private var _requests: [(root: URL, pattern: SearchPattern, matchesRoot: Bool, visits: SearchVisitLog)] = []
    private var _cancelledCount = 0

    var requests: [(root: URL, pattern: SearchPattern, matchesRoot: Bool, visits: SearchVisitLog)] {
        lock.withLock { _requests }
    }

    var cancelledCount: Int {
        lock.withLock { _cancelledCount }
    }

    func search(_ request: SearchRequest) -> AsyncStream<[MediaFile]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [MediaFile].self)
        continuation.onTermination = { [weak self] reason in
            guard case .cancelled = reason, let self else { return }
            self.lock.withLock { self._cancelledCount += 1 }
        }
        lock.withLock {
            continuations.append(continuation)
            _requests.append((request.root, request.pattern, request.matchesRoot, request.visits))
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
