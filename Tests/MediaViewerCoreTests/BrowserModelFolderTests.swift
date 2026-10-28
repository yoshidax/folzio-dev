import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("BrowserModel のフォルダ")
@MainActor
struct BrowserModelFolderTests {
    // MARK: - フィクスチャ

    /// 一時フォルダ `root`。`cover.jpg`・`trip/day1/1.jpg`・`trip/day2/`・`empty/`・`only/inner/` を持つ
    private struct Env {
        let root: URL
        let defaults: UserDefaults
        let suite: String
        let model: BrowserModel

        func url(_ path: String) -> URL {
            root.appendingPathComponent(path, isDirectory: true)
        }

        /// 一覧の行のうち、パスが `path` のもの
        @MainActor
        func row(_ path: String) -> MediaFile? {
            let target = url(path).standardizedFileURL.path
            return model.listing.files.first { $0.url.standardizedFileURL.path == target }
        }

        /// 保存された最後のフォルダ（FR-003）
        var lastFolder: URL? {
            SettingsStore(defaults: defaults).viewSettings.lastFolder
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// `DirectoryLister` は `/private/var/...` の URL を返すため、同じ表記の一時フォルダを作る
    private func makeEnv(roots: [String] = [""]) throws -> Env {
        var root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserModelFolderTests-\(UUID().uuidString)", isDirectory: true)
        if root.path.hasPrefix("/var/") {
            root = URL(fileURLWithPath: "/private" + root.path, isDirectory: true)
        }
        let fileManager = FileManager.default
        for path in ["trip/day1", "trip/day2", "empty", "only/inner"] {
            try fileManager.createDirectory(
                at: root.appendingPathComponent(path, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        try ImageFixtures.jpeg(at: root.appendingPathComponent("cover.jpg"), width: 32, height: 24)
        try ImageFixtures.jpeg(at: root.appendingPathComponent("trip/day1/1.jpg"), width: 32, height: 24)

        let suite = "BrowserModelFolderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let model = BrowserModel(
            kindNames: FixtureKit.kindNames,
            lister: DirectoryLister(kindNames: FixtureKit.kindNames),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(costLimitBytes: 50_000_000),
            settings: SettingsStore(defaults: defaults),
            archiveReader: ZipArchiveReader(kindNames: FixtureKit.kindNames)
        )
        model.setNavigationRoots(roots.map { root.appendingPathComponent($0, isDirectory: true) })
        return Env(root: root, defaults: defaults, suite: suite, model: model)
    }

    private func path(_ url: URL?) -> String? {
        url?.standardizedFileURL.path
    }

    private func isEmptyPreview(_ preview: PreviewContent) -> Bool {
        if case .empty = preview { return true }
        return false
    }

    private func setPermissions(_ permissions: Int, of url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }

    // MARK: - フォルダの行と ..

    @Test("ツリーのルートの一覧には .. がなく、フォルダとファイルが名前の順に並び、戻る操作は何もしない")
    func rootHasNoParentRow() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)

        #expect(env.model.listing.files.map(\.name) == ["cover.jpg", "empty", "only", "trip"])
        #expect(env.row("trip")?.kind == .folder)
        #expect(!env.model.listing.files.contains { $0.kind == .parent })
        #expect(env.model.hasEnclosingLevel == false)

        await env.model.goToEnclosingLevel()
        #expect(path(env.model.listing.folder) == path(env.root))
        #expect(env.model.treeSyncRequest == nil)
    }

    @Test("フォルダの行を開くと、その一覧になり、.. が先頭に入り、lastFolder と同期の依頼が更新される")
    func openingFolderNavigates() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        let trip = try #require(env.row("trip"))

        await env.model.openItem(trip.url)

        #expect(path(env.model.listing.folder) == path(env.url("trip")))
        let first = try #require(env.model.listing.files.first)
        #expect(first.kind == .parent)
        #expect(first.name == "..")
        #expect(ParentLink.isParentLink(first.url))
        #expect(env.model.listing.files.dropFirst().map(\.name) == ["day1", "day2"])
        #expect(env.model.selection.selected.isEmpty)
        #expect(isEmptyPreview(env.model.preview))
        #expect(path(env.lastFolder) == path(env.url("trip")))
        #expect(path(env.model.treeSyncRequest?.folder) == path(env.url("trip")))
        #expect(env.model.hasEnclosingLevel == true)
    }

    @Test(".. と goToEnclosingLevel で親へ戻り、直前のフォルダの行が選ばれる")
    func goingUpSelectsPreviousFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(try #require(env.row("trip")).url)
        await env.model.openItem(try #require(env.row("trip/day1")).url)
        let idBeforeUp = try #require(env.model.treeSyncRequest?.id)

        await env.model.goToEnclosingLevel()

        #expect(path(env.model.listing.folder) == path(env.url("trip")))
        let day1 = try #require(env.row("trip/day1"))
        #expect(env.model.selection.selected == [day1.url])
        #expect(env.model.selection.focused == day1.url)
        #expect(path(env.model.treeSyncRequest?.folder) == path(env.url("trip")))
        #expect((env.model.treeSyncRequest?.id ?? 0) > idBeforeUp)
        #expect(path(env.lastFolder) == path(env.url("trip")))

        // .. の行を開いても同じ結果になる
        await env.model.openItem(day1.url)
        let parent = try #require(env.model.listing.files.first { $0.kind == .parent })
        await env.model.openItem(parent.url)
        #expect(path(env.model.listing.folder) == path(env.url("trip")))
        #expect(env.model.selection.focused == env.row("trip/day1")?.url)

        // もう一度戻るとルートで、trip が選ばれ、.. はない
        await env.model.goToEnclosingLevel()
        #expect(path(env.model.listing.folder) == path(env.root))
        #expect(env.model.selection.focused == env.row("trip")?.url)
        #expect(!env.model.listing.files.contains { $0.kind == .parent })
    }

    @Test("ツリーからの選択では同期の依頼を出さないが、ルート以外なら .. は出る")
    func selectFolderDoesNotRequestTreeSync() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }

        await env.model.selectFolder(env.url("trip/day2"))

        #expect(env.model.treeSyncRequest == nil)
        #expect(env.model.hasEnclosingLevel == true)
        #expect(env.model.listing.files.map(\.kind) == [.parent])
    }

    @Test("ルートが空なら .. を出さず、setNavigationRoots で読み直さずに .. が入る")
    func navigationRootsControlParentRow() async throws {
        let env = try makeEnv(roots: [])
        defer { env.cleanup() }
        await env.model.selectFolder(env.url("trip"))

        #expect(env.model.listing.files.map(\.name) == ["day1", "day2"])
        #expect(env.model.hasEnclosingLevel == false)

        env.model.setNavigationRoots([env.root])

        #expect(env.model.listing.files.map(\.name) == ["..", "day1", "day2"])
        #expect(env.model.hasEnclosingLevel == true)

        env.model.setNavigationRoots([env.url("trip")])
        #expect(env.model.listing.files.map(\.name) == ["day1", "day2"])
    }

    // MARK: - 空の判定（FR-060）と種類フィルタ

    @Test("空のフォルダは .. だけで .empty、フォルダだけのフォルダは .loaded")
    func emptyStates() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }

        await env.model.selectFolder(env.url("empty"))
        #expect(env.model.listing.files.map(\.kind) == [.parent])
        #expect(env.model.listing.state == .empty)

        await env.model.selectFolder(env.url("only"))
        #expect(env.model.listing.files.map(\.name) == ["..", "inner"])
        #expect(env.model.listing.state == .loaded)
    }

    @Test("種類フィルタでもフォルダは残り、メディアが元々ない階層は .loaded のまま")
    func filterKeepsFolders() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        env.model.setMediaTypeFilter(MediaTypeFilter(videosOnly: true))

        await env.model.selectFolder(env.url("trip"))
        #expect(env.model.listing.files.map(\.name) == ["..", "day1", "day2"])
        #expect(env.model.listing.state == .loaded)

        await env.model.selectFolder(env.url("trip/day1"))
        #expect(env.model.listing.files.map(\.kind) == [.parent])
        #expect(env.model.listing.state == .noMatches)
    }

    // MARK: - 読めないフォルダ（FR-077）

    @Test("権限のないフォルダへ入ると .. だけが残り、.. で戻れる")
    func deniedFolderKeepsParentRow() async throws {
        let env = try makeEnv()
        let locked = env.url("locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try setPermissions(0o000, of: locked)
        defer {
            try? setPermissions(0o755, of: locked)
            env.cleanup()
        }
        await env.model.selectFolder(env.root)

        await env.model.openItem(try #require(env.row("locked")).url)

        #expect(env.model.listing.state == .denied)
        #expect(env.model.listing.files.map(\.kind) == [.parent])

        await env.model.openItem(try #require(env.model.listing.files.first).url)
        #expect(path(env.model.listing.folder) == path(env.root))
        #expect(env.model.selection.focused == env.row("locked")?.url)
    }

    @Test("存在しないフォルダと、読み直しで読めなくなったフォルダでも .. だけが残る")
    func failedFolderKeepsParentRow() async throws {
        let env = try makeEnv()
        let trip = env.url("trip")
        defer {
            try? setPermissions(0o755, of: trip)
            env.cleanup()
        }

        // standardizedFileURL は存在するパスだけ先頭の /private を外すため、存在しないフォルダは外した表記で作る
        let missing = env.root.standardizedFileURL.appendingPathComponent("missing", isDirectory: true)
        await env.model.selectFolder(missing)
        if case .failed = env.model.listing.state {} else {
            Issue.record("state should be failed, got \(env.model.listing.state)")
        }
        #expect(env.model.listing.files.map(\.kind) == [.parent])

        await env.model.selectFolder(trip)
        try setPermissions(0o000, of: trip)
        await env.model.reloadCurrentFolder()
        #expect(env.model.listing.state == .denied)
        #expect(env.model.listing.files.map(\.kind) == [.parent])
    }

    @Test("ルートが読めないときは .. も出さない")
    func deniedRootHasNoParentRow() async throws {
        let env = try makeEnv()
        defer {
            try? setPermissions(0o755, of: env.root)
            env.cleanup()
        }
        try setPermissions(0o000, of: env.root)

        await env.model.selectFolder(env.root)

        #expect(env.model.listing.state == .denied)
        #expect(env.model.listing.files.isEmpty)
    }

    // MARK: - プレビュー・操作の対象

    @Test("フォルダの行を選ぶとプレビューは空になり、再生中の動画は止まる")
    func selectingFolderClearsPreview() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let video = env.root.appendingPathComponent("clip.mp4")
        try Data().write(to: video)
        await env.model.selectFolder(env.root)

        let clip = try #require(env.model.listing.files.first { $0.name == "clip.mp4" })
        env.model.select([clip.url], focused: clip.url)
        guard case .video = env.model.preview else {
            Issue.record("preview should be video, got \(env.model.preview)")
            return
        }
        let before = env.model.stopPlaybackSignal

        let trip = try #require(env.row("trip"))
        env.model.select([trip.url], focused: trip.url)

        #expect(isEmptyPreview(env.model.preview))
        #expect(env.model.stopPlaybackSignal > before)
    }

    @Test("operableSelection は一覧の並び順で .. を除く")
    func operableSelectionExcludesParent() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.url("trip"))
        let parent = try #require(env.model.listing.files.first { $0.kind == .parent })
        let day1 = try #require(env.row("trip/day1"))
        let day2 = try #require(env.row("trip/day2"))

        env.model.select([day2.url, parent.url, day1.url], focused: parent.url)
        #expect(env.model.operableSelection == [day1.url, day2.url])

        env.model.select([parent.url], focused: parent.url)
        #expect(env.model.operableSelection.isEmpty)
    }

    // MARK: - 同期の依頼を出さない経路

    @Test("zip の中の移動では同期の依頼と lastFolder が変わらない")
    func archiveNavigationDoesNotRequestTreeSync() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let zip = env.root.appendingPathComponent("a.zip")
        try ZipFixtureWriter.write(
            [ZipFixtureEntry(name: "sub/x.png", content: .bytes(Data([0x89, 0x50])))],
            to: zip
        )
        env.model.setShowsZipFiles(true)
        await env.model.selectFolder(env.root)
        let lastFolder = env.lastFolder

        await env.model.openItem(try #require(env.model.listing.files.first { $0.name == "a.zip" }).url)
        #expect(env.model.isBrowsingArchive)
        await env.model.goToEnclosingLevel()

        #expect(env.model.treeSyncRequest == nil)
        #expect(path(env.lastFolder) == path(lastFolder))
    }

    @Test("表示中のフォルダが外部で消えて親へ移っても、同期の依頼は出さない")
    func fileSystemEventDoesNotRequestTreeSync() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.url("trip/day2"))
        try FileManager.default.removeItem(at: env.url("trip/day2"))

        await env.model.handleFileSystemEvent([env.model.listing.folder])

        #expect(path(env.model.listing.folder) == path(env.url("trip")))
        #expect(env.model.treeSyncRequest == nil)
    }

    // MARK: - ゴミ箱に入れたフォルダから出る（FR-079）

    @Test("表示中のフォルダ自身を消すと、親の一覧になり、選択とプレビューが空で、同期の依頼が増える")
    func leavingTrashedShowingFolder() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(try #require(env.row("trip")).url)
        await env.model.openItem(try #require(env.row("trip/day1")).url)
        let idBefore = try #require(env.model.treeSyncRequest?.id)
        try FileManager.default.removeItem(at: env.url("trip/day1"))

        let moved = await env.model.leaveTrashedFolders([env.url("trip/day1")])

        #expect(moved == true)
        #expect(path(env.model.listing.folder) == path(env.url("trip")))
        #expect(env.model.listing.state == .loaded)
        #expect(env.model.selection.selected.isEmpty)
        #expect(env.model.selection.focused == nil)
        #expect(isEmptyPreview(env.model.preview))
        #expect(path(env.lastFolder) == path(env.url("trip")))
        #expect(path(env.model.treeSyncRequest?.folder) == path(env.url("trip")))
        #expect(try #require(env.model.treeSyncRequest?.id) > idBefore)
        #expect(env.row("trip/day1") == nil)
        #expect(env.row("trip/day2") != nil)
    }

    @Test("表示中のフォルダの祖先を消すと、その親の一覧になる")
    func leavingTrashedAncestor() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(try #require(env.row("trip")).url)
        await env.model.openItem(try #require(env.row("trip/day1")).url)
        try FileManager.default.removeItem(at: env.url("trip"))

        let moved = await env.model.leaveTrashedFolders([env.url("trip")])

        #expect(moved == true)
        #expect(path(env.model.listing.folder) == path(env.root))
        #expect(env.row("trip") == nil)
    }

    @Test("無関係なフォルダを消しても、一覧・選択・同期の依頼は変わず false を返す")
    func leavingUnrelatedFolderDoesNothing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(try #require(env.row("trip")).url)
        await env.model.openItem(try #require(env.row("trip/day1")).url)
        let day1Image = try #require(env.model.listing.files.first { $0.name == "1.jpg" })
        env.model.select([day1Image.url], focused: day1Image.url)
        let requestBefore = env.model.treeSyncRequest
        let selectionBefore = env.model.selection.selected
        try FileManager.default.removeItem(at: env.url("empty"))

        let moved = await env.model.leaveTrashedFolders([env.url("empty")])

        #expect(moved == false)
        #expect(path(env.model.listing.folder) == path(env.url("trip/day1")))
        #expect(env.model.selection.selected == selectionBefore)
        #expect(env.model.treeSyncRequest == requestBefore)
    }

    @Test("空の配列では false を返し、何も変わらない")
    func leavingNothingDoesNothing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        await env.model.openItem(try #require(env.row("trip")).url)
        let requestBefore = env.model.treeSyncRequest

        let moved = await env.model.leaveTrashedFolders([])

        #expect(moved == false)
        #expect(path(env.model.listing.folder) == path(env.url("trip")))
        #expect(env.model.treeSyncRequest == requestBefore)
    }

    @Test("動画のプレビュー中に表示中のフォルダを消すと、停止の合図が増える")
    func leavingTrashedFolderStopsVideo() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        try VideoFixtures.mp4(at: env.url("trip/day1").appendingPathComponent("clip.mp4"), seconds: 0.5)
        await env.model.selectFolder(env.root)
        await env.model.openItem(try #require(env.row("trip")).url)
        await env.model.openItem(try #require(env.row("trip/day1")).url)
        let clip = try #require(env.model.listing.files.first { $0.name == "clip.mp4" })
        env.model.select([clip.url], focused: clip.url)
        guard case .video = env.model.preview else {
            Issue.record("preview should be video, got \(env.model.preview)")
            return
        }
        let before = env.model.stopPlaybackSignal
        try FileManager.default.removeItem(at: env.url("trip/day1"))

        let moved = await env.model.leaveTrashedFolders([env.url("trip/day1")])

        #expect(moved == true)
        #expect(env.model.stopPlaybackSignal > before)
        #expect(isEmptyPreview(env.model.preview))
    }

    @Test("zip の中を表示中に、zip を含むフォルダを消すと、zip の状態を捨てて親の一覧になる")
    func leavingTrashedFolderContainingOpenArchive() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let jpeg = env.root.appendingPathComponent("cover.jpg")
        try ZipFixtureWriter.write(
            [ZipFixtureEntry(name: "a.jpg", content: .bytes(try Data(contentsOf: jpeg)), method: .deflated)],
            to: env.url("trip").appendingPathComponent("photos.zip")
        )
        env.model.setShowsZipFiles(true)
        await env.model.selectFolder(env.root)
        await env.model.openItem(try #require(env.row("trip")).url)
        await env.model.openItem(try #require(env.row("trip/photos.zip")).url)
        #expect(env.model.isBrowsingArchive)
        try FileManager.default.removeItem(at: env.url("trip"))

        let moved = await env.model.leaveTrashedFolders([env.url("trip")])

        #expect(moved == true)
        #expect(env.model.isBrowsingArchive == false)
        #expect(path(env.model.listing.folder) == path(env.root))
    }

    // MARK: - フォルダの名前の変更（FR-104、R62）

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

    /// `trip/day1` を表示して `1.jpg` をプレビューした状態にする
    private func showDay1Photo(_ env: Env) async throws -> URL {
        await env.model.selectFolder(env.url("trip/day1"))
        let photo = try #require(env.row("trip/day1/1.jpg")).url
        env.model.select([photo], focused: photo)
        #expect(await waitUntil { isImagePreview(env.model.preview) })
        return photo
    }

    private func rename(_ env: Env, _ from: String, to newName: String) throws -> (URL, URL) {
        let old = env.url(from)
        let new = old.deletingLastPathComponent().appendingPathComponent(newName, isDirectory: true)
        try FileManager.default.moveItem(at: old, to: new)
        return (old, new)
    }

    @Test("表示中のフォルダの祖先の名前を変えると、一覧・選択・lastFolder が新しい場所になり、プレビューは変わらない")
    func renamingAncestorRebasesListing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        _ = try await showDay1Photo(env)
        let signal = env.model.stopPlaybackSignal

        let (old, new) = try rename(env, "trip", to: "trip2")
        env.model.didRenameFolder(from: old, to: new)

        #expect(path(env.model.listing.folder) == path(env.url("trip2/day1")))
        #expect(path(env.model.selection.focused) == path(env.url("trip2/day1/1.jpg")))
        #expect(env.model.selection.selected.map { path($0) } == [path(env.url("trip2/day1/1.jpg"))])
        #expect(env.row("trip2/day1/1.jpg") != nil)
        #expect(env.model.listing.files.first?.url == ParentLink.url(for: env.url("trip2/day1")))
        #expect(isImagePreview(env.model.preview))
        #expect(env.model.stopPlaybackSignal == signal)
        #expect(path(env.lastFolder) == path(env.url("trip2/day1")))

        // ⌘↑ は新しい名前のフォルダへ戻る（US1-AS40）
        await env.model.goToEnclosingLevel()
        #expect(path(env.model.listing.folder) == path(env.url("trip2")))
    }

    @Test("表示中のフォルダ自身の名前を変えた後、古い場所のイベントが届いても親へ移らない")
    func renamingDisplayedFolderIgnoresOldEvents() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        _ = try await showDay1Photo(env)

        let (old, new) = try rename(env, "trip/day1", to: "day1x")
        env.model.didRenameFolder(from: old, to: new)
        await env.model.handleFileSystemEvent([old, env.url("trip")])

        #expect(path(env.model.listing.folder) == path(env.url("trip/day1x")))
        #expect(path(env.model.selection.focused) == path(env.url("trip/day1x/1.jpg")))
        #expect(env.row("trip/day1x/1.jpg") != nil)
        #expect(isImagePreview(env.model.preview))
    }

    @Test("親の一覧を表示中にフォルダの名前を変えると、行の名前が変わって並び順の位置へ移り、選択は残る")
    func renamingFolderRowInParentListing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        await env.model.selectFolder(env.root)
        let trip = try #require(env.row("trip")).url
        env.model.select([trip], focused: trip)

        let (old, new) = try rename(env, "trip", to: "a-trip")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.model.listing.files.map(\.name) == ["a-trip", "cover.jpg", "empty", "only"])
        #expect(env.row("a-trip")?.kind == .folder)
        #expect(path(env.model.selection.focused) == path(env.url("a-trip")))
    }

    @Test("zip の中を表示中に zip を含むフォルダの名前を変えても、一覧はそのままで、別の項目を新しい場所から読める（EC-50）")
    func renamingFolderContainingOpenArchive() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let jpeg = try Data(contentsOf: env.root.appendingPathComponent("cover.jpg"))
        try ZipFixtureWriter.write(
            [
                ZipFixtureEntry(name: "a.jpg", content: .bytes(jpeg), method: .deflated),
                ZipFixtureEntry(name: "b.jpg", content: .bytes(jpeg), method: .deflated),
            ],
            to: env.url("trip").appendingPathComponent("photos.zip")
        )
        env.model.setShowsZipFiles(true)
        await env.model.selectFolder(env.url("trip"))
        await env.model.openItem(try #require(env.row("trip/photos.zip")).url)
        let names = env.model.listing.files.map(\.name)

        let (old, new) = try rename(env, "trip", to: "trip2")
        env.model.didRenameFolder(from: old, to: new)

        let newZip = env.url("trip2").appendingPathComponent("photos.zip")
        #expect(path(env.model.listing.archive?.archive) == path(newZip))
        #expect(env.model.listing.files.map(\.name) == names)
        let b = try #require(env.model.listing.files.first { $0.name == "b.jpg" })
        #expect(ArchiveURL.parse(b.url).map { path($0.archive) } == path(newZip))
        env.model.select([b.url], focused: b.url)
        #expect(await waitUntil { isImagePreview(env.model.preview) })

        await env.model.goToEnclosingLevel()
        #expect(env.model.isBrowsingArchive == false)
        #expect(path(env.model.listing.folder) == path(env.url("trip2")))
        #expect(env.model.selection.focused.map { path($0) } == path(newZip))
    }

    @Test("関係のないフォルダの名前を変えても、一覧・選択・lastFolder は変わらない")
    func renamingUnrelatedFolderChangesNothing() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let photo = try await showDay1Photo(env)
        let files = env.model.listing.files.map(\.url)

        let (old, new) = try rename(env, "empty", to: "empty2")
        env.model.didRenameFolder(from: old, to: new)

        #expect(env.model.listing.files.map(\.url) == files)
        #expect(env.model.selection.focused == photo)
        #expect(path(env.lastFolder) == path(env.url("trip/day1")))
    }
}
