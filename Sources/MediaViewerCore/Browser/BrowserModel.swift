import Foundation
import Observation

/// `BrowserModel` が場所を変えたときの同期の通知（R70）
public enum LocationEvent: Sendable, Equatable {
    case navigated(leavingFocus: URL?)
    /// 検索結果のフォルダの行を開き、検索結果の表示を終えた（FR-113・140、EC-99・EC-100）。
    /// `HistoryNavigator` は表示の状態を現在の履歴へ反映してから、記録の要否を判定する
    case openedSearchResultFolder(leavingFocus: URL?)
    case relocated(vanished: [URL])
    case notFound(HistoryLocation)
}

/// 表示を変えずに確かめた場所（R73）。索引や開けなかった理由は表示に使う
public struct ResolvedHistoryLocation: Sendable {
    public let location: HistoryLocation
    private let navigationGeneration: Int
    private let archiveIndex: ArchiveIndex?
    private let archiveError: ArchiveError?
    private let usesArchiveIndex: Bool

    init(
        location: HistoryLocation,
        navigationGeneration: Int,
        archiveIndex: ArchiveIndex?,
        archiveError: ArchiveError?
    ) {
        self.location = location
        self.navigationGeneration = navigationGeneration
        self.archiveIndex = archiveIndex
        self.archiveError = archiveError
        self.usesArchiveIndex = location.archive != nil
    }

    func index(for generation: Int) -> ArchiveIndex? {
        guard self.navigationGeneration == generation, usesArchiveIndex else { return nil }
        return archiveIndex
    }

    func error(for generation: Int) -> ArchiveError? {
        guard self.navigationGeneration == generation, usesArchiveIndex else { return nil }
        return archiveError
    }

    func isCurrent(for generation: Int) -> Bool {
        self.navigationGeneration == generation
    }
}

public enum HistoryLocationResolution: Sendable {
    case available(ResolvedHistoryLocation)
    case missing
    case superseded
}

@MainActor
@Observable
public final class BrowserModel {
    public private(set) var listing: FolderListing
    public private(set) var selection: SelectionState
    public private(set) var preview: PreviewContent
    public private(set) var stopPlaybackSignal = 0
    public private(set) var mediaTypeFilter = MediaTypeFilter()
    /// zip ファイルの行を一覧に出すか（FR-095）。保存の正は `SettingsStore` の `view.showsZipFiles`
    public private(set) var showsZipFiles: Bool
    public var screenMaxPixel: Int
    public var playbackRequest: PlaybackOptions { settings.playback }
    /// 場所を変えたときの同期の通知（R70）。`HistoryNavigator` が設定する。Observation の対象外
    @ObservationIgnored public var onLocationEvent: ((LocationEvent) -> Void)?
    /// 閲覧先を置き換える直前に同期で呼ぶ（FR-126）。スライドショーはここで送りを止め、復帰先を確定する。
    /// `listing`・`selection` を変える前に呼ぶ。Observation の対象外
    @ObservationIgnored public var onWillReplaceLocation: (() -> Void)?
    /// zip の中を表示中か（FR-069）
    public var isBrowsingArchive: Bool { listing.archive != nil }
    /// ⌘↑ で戻る先があるか。zip の中、またはツリーのルート以外の通常のフォルダ（FR-077）。検索結果の表示中はない（FR-087）
    public var hasEnclosingLevel: Bool {
        guard !isShowingSearchResults else { return false }
        return listing.archive != nil || enclosingFolder != nil
    }
    /// 検索結果を表示中か（FR-084〜086）。`listing.folder` は検索前のフォルダのまま
    public var isShowingSearchResults: Bool { listing.search != nil }
    /// 今の表示の場所（FR-108）。検索結果の表示中と「見つからない」表示では nil（R70）
    public var historyLocation: HistoryLocation? {
        guard !isShowingSearchResults, !showsNotFound else { return nil }
        return HistoryLocation(folder: listing.folder, archive: listing.archive)
    }
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
    /// 検索結果のフォルダを開いたときのツリー同期の依頼の ID。同期が完了したときに、選択できた場所を
    /// 最後に選択していたフォルダとして保存する（EC-102・R10）。次のナビゲーションで消す
    private var pendingSearchTreeSyncID: Int?

    /// 表示中の zip の索引。zip の外、または開いている途中・開けなかったときは nil
    private var archiveIndex: ArchiveIndex?
    /// フォルダ・zip の移動のたびに増やし、古い非同期処理の結果を捨てるのに使う
    private var navigationGeneration = 0
    /// 並べ替え済み・種類フィルタ適用前の行。`..` は含めず、`rebuildListing()` で1回だけ加える
    private var allFiles: [MediaFile] = [] {
        didSet { kindFilesRevision &+= 1 }
    }
    @ObservationIgnored private var kindFilesRevision = 0
    @ObservationIgnored private var kindUpdateGeneration = 0
    @ObservationIgnored private var kindNames: KindNames
    private var listingTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = 0
    private var prefetchTasks: [URL: Task<Void, Never>] = [:]
    private var isRevertingSortOrder = false

    /// 実行中の検索の列挙（元の列挙と、名前の変更で足した列挙）。新しい検索・フォルダの移動（`resetForNavigation`）で取り消す
    private var searchTasks: [Task<Void, Never>] = []
    /// 今の検索の条件。名前の変更で新しい場所を追加で列挙するのに使う（R63）
    private var searchPattern: SearchPattern?
    /// 今の検索の間に行われたフォルダの名前の変更。後から届いた結果の URL を順に付け替える（R63）
    private var searchLedger = SearchRenameLedger()
    /// 今の検索で終わっていない列挙の数。0 になったら検索を終える（R63）
    private var activeSearchStreams = 0
    /// 開いている zip（開いている途中を含む）を開いた後のフォルダの名前の変更。索引の行は開いたときの zip の場所で
    /// 作られているため、階層を移るたびに付け替える（R62、EC-50）
    private var archiveRenames: [RenamedFolder] = []
    /// 検索結果を、ファイルを含むフォルダ（`standardizedFileURL.path`）ごとに引く。外部の変更で確かめる結果を、
    /// 全件ではなく届いたフォルダ以下だけに絞るのに使う（R38）
    private var searchResultsByFolder: [String: Set<URL>] = [:]
    /// 通常のフォルダの読み込みが「見つからない」で終わった表示か（EC-62・EC-65）。履歴の場所を nil にする
    private var showsNotFound = false

    /// 場所の変更の理由（R70）。通知の `leavingFocus` は呼び出しの直前に読む
    private enum LocationChangeReason {
        case navigated
        case openedSearchResultFolder
        case relocated(vanished: [URL])
    }

    private enum ArchiveImageResult {
        case image(DecodedImage)
        case animated(Data)
        case failure(PreviewFailure)
    }

    public init(
        kindNames: KindNames,
        lister: any DirectoryListing,
        decoder: any ImageDecoding,
        cache: DecodedImageCache,
        settings: SettingsStore,
        archiveReader: (any ArchiveReading)? = nil,
        searcher: (any FileNameSearching)? = nil
    ) {
        self.lister = lister
        self.kindNames = kindNames
        self.decoder = decoder
        self.cache = cache
        self.settings = settings
        self.archiveReader = archiveReader ?? ZipArchiveReader(kindNames: kindNames)
        self.searcher = searcher ?? FileNameSearcher(kindNames: kindNames)
        self.sortOrder = settings.viewSettings.sortOrder
        self.showsZipFiles = settings.viewSettings.showsZipFiles
        self.screenMaxPixel = 4096

        let folder = settings.viewSettings.lastFolder
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.listing = FolderListing(folder: folder, files: [], state: .empty)
        self.selection = SelectionState()
        self.preview = .empty
    }

    /// 言語変更後の種類名と並びを、ディスクを再列挙せず更新する。
    public func setKindNames(_ names: KindNames) {
        guard names != kindNames else { return }
        kindNames = names
        kindUpdateGeneration &+= 1
        let generation = kindUpdateGeneration
        Task { [weak self] in
            guard let self else { return }
            while generation == self.kindUpdateGeneration {
                let files = self.allFiles
                let revision = self.kindFilesRevision
                let order = self.sortOrder
                let updated = await Task.detached(priority: .userInitiated) {
                    sorted(files.map { $0.localizedKindName(using: names) }, by: order)
                }.value
                guard generation == self.kindUpdateGeneration else { return }
                guard revision == self.kindFilesRevision, order == self.sortOrder else { continue }
                self.allFiles = updated
                switch self.listing.state {
                case .loaded, .empty, .noMatches:
                    self.rebuildListing()
                case .loading where self.isShowingSearchResults:
                    self.rebuildListing()
                default:
                    break
                }
                return
            }
        }
    }

    /// フォルダの一覧を表示する。検索結果の表示中なら、検索を止めて表示を終える（FR-086）
    public func selectFolder(_ url: URL) async {
        await selectFolder(url, reason: .navigated)
    }

    private func selectFolder(_ url: URL, reason: LocationChangeReason) async {
        let leavingFocus = selection.focused
        let openedFromSearchResults: Bool
        if case .openedSearchResultFolder = reason {
            openedFromSearchResults = true
        } else {
            openedFromSearchResults = false
        }
        resetForNavigation()
        leaveSearchIfNeeded()
        if openedFromSearchResults {
            // 検索結果から開いた依頼だけ、同期の完了で保存先の更新を受け付ける（EC-102）
            pendingSearchTreeSyncID = treeSyncRequest?.id
        }
        archiveIndex = nil
        showsNotFound = false
        listing = FolderListing(folder: url, files: [], state: .loading)

        var viewSettings = settings.viewSettings
        if viewSettings.lastFolder?.standardizedFileURL != url.standardizedFileURL {
            viewSettings.lastFolder = url
            settings.viewSettings = viewSettings
        }

        notifyLocationChange(reason, leavingFocus: leavingFocus)

        let generation = navigationGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadFolder(url, generation: generation)
        }
        listingTask = task
        await task.value
    }

    private func notifyLocationChange(_ reason: LocationChangeReason, leavingFocus: URL?) {
        switch reason {
        case .navigated:
            onLocationEvent?(.navigated(leavingFocus: leavingFocus))
        case .openedSearchResultFolder:
            onLocationEvent?(.openedSearchResultFolder(leavingFocus: leavingFocus))
        case let .relocated(vanished):
            onLocationEvent?(.relocated(vanished: vanished))
        }
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

        searchPattern = pattern
        startSearchStream(in: root, matching: pattern)
    }

    /// 列挙を1つ始める。すべての列挙が終わったときに検索を終える（R63）。照合の記録は列挙ごとに作って台帳に登録し、
    /// 検索を止めたら台帳ごと捨てる（R2・R3）
    private func startSearchStream(in root: URL, matching pattern: SearchPattern, matchesRoot: Bool = false) {
        let generation = navigationGeneration
        let visits = SearchVisitLog()
        let streamIndex = searchLedger.addStream(visits: visits)
        let stream = searcher.search(
            SearchRequest(root: root, pattern: pattern, matchesRoot: matchesRoot, visits: visits)
        )
        activeSearchStreams += 1
        let task = Task { [weak self] in
            for await batch in stream {
                guard let self, generation == self.navigationGeneration else { return }
                self.appendSearchResults(batch, fromStream: streamIndex)
            }
            guard let self, !Task.isCancelled, generation == self.navigationGeneration else { return }
            self.activeSearchStreams -= 1
            guard self.activeSearchStreams == 0 else { return }
            self.listing.search?.phase = .finished
            self.rebuildListing()
        }
        searchTasks.append(task)
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

    /// フォルダの名前を変えた後に、表示中の一覧・選択・検索結果・zip の中の位置・最後に選択していたフォルダの場所を付け替える。
    /// ディスクは読まず、プレビューと再生中の動画は変えない（`select` を呼ばない）。検索中なら、後から届く結果も付け替え、
    /// 検索起点の配下の名前の変更では新しい場所を追加で列挙する。関係がなければ何もしない（FR-104・105、R62・R63）
    public func didRenameFolder(from oldURL: URL, to newURL: URL) {
        let renamed = RenamedFolder(from: oldURL, to: newURL)
        let oldName = oldURL.standardizedFileURL.path

        var updated = listing
        var changed = false
        if let folder = renamed.rebase(updated.folder) {
            updated.folder = folder
            changed = true
        }
        if let location = updated.archive, let archive = renamed.rebase(location.archive) {
            updated.archive = ArchiveLocation(archive: archive, directory: location.directory)
            changed = true
        }
        let previousRoot = updated.search?.root
        if let root = previousRoot, let rebasedRoot = renamed.rebase(root) {
            updated.search?.root = rebasedRoot
            changed = true
        }

        var filesChanged = false
        var namesChanged = false
        // 検索結果の索引の付け替えで、同じ URL をもう一度付け替えないよう、元の URL と新しい URL を残す（R67）
        let collectsMoves = isShowingSearchResults
        var moves: [(URL, URL)] = []
        let files = allFiles.map { file -> MediaFile in
            guard let url = renamed.rebase(file.url) else { return file }
            filesChanged = true
            if collectsMoves {
                moves.append((file.url, url))
            }
            var moved = file
            moved.url = url
            if file.kind == .folder, file.url.standardizedFileURL.path == oldName {
                moved.name = newURL.lastPathComponent
                namesChanged = true
            }
            return moved
        }

        var selected = selection.selected
        var selectionChanged = false
        for url in selection.selected {
            guard let rebased = renamed.rebase(url) else { continue }
            selected.remove(url)
            selected.insert(rebased)
            selectionChanged = true
        }
        let focused = selection.focused.map { url -> URL in
            guard let rebased = renamed.rebase(url) else { return url }
            selectionChanged = true
            return rebased
        }

        var viewSettings = settings.viewSettings
        if let lastFolder = viewSettings.lastFolder, let rebased = renamed.rebase(lastFolder) {
            viewSettings.lastFolder = rebased
            settings.viewSettings = viewSettings
        }

        // 検索中は、表示中の行に関係がなくても、起点の配下の名前の変更なら後から届く結果に関わる。
        // 照合済みだったかで、新しい場所を起点そのものとして照合するかを決める（EC-94、R2・R3）
        var additionalSearchRoot: URL?
        var additionalMatchesRoot = false
        if listing.search?.phase == .searching, let previousRoot {
            if let rebasedRoot = renamed.rebase(previousRoot) {
                // 起点そのものか祖先の名前を変えた。起点は行にしないため、新しい起点を列挙し直す
                searchLedger.recordRename(renamed, visited: true)
                additionalSearchRoot = rebasedRoot
            } else if RenamedFolder(from: previousRoot, to: previousRoot).rebase(oldURL) != nil {
                // 起点の配下のフォルダ。そのフォルダの新しい場所だけを列挙する
                let visited = searchLedger.hasVisited(oldURL)
                searchLedger.recordRename(renamed, visited: visited)
                additionalSearchRoot = newURL
                additionalMatchesRoot = !visited
            }
        }

        guard changed || filesChanged || selectionChanged || additionalSearchRoot != nil else { return }

        let folderChanged = updated.folder != listing.folder
        // 開いている途中を含め、zip の中を表示中なら索引の行の付け替えに使う
        if listing.archive != nil {
            archiveRenames.append(renamed)
        }
        listing = updated
        if selectionChanged {
            selection = SelectionState(selected: selected, focused: focused)
        }
        if filesChanged {
            // 配下のファイルの名前は変わらないため、並び順が変わるのは行の名前が変わったときと「場所」で並べ替え中だけ
            allFiles = namesChanged || sortOrder.column == .location ? sorted(files, by: sortOrder) : files
        }
        if isShowingSearchResults, filesChanged {
            rebaseSearchIndex(renamed, moved: Dictionary(moves, uniquingKeysWith: { first, _ in first }))
        }

        switch listing.state {
        case .loaded, .empty, .noMatches:
            rebuildListing()
        case .denied, .failed:
            listing.files = unreadableFolderRows()
        case .loading:
            if isShowingSearchResults {
                rebuildListing()
            } else if folderChanged, listing.archive == nil {
                // 読み込み中の一覧は古い場所の結果を捨てるため、新しい場所で読み直す（世代は変えない）
                listingTask?.cancel()
                let generation = navigationGeneration
                let folder = listing.folder
                listingTask = Task { [weak self] in
                    await self?.loadFolder(folder, generation: generation)
                }
            }
        }

        if let additionalSearchRoot, let pattern = searchPattern {
            startSearchStream(in: additionalSearchRoot, matching: pattern, matchesRoot: additionalMatchesRoot)
        }
    }

    /// 検索結果の索引のキー（ファイルを含むフォルダ）を付け替える。10,000 件の URL からキーを作り直さないよう、
    /// キーごとに付け替える（R67）。キーは `searchFolderKey` と同じ標準化した形で比べるため、名前を変えた後の場所
    /// （存在する）を標準化し、元の場所はその親に元の名前を足して作る
    private func rebaseSearchIndex(_ renamed: RenamedFolder, moved: [URL: URL]) {
        let newKeyFolder = renamed.to.standardizedFileURL
        let keyRenamed = RenamedFolder(
            from: newKeyFolder.deletingLastPathComponent().appendingPathComponent(renamed.from.lastPathComponent),
            to: newKeyFolder
        )
        var index: [String: Set<URL>] = [:]
        index.reserveCapacity(searchResultsByFolder.count)
        for (key, urls) in searchResultsByFolder {
            if let newKey = keyRenamed.rebase(URL(fileURLWithPath: key, isDirectory: true))?.path {
                index[newKey, default: []].formUnion(urls.map { moved[$0] ?? renamed.rebaseOrSelf($0) })
            } else {
                // キーが変わらない行でも、名前を変えたフォルダ自身の行は URL が変わる（R4）
                index[key, default: []].formUnion(urls.map { moved[$0] ?? $0 })
            }
        }
        searchResultsByFolder = index
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
            let leavingFocus = selection.focused
            resetForNavigation()
            showArchiveLevel(ArchiveLocation(archive: location.archive, directory: parsed.path), index: index)
            onLocationEvent?(.navigated(leavingFocus: leavingFocus))
        case .parent:
            await goToEnclosingLevel()
        case .folder:
            // 検索結果から開いたときは、履歴の記録の前に表示の状態を現在の履歴へ反映する（FR-113・EC-99）
            await navigateToFolder(
                file.url,
                selecting: nil,
                reason: isShowingSearchResults ? .openedSearchResultFolder : .navigated
            )
        case .media:
            break
        }
    }

    /// 表示中のフォルダ（zip の中なら zip を含むフォルダ）自身か祖先をゴミ箱に入れたときに、親へ移る。
    /// `treeSyncRequest` を出す（FR-079）。移ったら true、該当しなければ何もせず false。
    ///
    /// 検索結果の一覧から（`origin: .fileList`）のゴミ箱では、選択した行が検索前のフォルダの祖先になることがある。
    /// そのときも検索結果の表示を続け、検索前のフォルダが消えたことは表示を終えたときに知らせる（EC-101）。
    /// ツリーから（`origin: .tree`）は従来どおり親へ移る
    @discardableResult
    public func leaveTrashedFolders(_ trashed: [URL], origin: OperationOrigin = .tree) async -> Bool {
        if origin == .fileList, isShowingSearchResults { return false }
        guard let parent = FolderNavigation.folderToShow(
            afterTrashing: trashed,
            showing: listing.folder,
            roots: navigationRoots
        ) else { return false }
        await navigateToFolder(parent, selecting: nil, reason: .relocated(vanished: trashed))
        return true
    }

    /// 検索結果から開いたフォルダのツリー同期の完了を受け取る（FR-140、EC-102、research.md R10）。
    /// 検索結果から開いた依頼のまま、一覧がそのフォルダを表示していて、選択できた場所がそのフォルダ自身か
    /// 祖先（標準化した pathComponents で比較）であるときだけ、最後に選択していたフォルダを選択先にする。
    /// 一覧・履歴・フォーカスは変えず、ディスクも読まない。古い依頼・重複・通常の一覧や履歴からの同期は受け付けない
    public func completeSearchResultTreeSync(_ request: TreeSyncRequest, selectedFolder: URL) {
        guard let pending = pendingSearchTreeSyncID,
              pending == request.id,
              treeSyncRequest == request,
              listing.folder.standardizedFileURL == request.folder.standardizedFileURL,
              !isShowingSearchResults,
              listing.archive == nil,
              !showsNotFound else { return }
        let selectedComponents = selectedFolder.standardizedFileURL.pathComponents
        let targetComponents = request.folder.standardizedFileURL.pathComponents
        guard selectedComponents.count <= targetComponents.count,
              Array(targetComponents.prefix(selectedComponents.count)) == selectedComponents else { return }

        pendingSearchTreeSyncID = nil
        var viewSettings = settings.viewSettings
        if viewSettings.lastFolder?.standardizedFileURL != selectedFolder.standardizedFileURL {
            viewSettings.lastFolder = selectedFolder
            settings.viewSettings = viewSettings
        }
    }

    /// 1つ上の階層へ。zip の最上位からはフォルダの一覧へ戻る（FR-070）。zip の外では親フォルダへ戻り、
    /// ツリーのルートでは何もしない（FR-077）
    public func goToEnclosingLevel() async {
        // 検索結果の表示中は戻る先がない（FR-087）
        guard !isShowingSearchResults else { return }
        guard let location = listing.archive else {
            if let parent = enclosingFolder {
                await navigateToFolder(parent, selecting: listing.folder, reason: .navigated)
            }
            return
        }

        if let parentLocation = location.parent {
            guard let index = archiveIndex else { return }
            let previous = ArchiveURL.entry(archive: location.archive, path: location.directory)
            let leavingFocus = selection.focused
            resetForNavigation()
            showArchiveLevel(parentLocation, index: index)
            onLocationEvent?(.navigated(leavingFocus: leavingFocus))
            if listing.files.contains(where: { $0.url == previous }) {
                select([previous], focused: previous)
            }
        } else {
            await returnToFolder(selecting: location.archive, reason: .navigated)
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

    /// スライドショーの対象を選択に反映する（FR-127）。同じ URL のフォーカスが既に選ばれているなら
    /// プレビューを読み直さず、選択を1件に整理するだけにする。動画の再生位置も保つ。
    /// 実際にフォーカスが変わったときだけ true を返す。
    @discardableResult
    public func synchronizeSlideshowSelection(to url: URL) -> Bool {
        if selection.focused == url {
            if selection.selected != [url] {
                selection = SelectionState(selected: [url], focused: url)
                return true
            }
            return false
        }
        select([url], focused: url)
        return true
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

    /// zip ファイルの表示を切り替えて保存する（FR-095〜098）。同じ値なら何もしない。
    /// zip の中を表示中は設定を保存するだけで、一覧・選択・プレビューを変えない（FR-098）。
    /// それ以外は一覧を作り直し（ディスクは読み直さない）、選択を表示中の行に整理する（FR-097）
    public func setShowsZipFiles(_ shows: Bool) {
        guard shows != showsZipFiles else { return }
        showsZipFiles = shows
        var viewSettings = settings.viewSettings
        viewSettings.showsZipFiles = shows
        settings.viewSettings = viewSettings

        guard listing.archive == nil else { return }
        switch listing.state {
        case .loaded, .empty, .noMatches:
            rebuildListing()
        case .loading, .denied, .failed:
            break
        }

        // 選択がなければ整理するものがない。10,000 件の URL を集合にする費用を省く（SC-017）
        guard !selection.selected.isEmpty || selection.focused != nil else { return }
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
        let generation = navigationGeneration
        do {
            let files = try await lister.mediaFiles(in: folder)
            guard generation == navigationGeneration,
                  listing.folder == folder,
                  listing.archive == nil else { return }

            showsNotFound = false
            allFiles = sorted(files.map { $0.localizedKindName(using: kindNames) }, by: sortOrder)
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
            guard generation == navigationGeneration,
                  listing.folder == folder,
                  listing.archive == nil else { return }
            allFiles = []
            listing.files = unreadableFolderRows()
            switch error {
            case .accessDenied:
                showsNotFound = false
                listing.state = .denied
            case .notFound:
                showsNotFound = true
                listing.state = .failed(.folderNotFound)
                onLocationEvent?(.notFound(HistoryLocation(folder: folder)))
            case let .other(message):
                showsNotFound = false
                listing.state = .failed(.systemFailure(systemReason: message))
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
            let vanished = listing.folder
            await selectFolder(vanished.deletingLastPathComponent(), reason: .relocated(vanished: [vanished]))
            return
        }

        if let location = listing.archive {
            // 開いている途中は索引がないため、比べずに待つ
            if archiveIndex == nil, listing.state == .loading { return }
            if let identity = archiveReader.identity(of: location.archive),
               identity == archiveIndex?.identity {
                return
            }
            let vanished = archiveReader.identity(of: location.archive) == nil ? [location.archive] : []
            await returnToFolder(selecting: nil, reason: .relocated(vanished: vanished))
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
        // 種類フィルタのあとに zip ファイルの表示を1回だけ通す。`allFiles` は変えない（FR-095、R46）
        let filtered = ZipFileVisibility(showsZipFiles: showsZipFiles)
            .apply(to: mediaTypeFilter.apply(to: allFiles))
        if let location = listing.archive {
            listing.files = [Self.parentRow(for: location)] + filtered
        } else {
            listing.files = folderParentRows() + filtered
        }

        if listing.search?.phase == .searching, allFiles.isEmpty {
            listing.state = .loading
            return
        }

        // zip ファイル・フォルダ・ディレクトリ・`..` は「メディアがない」の判定で数えない（FR-060）。
        // メディアは zip の表示設定に影響されないため `allFiles`、それ以外の行は表示する行から求める（FR-097）
        let hasMedia = allFiles.contains { $0.kind.isMedia }
        let hasOtherRows = filtered.contains { !$0.kind.isMedia }
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
    private func navigateToFolder(
        _ url: URL,
        selecting target: URL?,
        reason: LocationChangeReason
    ) async {
        treeSyncCounter += 1
        let request = TreeSyncRequest(folder: url, id: treeSyncCounter)
        // 依頼は読み込みの前に出し、ツリーの同期を一覧の完了で待たせない
        treeSyncRequest = request
        await selectFolder(url, reason: reason)

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
        onWillReplaceLocation?()
        navigationGeneration += 1
        showsNotFound = false
        listingTask?.cancel()
        listingTask = nil
        for task in searchTasks {
            task.cancel()
        }
        searchTasks.removeAll()
        searchPattern = nil
        searchLedger = SearchRenameLedger()
        pendingSearchTreeSyncID = nil
        activeSearchStreams = 0
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
        let leavingFocus = selection.focused
        resetForNavigation()
        leaveSearchIfNeeded()
        archiveIndex = nil
        archiveRenames.removeAll()
        listing = FolderListing(
            folder: listing.folder,
            files: [],
            state: .loading,
            archive: ArchiveLocation(archive: url, directory: "")
        )
        onLocationEvent?(.navigated(leavingFocus: leavingFocus))

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
            // 開いている途中に zip を含むフォルダの名前が変わっていれば、新しい場所で表示する（R62）
            showArchiveLevel(ArchiveLocation(archive: rebasedForArchive(url), directory: ""), index: index)
        case let .failure(error):
            archiveIndex = nil
            allFiles = []
            if let location = listing.archive {
                listing.files = [Self.parentRow(for: location)]
            }
            listing.state = .failed(.archive(error))
        }
    }

    /// 開いている索引から、zip の中の1つの階層の一覧を作る（zip は読み直さない）
    private func showArchiveLevel(_ location: ArchiveLocation, index: ArchiveIndex) {
        listing = FolderListing(folder: listing.folder, files: [], state: .loading, archive: location)
        var items = index.items(in: location.directory)
        if !archiveRenames.isEmpty {
            items = items.map { item in
                var moved = item
                moved.url = rebasedForArchive(item.url)
                return moved
            }
        }
        allFiles = sorted(items.map { $0.localizedKindName(using: kindNames) }, by: sortOrder)
        rebuildListing()
    }

    /// zip を開いた後の名前の変更を順に当てる
    private func rebasedForArchive(_ url: URL) -> URL {
        archiveRenames.reduce(url) { $1.rebaseOrSelf($0) }
    }

    /// zip を閉じ、zip を含むフォルダの一覧をディスクから読み直す。`lastFolder` は書き換えない
    private func returnToFolder(selecting target: URL?, reason: LocationChangeReason) async {
        let folder = listing.folder
        let leavingFocus = selection.focused
        resetForNavigation()
        leaveSearchIfNeeded()
        archiveIndex = nil
        listing = FolderListing(folder: folder, files: [], state: .loading)
        notifyLocationChange(reason, leavingFocus: leavingFocus)

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

    private func loadFolder(_ url: URL, generation: Int, notifyNotFound: Bool = true) async {
        do {
            let files = try await lister.mediaFiles(in: url)
            guard !Task.isCancelled, generation == navigationGeneration, listing.folder == url else { return }

            showsNotFound = false
            allFiles = sorted(files.map { $0.localizedKindName(using: kindNames) }, by: sortOrder)
            rebuildListing()
        } catch {
            guard !Task.isCancelled, generation == navigationGeneration, listing.folder == url else { return }

            allFiles = []
            listing.files = unreadableFolderRows()
            switch error {
            case .accessDenied:
                showsNotFound = false
                listing.state = .denied
            case .notFound:
                showsNotFound = true
                listing.state = .failed(.folderNotFound)
                if notifyNotFound {
                    onLocationEvent?(.notFound(HistoryLocation(folder: url)))
                }
            case let .other(message):
                showsNotFound = false
                listing.state = .failed(.systemFailure(systemReason: message))
            }
        }
    }

    // MARK: - 履歴

    /// 表示を変えずに場所を確かめる。stat と zip の索引の作成は UI スレッドの外（R73）
    public func resolveHistoryLocation(_ location: HistoryLocation) async -> HistoryLocationResolution {
        let generation = navigationGeneration

        guard let archive = location.archive else {
            let path = location.folder.path
            let isDirectory = await Task.detached(priority: .userInitiated) {
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                return exists && isDirectory.boolValue
            }.value
            guard generation == navigationGeneration else { return .superseded }
            guard isDirectory else { return .missing }
            return .available(ResolvedHistoryLocation(
                location: location,
                navigationGeneration: generation,
                archiveIndex: nil,
                archiveError: nil
            ))
        }

        let archivePath = archive.archive.path
        let isRegularFile = await Task.detached(priority: .userInitiated) {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: archivePath, isDirectory: &isDirectory)
            return exists && !isDirectory.boolValue
        }.value
        guard generation == navigationGeneration else { return .superseded }
        guard isRegularFile else { return .missing }

        if let index = archiveIndex, index.archive.path == archive.archive.path {
            guard index.containsDirectory(archive.directory) else { return .missing }
            return .available(ResolvedHistoryLocation(
                location: location,
                navigationGeneration: generation,
                archiveIndex: index,
                archiveError: nil
            ))
        }

        do throws(ArchiveError) {
            let index = try await archiveReader.open(archive.archive)
            guard generation == navigationGeneration else { return .superseded }
            guard index.containsDirectory(archive.directory) else { return .missing }
            return .available(ResolvedHistoryLocation(
                location: location,
                navigationGeneration: generation,
                archiveIndex: index,
                archiveError: nil
            ))
        } catch {
            guard generation == navigationGeneration else { return .superseded }
            return .available(ResolvedHistoryLocation(
                location: location,
                navigationGeneration: generation,
                archiveIndex: nil,
                archiveError: error
            ))
        }
    }

    /// 確かめた場所を表示する。読み込みの完了を待たずに戻り、読み込みの後に `focusing` の行だけを選択する。
    /// `treeSyncRequest` を出し、`lastFolder` を保存する。`onLocationEvent` は呼ばない（R74）
    public func showHistoryLocation(_ resolved: ResolvedHistoryLocation, focusing: URL?) {
        let resolvedGeneration = navigationGeneration
        guard resolved.isCurrent(for: resolvedGeneration) else { return }
        let location = resolved.location
        let resolvedIndex = resolved.index(for: resolvedGeneration)
        let resolvedError = resolved.error(for: resolvedGeneration)

        resetForNavigation()
        leaveSearchIfNeeded()
        archiveIndex = nil
        archiveRenames.removeAll()

        treeSyncCounter += 1
        treeSyncRequest = TreeSyncRequest(folder: location.folder, id: treeSyncCounter)

        var viewSettings = settings.viewSettings
        if viewSettings.lastFolder?.standardizedFileURL != location.folder.standardizedFileURL {
            viewSettings.lastFolder = location.folder
            settings.viewSettings = viewSettings
        }

        if let archive = location.archive {
            if let index = resolvedIndex {
                archiveIndex = index
                listing = FolderListing(folder: location.folder, files: [], state: .loading)
                showArchiveLevel(archive, index: index)
                selectHistoryFocus(focusing)
            } else {
                archiveIndex = nil
                allFiles = []
                listing = FolderListing(
                    folder: location.folder,
                    files: [Self.parentRow(for: archive)],
                    state: .failed(resolvedError.map(ListingFailure.archive) ?? .archive(.notAZip)),
                    archive: archive
                )
            }
            return
        }

        showsNotFound = false
        listing = FolderListing(folder: location.folder, files: [], state: .loading)
        let generation = navigationGeneration
        listingTask = Task { [weak self] in
            guard let self else { return }
            await self.loadFolder(location.folder, generation: generation, notifyNotFound: false)
            guard generation == self.navigationGeneration,
                  self.listing.folder == location.folder,
                  self.listing.archive == nil else { return }
            self.selectHistoryFocus(focusing)
        }
    }

    private func selectHistoryFocus(_ focusing: URL?) {
        guard let focusing else {
            selection = SelectionState()
            previewTask?.cancel()
            previewTask = nil
            previewGeneration += 1
            preview = .empty
            return
        }

        let standardized = focusing.standardizedFileURL
        guard let row = listing.files.first(where: {
            $0.kind != .parent && $0.url.standardizedFileURL == standardized
        }) else {
            selection = SelectionState()
            previewTask?.cancel()
            previewTask = nil
            previewGeneration += 1
            preview = .empty
            return
        }
        select([row.url], focused: row.url)
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

    /// 届いたバッチを現在の並べ替えで並べてから、並べ替え済みの全件にマージする（R36）。
    /// 名前の変更の後は、その列挙を始めた後の変更を順に当てて新しい場所にし、追加の列挙と重なる結果を捨てる（R63）
    private func appendSearchResults(_ incoming: [MediaFile], fromStream index: Int) {
        guard isShowingSearchResults, !incoming.isEmpty else { return }
        var batch = incoming
        if !searchLedger.isEmpty {
            var seen = Set<String>()
            batch = incoming.compactMap { file in
                guard let moved = searchLedger.place(file, fromStream: index) else { return nil }
                let path = moved.url.standardizedFileURL.path
                let listed = searchResultsByFolder[Self.searchFolderKey(moved.url)]?
                    .contains { $0.standardizedFileURL.path == path } == true
                guard !listed, seen.insert(path).inserted else { return nil }
                return moved
            }
            guard !batch.isEmpty else { return }
        }
        batch = batch.map { $0.localizedKindName(using: kindNames) }
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
            preview = .unavailable(name: url.lastPathComponent, reason: .unsupportedFormat)
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
                preview = .unavailable(name: url.lastPathComponent, reason: .archive(.entryEncrypted))
                return
            case .unsupportedMethod:
                preview = .unavailable(
                    name: url.lastPathComponent,
                    reason: .archive(.unsupportedMethod(entry.method))
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
            return .failure(.archive(error))
        }
        guard !Task.isCancelled else { return .failure(.unreadable) }

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

    private static func reason(for error: DecodeError) -> PreviewFailure {
        switch error {
        case .unreadable:
            return .unreadable
        case .unsupported:
            return .unsupportedFormat
        case .corrupted:
            return .corrupted
        }
    }
}
