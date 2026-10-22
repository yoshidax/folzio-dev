import Foundation
import Observation

@MainActor
@Observable
public final class BrowserModel {
    public private(set) var listing: FolderListing
    public private(set) var selection: SelectionState
    public private(set) var preview: PreviewContent
    public private(set) var stopPlaybackSignal = 0
    public private(set) var mediaTypeFilter = MediaTypeFilter()
    public var screenMaxPixel: Int
    public var playbackRequest: PlaybackOptions { settings.playback }
    /// zip の中を表示中か（FR-069）
    public var isBrowsingArchive: Bool { listing.archive != nil }
    /// ⌘↑ で戻る先があるか。zip の中、またはツリーのルート以外の通常のフォルダ（FR-077）。検索結果の表示中はない（FR-087）
    public var hasEnclosingLevel: Bool {
        guard !isShowingSearchResults else { return false }
        return listing.archive != nil || enclosingFolder != nil
    }
    /// 検索結果を表示中か（FR-084〜086）。`listing.folder` は検索前のフォルダのまま
    public var isShowingSearchResults: Bool { listing.search != nil }
    /// 一覧の並び順の選択から `..` の行を除いたもの。ファイル操作・コピー・ドラッグの対象（R30）
    public var operableSelection: [URL] {
        let selected = selection.selected
        guard !selected.isEmpty else { return [] }
        var urls = listing.files.filter { selected.contains($0.url) && $0.kind != .parent }.map(\.url)
        let listed = Set(listing.files.map(\.url))
        for url in selected where !listed.contains(url) && !ParentLink.isParentLink(url) {
            urls.append(url)
        }
        return urls
    }
    /// ファイルリストの中でフォルダを移ったときに、ツリーへ出す選択の同期の依頼（FR-078、R31）。
    /// ツリーからの選択（`selectFolder`）・zip の中の移動・外部の変更による移動では変えない
    public private(set) var treeSyncRequest: TreeSyncRequest?
    /// 「場所」（`.location`）は検索結果の表示中だけ受け付け、保存しない（FR-084）。通常のフォルダでの代入は元の値に戻す
    public var sortOrder: SortOrder {
        didSet {
            guard sortOrder != oldValue, !isRevertingSortOrder else { return }
            if sortOrder.column == .location, !isShowingSearchResults {
                // 戻す代入でも didSet が呼ばれるため、その間は設定の書き込みと並べ直しを行わない
                isRevertingSortOrder = true
                sortOrder = oldValue
                isRevertingSortOrder = false
                return
            }
            if sortOrder.column != .location {
                var settingsValue = settings.viewSettings
                settingsValue.sortOrder = sortOrder
                settings.viewSettings = settingsValue
            }

            if listing.state == .loaded || listing.state == .empty || listing.state == .noMatches {
                allFiles = sorted(allFiles, by: sortOrder)
                rebuildListing()
            }
        }
    }

    private let lister: any DirectoryListing
    private let decoder: any ImageDecoding
    private let cache: DecodedImageCache
    private let settings: SettingsStore
    private let archiveReader: any ArchiveReading
    private let searcher: any FileNameSearching

    /// ツリーのルート（ホーム・ボリューム）。通常のフォルダの `..` と ⌘↑ の戻る先を決める（R30）
    private var navigationRoots: [URL] = []
    private var treeSyncCounter = 0

    /// 表示中の zip の索引。zip の外、または開いている途中・開けなかったときは nil
    private var archiveIndex: ArchiveIndex?
    /// フォルダ・zip の移動のたびに増やし、古い非同期処理の結果を捨てるのに使う
    private var navigationGeneration = 0
    /// 並べ替え済み・種類フィルタ適用前の行。`..` は含めず、`rebuildListing()` で1回だけ加える
    private var allFiles: [MediaFile] = []
    private var listingTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = 0
    private var prefetchTasks: [URL: Task<Void, Never>] = [:]
    private var isRevertingSortOrder = false

    /// 実行中の検索。新しい検索・フォルダの移動（`resetForNavigation`）で取り消す
    private var searchTask: Task<Void, Never>?
    /// 検索結果を、ファイルを含むフォルダ（`standardizedFileURL.path`）ごとに引く。外部の変更で確かめる結果を、
    /// 全件ではなく届いたフォルダ以下だけに絞るのに使う（R38）
    private var searchResultsByFolder: [String: Set<URL>] = [:]

    private enum ArchiveImageResult {
        case image(DecodedImage)
        case animated(Data)
        case failure(String)
    }

    public init(
        lister: any DirectoryListing,
        decoder: any ImageDecoding,
        cache: DecodedImageCache,
        settings: SettingsStore,
        archiveReader: any ArchiveReading = ZipArchiveReader(),
        searcher: any FileNameSearching = FileNameSearcher()
    ) {
        self.lister = lister
        self.decoder = decoder
        self.cache = cache
        self.settings = settings
        self.archiveReader = archiveReader
        self.searcher = searcher
        self.sortOrder = settings.viewSettings.sortOrder
        self.screenMaxPixel = 4096

        let folder = settings.viewSettings.lastFolder
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.listing = FolderListing(folder: folder, files: [], state: .empty)
        self.selection = SelectionState()
        self.preview = .empty
    }

    /// フォルダの一覧を表示する。検索結果の表示中なら、検索を止めて表示を終える（FR-086）
    public func selectFolder(_ url: URL) async {
        resetForNavigation()
        leaveSearchIfNeeded()
        archiveIndex = nil
        listing = FolderListing(folder: url, files: [], state: .loading)

        var viewSettings = settings.viewSettings
        if viewSettings.lastFolder?.standardizedFileURL != url.standardizedFileURL {
            viewSettings.lastFolder = url
            settings.viewSettings = viewSettings
        }

        let generation = navigationGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFolder(url, generation: generation)
        }
        listingTask = task
        await task.value
    }

    /// 検索を始め、結果を見つかった順に現在の並べ替えで一覧へ加える（FR-084・085）。列挙の完了を待たずに戻る。
    /// `listing.folder`・`lastFolder`・`treeSyncRequest` は変えず、zip の中で始めた場合は zip の状態を捨てる
    public func startSearch(_ pattern: SearchPattern, root: URL) {
        resetForNavigation()
        archiveIndex = nil
        listing = FolderListing(
            folder: listing.folder,
            files: [],
            state: .loading,
            search: SearchListing(keyword: pattern.keyword, root: root, phase: .searching, totalCount: 0)
        )

        let generation = navigationGeneration
        let stream = searcher.search(in: root, matching: pattern)
        searchTask = Task { [weak self] in
            for await batch in stream {
                guard let self, generation == self.navigationGeneration else { return }
                self.appendSearchResults(batch)
            }
            guard let self, !Task.isCancelled, generation == self.navigationGeneration else { return }
            self.listing.search?.phase = .finished
            self.rebuildListing()
        }
    }

    /// 検索結果で名前を変更したときに、その行の URL・名前を差し替えて並べ直す。キーワードに一致しなくなっても残し、
    /// 対応メディアの拡張子でなくなったら外す。検索結果の表示中でなければ何もしない（FR-087、R38）
    public func didRenameItem(at oldURL: URL, to newURL: URL) {
        guard isShowingSearchResults,
              let index = allFiles.firstIndex(where: { $0.url == oldURL }) else { return }
        guard let kind = MediaKind(fileExtension: newURL.pathExtension) else {
            removeSearchResults([oldURL])
            return
        }

        let old = allFiles[index]
        var renamed = old
        renamed.url = newURL
        renamed.name = newURL.lastPathComponent
        renamed.kind = .media(kind)
        renamed.typeDescription = (try? newURL.resourceValues(forKeys: [.localizedTypeDescriptionKey]))?
            .localizedTypeDescription ?? old.typeDescription
        allFiles[index] = renamed
        removeFromSearchIndex(oldURL)
        addToSearchIndex(newURL)
        allFiles = sorted(allFiles, by: sortOrder)
        rebuildListing()

        var selected = selection.selected
        if selected.remove(oldURL) != nil {
            selected.insert(newURL)
        }
        if selection.focused == oldURL {
            // プレビューは新しい URL で読み直す
            select(selected, focused: newURL)
        } else {
            selection = SelectionState(selected: selected, focused: selection.focused)
        }
    }

    /// ツリーのルートを受け取る。変わったら、読み込み済みの通常のフォルダの一覧の `..` を作り直す（ディスクは読まない）
    public func setNavigationRoots(_ urls: [URL]) {
        guard urls != navigationRoots else { return }
        navigationRoots = urls
        guard listing.archive == nil else { return }
        switch listing.state {
        case .loaded, .empty, .noMatches:
            rebuildListing()
        case .denied, .failed:
            listing.files = unreadableFolderRows()
        case .loading:
            return
        }

        let restricted = selection.restricted(toVisible: listing.files.map(\.url))
        if restricted.focused == selection.focused {
            selection = restricted
        } else {
            select(restricted.selected, focused: restricted.focused)
        }
    }

    /// 一覧の行を開く。zip ファイル・フォルダ・ディレクトリは中へ、`..` は上へ。メディアと一覧にない URL では何もしない（FR-069・076）
    public func openItem(_ url: URL) async {
        guard let file = listing.files.first(where: { $0.url == url }) else { return }

        switch file.kind {
        case .archive:
            guard listing.archive == nil else { return }
            await openArchive(file.url)
        case .directory:
            guard let location = listing.archive,
                  let index = archiveIndex,
                  let parsed = ArchiveURL.parse(file.url) else { return }
            resetForNavigation()
            showArchiveLevel(ArchiveLocation(archive: location.archive, directory: parsed.path), index: index)
        case .parent:
            await goToEnclosingLevel()
        case .folder:
            await navigateToFolder(file.url, selecting: nil)
        case .media:
            break
        }
    }

    /// 表示中のフォルダ（zip の中なら zip を含むフォルダ）自身か祖先をゴミ箱に入れたときに、親へ移る。
    /// `treeSyncRequest` を出す（FR-079）。移ったら true、該当しなければ何もせず false
    @discardableResult
    public func leaveTrashedFolders(_ trashed: [URL]) async -> Bool {
        guard let parent = FolderNavigation.folderToShow(
            afterTrashing: trashed,
            showing: listing.folder,
            roots: navigationRoots
        ) else { return false }
        await navigateToFolder(parent, selecting: nil)
        return true
    }

    /// 1つ上の階層へ。zip の最上位からはフォルダの一覧へ戻る（FR-070）。zip の外では親フォルダへ戻り、
    /// ツリーのルートでは何もしない（FR-077）
    public func goToEnclosingLevel() async {
        // 検索結果の表示中は戻る先がない（FR-087）
        guard !isShowingSearchResults else { return }
        guard let location = listing.archive else {
            if let parent = enclosingFolder {
                await navigateToFolder(parent, selecting: listing.folder)
            }
            return
        }

        if let parentLocation = location.parent {
            guard let index = archiveIndex else { return }
            let previous = ArchiveURL.entry(archive: location.archive, path: location.directory)
            resetForNavigation()
            showArchiveLevel(parentLocation, index: index)
            if listing.files.contains(where: { $0.url == previous }) {
                select([previous], focused: previous)
            }
        } else {
            await returnToFolder(selecting: location.archive)
        }
    }

    public func select(_ urls: Set<URL>, focused: URL?) {
        let previousFocused = selection.focused
        selection = SelectionState(selected: urls, focused: focused)
        if previousFocused != focused {
            stopPlaybackSignal &+= 1
        }
        loadPreview(for: focused)
        schedulePrefetch(around: focused)
    }

    public func setMediaTypeFilter(_ filter: MediaTypeFilter) {
        guard filter != mediaTypeFilter else { return }
        mediaTypeFilter = filter
        switch listing.state {
        case .loaded, .empty, .noMatches:
            rebuildListing()
        case .loading, .denied, .failed:
            break
        }

        let restricted = selection.restricted(toVisible: listing.files.map(\.url))
        if restricted.focused == selection.focused {
            selection = restricted
            schedulePrefetch(around: restricted.focused)
        } else {
            select(restricted.selected, focused: restricted.focused)
        }
    }

    public func reloadCurrentFolder() async {
        // 検索結果の表示中はディスクを列挙し直さず、存在しなくなった結果を外すだけにする（FR-087、R38）
        if isShowingSearchResults {
            await pruneMissingResults(under: nil)
            return
        }
        // zip の中では、フォルダの一覧で zip の中の一覧を上書きしない
        guard listing.archive == nil else { return }
        let folder = listing.folder
        do {
            let files = try await lister.mediaFiles(in: folder)
            guard listing.folder == folder, listing.archive == nil else { return }

            allFiles = sorted(files, by: sortOrder)
            rebuildListing()

            let available = Set(listing.files.map(\.url))
            let selected = selection.selected.intersection(available)
            let focused = selection.focused.flatMap { available.contains($0) ? $0 : nil }
            selection = SelectionState(selected: selected, focused: focused)
            if focused == nil {
                previewTask?.cancel()
                previewTask = nil
                previewGeneration += 1
                preview = .empty
            }
        } catch {
            guard listing.folder == folder, listing.archive == nil else { return }
            allFiles = []
            listing.files = unreadableFolderRows()
            switch error {
            case .accessDenied:
                listing.state = .denied
            case .notFound:
                listing.state = .failed("フォルダが見つかりません")
            case let .other(message):
                listing.state = .failed(message)
            }
            previewTask?.cancel()
            previewTask = nil
            previewGeneration += 1
            selection = SelectionState()
            preview = .empty
        }
    }

    public func handleFileSystemEvent(_ folders: Set<URL>) async {
        // 検索結果の表示中は、届いたフォルダ以下の結果だけを確かめる。`listing.folder` が消えても親へ移らない（R38）
        if isShowingSearchResults {
            await pruneMissingResults(under: folders)
            return
        }
        let current = listing.folder.standardizedFileURL
        guard folders.contains(where: { $0.standardizedFileURL == current }) else {
            return
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: listing.folder.path,
            isDirectory: &isDirectory
        )
        guard exists, isDirectory.boolValue else {
            await selectFolder(listing.folder.deletingLastPathComponent())
            return
        }

        if let location = listing.archive {
            // 開いている途中は索引がないため、比べずに待つ
            if archiveIndex == nil, listing.state == .loading { return }
            if let identity = archiveReader.identity(of: location.archive),
               identity == archiveIndex?.identity {
                return
            }
            await returnToFolder(selecting: nil)
            return
        }

        await reloadCurrentFolder()
    }

    public func moveFocus(_ direction: FocusDirection) {
        let files = listing.files
        guard !files.isEmpty else { return }

        let currentIndex = selection.focused.flatMap { focused in
            files.firstIndex { $0.url == focused }
        }

        let targetIndex: Int
        switch direction {
        case .previous:
            targetIndex = max(0, (currentIndex ?? 0) - 1)
        case .next:
            targetIndex = min(files.count - 1, (currentIndex ?? -1) + 1)
        }

        let url = files[targetIndex].url
        if currentIndex == targetIndex, selection.selected == [url] {
            return
        }
        select([url], focused: url)
    }

    // MARK: - 一覧

    /// `allFiles`（`..` を含まない）から表示する行と状態を作る。`..` は zip の中では常に、通常のフォルダでは
    /// 戻る先があるときだけ、ここで1回加える（FR-070・077）。検索結果では加えず、検索中で結果がまだなければ `.loading`
    private func rebuildListing() {
        let filtered = mediaTypeFilter.apply(to: allFiles)
        if let location = listing.archive {
            listing.files = [Self.parentRow(for: location)] + filtered
        } else {
            listing.files = folderParentRows() + filtered
        }

        if listing.search?.phase == .searching, allFiles.isEmpty {
            listing.state = .loading
            return
        }

        // zip ファイル・フォルダ・ディレクトリ・`..` は「メディアがない」の判定で数えない（FR-060）
        let hasMedia = allFiles.contains { $0.kind.isMedia }
        let hasOtherRows = allFiles.contains { !$0.kind.isMedia }
        if !hasMedia && !hasOtherRows {
            listing.state = .empty
        } else if hasMedia && !filtered.contains(where: { $0.kind.isMedia }) {
            listing.state = .noMatches
        } else {
            listing.state = .loaded
        }
    }

    private static func parentRow(for location: ArchiveLocation) -> MediaFile {
        parentRow(url: ArchiveURL.parentLink(of: location))
    }

    private static func parentRow(url: URL) -> MediaFile {
        MediaFile(
            url: url,
            name: "..",
            kind: .parent,
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }

    /// 通常のフォルダの1つ上の階層。ツリーのルートとルートの外では nil
    private var enclosingFolder: URL? {
        FolderNavigation.enclosingFolder(of: listing.folder, roots: navigationRoots)
    }

    /// 通常のフォルダの先頭に置く `..` の行。戻る先がないとき・検索結果の表示中は空
    private func folderParentRows() -> [MediaFile] {
        guard !isShowingSearchResults, enclosingFolder != nil else { return [] }
        return [Self.parentRow(url: ParentLink.url(for: listing.folder))]
    }

    /// 読めない通常のフォルダ（`.denied` / `.failed`）の行。ルート以外では `..` だけを残し、行き止まりにしない（FR-077）
    private func unreadableFolderRows() -> [MediaFile] {
        listing.archive == nil ? folderParentRows() : []
    }

    /// ファイルリストの中でフォルダを移る（フォルダの行を開く・`..`・⌘↑）。`selectFolder` と同じく読み込み、
    /// ツリーへ同期の依頼を出す。読み込み後に `target` の行があれば、その行だけを選択する（FR-076〜078）
    private func navigateToFolder(_ url: URL, selecting target: URL?) async {
        treeSyncCounter += 1
        let request = TreeSyncRequest(folder: url, id: treeSyncCounter)
        // 依頼は読み込みの前に出し、ツリーの同期を一覧の完了で待たせない
        treeSyncRequest = request
        await selectFolder(url)

        guard treeSyncRequest == request,
              listing.folder == url,
              listing.archive == nil,
              let target else { return }
        let standardized = target.standardizedFileURL
        if let row = listing.files.first(where: { $0.kind != .parent && $0.url.standardizedFileURL == standardized }) {
            select([row.url], focused: row.url)
        }
    }

    /// 読み込み・プレビュー・先読みの取り消し、動画の停止、選択とプレビューを空にする。
    /// `selectFolder` と zip の中の移動で共有する
    private func resetForNavigation() {
        navigationGeneration += 1
        listingTask?.cancel()
        listingTask = nil
        searchTask?.cancel()
        searchTask = nil
        searchResultsByFolder.removeAll()
        previewGeneration += 1
        previewTask?.cancel()
        previewTask = nil
        for task in prefetchTasks.values {
            task.cancel()
        }
        prefetchTasks.removeAll()

        if case .video = preview {
            stopPlaybackSignal &+= 1
        }

        selection = SelectionState()
        preview = .empty
        allFiles = []
    }

    /// zip を開いて最上位の一覧を作る。開く間は `.loading`
    private func openArchive(_ url: URL) async {
        resetForNavigation()
        leaveSearchIfNeeded()
        archiveIndex = nil
        listing = FolderListing(
            folder: listing.folder,
            files: [],
            state: .loading,
            archive: ArchiveLocation(archive: url, directory: "")
        )

        let generation = navigationGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadArchive(url, generation: generation)
        }
        listingTask = task
        await task.value
    }

    private func loadArchive(_ url: URL, generation: Int) async {
        let result: Result<ArchiveIndex, ArchiveError>
        do throws(ArchiveError) {
            result = .success(try await archiveReader.open(url))
        } catch {
            result = .failure(error)
        }
        guard !Task.isCancelled, generation == navigationGeneration else { return }

        switch result {
        case let .success(index):
            archiveIndex = index
            showArchiveLevel(ArchiveLocation(archive: url, directory: ""), index: index)
        case let .failure(error):
            archiveIndex = nil
            allFiles = []
            if let location = listing.archive {
                listing.files = [Self.parentRow(for: location)]
            }
            listing.state = .failed(error.message)
        }
    }

    /// 開いている索引から、zip の中の1つの階層の一覧を作る（zip は読み直さない）
    private func showArchiveLevel(_ location: ArchiveLocation, index: ArchiveIndex) {
        listing = FolderListing(folder: listing.folder, files: [], state: .loading, archive: location)
        allFiles = sorted(index.items(in: location.directory), by: sortOrder)
        rebuildListing()
    }

    /// zip を閉じ、zip を含むフォルダの一覧をディスクから読み直す。`lastFolder` は書き換えない
    private func returnToFolder(selecting target: URL?) async {
        let folder = listing.folder
        resetForNavigation()
        leaveSearchIfNeeded()
        archiveIndex = nil
        listing = FolderListing(folder: folder, files: [], state: .loading)

        let generation = navigationGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFolder(folder, generation: generation)
        }
        listingTask = task
        await task.value

        guard generation == navigationGeneration, let target else { return }
        let standardized = target.standardizedFileURL
        if let row = listing.files.first(where: { $0.url.standardizedFileURL == standardized }) {
            select([row.url], focused: row.url)
        }
    }

    private func loadFolder(_ url: URL, generation: Int) async {
        do {
            let files = try await lister.mediaFiles(in: url)
            guard !Task.isCancelled, generation == navigationGeneration, listing.folder == url else { return }

            allFiles = sorted(files, by: sortOrder)
            rebuildListing()
        } catch {
            guard !Task.isCancelled, generation == navigationGeneration, listing.folder == url else { return }

            allFiles = []
            listing.files = unreadableFolderRows()
            switch error {
            case .accessDenied:
                listing.state = .denied
            case .notFound:
                listing.state = .failed("フォルダが見つかりません")
            case let .other(message):
                listing.state = .failed(message)
            }
        }
    }

    // MARK: - 検索結果

    /// 検索結果の表示を終える前に、「場所」の並べ替えを保存済みの並べ替えに戻す（FR-084・086）。
    /// `listing` を作り直す前に呼ぶ
    private func leaveSearchIfNeeded() {
        guard isShowingSearchResults else { return }
        if sortOrder.column == .location {
            sortOrder = settings.viewSettings.sortOrder
        }
    }

    /// 届いたバッチを現在の並べ替えで並べてから、並べ替え済みの全件にマージする（R36）
    private func appendSearchResults(_ batch: [MediaFile]) {
        guard isShowingSearchResults, !batch.isEmpty else { return }
        allFiles = sortedMerge(allFiles, sorted(batch, by: sortOrder), by: sortOrder)
        for file in batch {
            addToSearchIndex(file.url)
        }
        listing.search?.totalCount = allFiles.count
        rebuildListing()

        // 行は増えるだけだが、種類フィルタで見えない行を選択に残さないよう整理する。フォーカスが変わらなければプレビューを読み直さない
        guard !selection.selected.isEmpty || selection.focused != nil else { return }
        let restricted = selection.restricted(toVisible: listing.files.map(\.url))
        if restricted.focused == selection.focused {
            selection = restricted
        } else {
            select(restricted.selected, focused: restricted.focused)
        }
    }

    private static func searchFolderKey(_ url: URL) -> String {
        url.deletingLastPathComponent().standardizedFileURL.path
    }

    private func addToSearchIndex(_ url: URL) {
        searchResultsByFolder[Self.searchFolderKey(url), default: []].insert(url)
    }

    private func removeFromSearchIndex(_ url: URL) {
        let key = Self.searchFolderKey(url)
        searchResultsByFolder[key]?.remove(url)
        if searchResultsByFolder[key]?.isEmpty == true {
            searchResultsByFolder[key] = nil
        }
    }

    /// 存在しなくなった検索結果を外す。`folders` が nil なら全件、あればそのフォルダ以下の結果だけを UI スレッドの外で確かめる。
    /// 新しく現れたファイルは加えない（FR-087、R38）
    private func pruneMissingResults(under folders: Set<URL>?) async {
        guard isShowingSearchResults else { return }
        let targets: [URL]
        if let folders {
            let prefixes = folders.map { $0.standardizedFileURL.path }
            if prefixes.contains("/") {
                targets = allFiles.map(\.url)
            } else {
                targets = searchResultsByFolder
                    .filter { key, _ in prefixes.contains { key == $0 || key.hasPrefix($0 + "/") } }
                    .flatMap(\.value)
            }
        } else {
            targets = allFiles.map(\.url)
        }
        guard !targets.isEmpty else { return }

        let generation = navigationGeneration
        let missing = await Task.detached(priority: .userInitiated) {
            Set(targets.filter { !FileManager.default.fileExists(atPath: $0.path) })
        }.value
        guard generation == navigationGeneration, !missing.isEmpty else { return }
        removeSearchResults(missing)
    }

    /// 検索結果から行を外し、選択を整理する。フォーカスが外れたらプレビューを空にし、再生中の動画を止める
    private func removeSearchResults(_ urls: Set<URL>) {
        allFiles.removeAll { urls.contains($0.url) }
        for url in urls {
            removeFromSearchIndex(url)
        }
        listing.search?.totalCount = allFiles.count
        rebuildListing()

        let previousFocused = selection.focused
        let available = Set(listing.files.map(\.url))
        let selected = selection.selected.intersection(available)
        let focused = previousFocused.flatMap { available.contains($0) ? $0 : nil }
        selection = SelectionState(selected: selected, focused: focused)
        if previousFocused != nil, focused == nil {
            if case .video = preview {
                stopPlaybackSignal &+= 1
            }
            previewTask?.cancel()
            previewTask = nil
            previewGeneration += 1
            preview = .empty
        }
    }

    // MARK: - プレビュー

    private func loadPreview(for url: URL?) {
        previewGeneration += 1
        let generation = previewGeneration
        previewTask?.cancel()
        previewTask = nil

        guard let url else {
            preview = .empty
            return
        }

        // 一覧の行の種類を先に見る。メディア以外（zip ファイル・ディレクトリ・`..`）はプレビューしない（FR-075）
        let kind: MediaKind
        if let file = listing.files.first(where: { $0.url == url }) {
            guard case let .media(mediaKind) = file.kind else {
                preview = .empty
                return
            }
            kind = mediaKind
        } else if let mediaKind = MediaKind(fileExtension: url.pathExtension) {
            kind = mediaKind
        } else {
            preview = .unavailable(name: url.lastPathComponent, reason: "対応していない形式です")
            return
        }

        if kind.isVideo {
            preview = .video(url)
            return
        }

        if let parsed = ArchiveURL.parse(url) {
            loadArchivePreview(for: url, path: parsed.path, generation: generation)
            return
        }

        if decoder.isAnimated(url) {
            preview = .animatedImage(url)
            return
        }

        preview = .loading(url)
        previewTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.decodedImage(for: url)
            guard !Task.isCancelled, self.previewGeneration == generation else { return }

            switch result {
            case let .success(image):
                self.preview = .image(image)
            case let .failure(error):
                self.preview = .unavailable(
                    name: url.lastPathComponent,
                    reason: Self.reason(for: error)
                )
            }
        }
    }

    private func loadArchivePreview(for url: URL, path: String, generation: Int) {
        if let entry = archiveIndex?.entry(at: path) {
            switch entry.readability {
            case .readable:
                break
            case .encrypted:
                preview = .unavailable(name: url.lastPathComponent, reason: ArchiveError.entryEncrypted.message)
                return
            case .unsupportedMethod:
                preview = .unavailable(
                    name: url.lastPathComponent,
                    reason: ArchiveError.unsupportedMethod(entry.method).message
                )
                return
            }
        }

        preview = .loading(url)
        let maxPixelSize = max(1, screenMaxPixel)
        previewTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.archiveImage(for: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled, self.previewGeneration == generation else { return }

            switch result {
            case let .image(image):
                self.preview = .image(image)
            case let .animated(data):
                self.preview = .animatedImageData(url, data)
            case let .failure(reason):
                self.preview = .unavailable(name: url.lastPathComponent, reason: reason)
            }
        }
    }

    /// zip の中の画像を、キャッシュ → `Data` の読み込み → デコードの順で得る。アニメーション画像は `Data` のまま返す
    private func archiveImage(for url: URL, maxPixelSize: Int) async -> ArchiveImageResult {
        if let cached = await cache.get(url) {
            return .image(cached)
        }

        let data: Data
        do throws(ArchiveError) {
            data = try await archiveReader.data(for: url, limit: MemoryLimits.archiveImageBytes)
        } catch {
            return .failure(error.message)
        }
        guard !Task.isCancelled else { return .failure("") }

        if decoder.isAnimated(data: data) {
            return .animated(data)
        }

        do {
            let image = try await decoder.decode(data: data, maxPixelSize: maxPixelSize)
            await cache.put(image, for: url)
            return .image(image)
        } catch {
            return .failure(Self.reason(for: error))
        }
    }

    private func decodedImage(for url: URL) async -> Result<DecodedImage, DecodeError> {
        if let cached = await cache.get(url) {
            return .success(cached)
        }

        do {
            let image = try await decoder.decode(url, maxPixelSize: max(1, screenMaxPixel))
            await cache.put(image, for: url)
            return .success(image)
        } catch {
            return .failure(error)
        }
    }

    private func schedulePrefetch(around url: URL?) {
        guard let url, let index = listing.files.firstIndex(where: { $0.url == url }) else {
            return
        }

        for neighborIndex in [index - 1, index + 1] where listing.files.indices.contains(neighborIndex) {
            let file = listing.files[neighborIndex]
            // 動画とメディア以外の行（zip ファイル・ディレクトリ・`..`）は先読みしない
            guard file.kind.isMedia, !file.kind.isVideo else { continue }
            guard prefetchTasks[file.url] == nil else { continue }

            if let parsed = ArchiveURL.parse(file.url) {
                if let entry = archiveIndex?.entry(at: parsed.path), entry.readability != .readable {
                    continue
                }
                let maxPixelSize = max(1, screenMaxPixel)
                let task = Task { [weak self] in
                    guard let self else { return }
                    _ = await self.archiveImage(for: file.url, maxPixelSize: maxPixelSize)
                    self.prefetchTasks[file.url] = nil
                }
                prefetchTasks[file.url] = task
                continue
            }

            guard !decoder.isAnimated(file.url) else { continue }
            let task = Task { [weak self] in
                guard let self else { return }
                _ = await self.decodedImage(for: file.url)
                self.prefetchTasks[file.url] = nil
            }
            prefetchTasks[file.url] = task
        }
    }

    private static func reason(for error: DecodeError) -> String {
        switch error {
        case .unreadable:
            return "ファイルを読み込めません"
        case .unsupported:
            return "対応していない形式です"
        case .corrupted:
            return "ファイルが壊れています"
        }
    }
}
