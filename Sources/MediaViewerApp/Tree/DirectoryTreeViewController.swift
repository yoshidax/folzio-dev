import AppKit
import MediaViewerCore

@MainActor
final class DirectoryTreeViewController: NSViewController {
    final class Node {
        var folder: FolderNode
        var children: [Node]?
        var isLoading = false

        init(folder: FolderNode) {
            self.folder = folder
        }

        var url: URL { folder.url }
    }

    /// ツリー最上部の「お気に入り」の見出し。ファイルシステム上にない仮想の行（FR-061）
    final class FavoritesHeader {}

    /// 見出しの下の各項目。開閉の三角を持たない（FR-063）
    final class FavoriteEntry {
        let url: URL
        var name: String
        var kind: FolderNode.Kind
        var availability: FavoriteAvailability = .unknown

        init(url: URL, name: String, kind: FolderNode.Kind) {
            self.url = url
            self.name = name
            self.kind = kind
        }
    }

    private let model: BrowserModel
    private let lister: any DirectoryListing
    private let volumes: any VolumeProviding
    private let coordinator: FileOperationCoordinator
    private let watcher: any FileSystemWatching
    private let settings: SettingsStore
    private let confirmation: ConfirmationPresenter
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()

    private var roots: [Node] = []
    private let favoritesHeader = FavoritesHeader()
    private var favorites = FavoriteFolders()
    private var favoriteEntries: [FavoriteEntry] = []
    private var volumeTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var favoriteProbeTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?
    private var didReveal = false
    private var isRestoringSelection = false

    private enum ProbeKey: Hashable {
        case roots
        case children(ObjectIdentifier)
        case recheck(ObjectIdentifier)
    }

    private struct ProbeEntry {
        let id: Int
        let task: Task<Void, Never>
    }

    private var probeTasks: [ProbeKey: ProbeEntry] = [:]
    private var nextProbeID = 0

    init(
        model: BrowserModel,
        lister: any DirectoryListing,
        volumes: any VolumeProviding,
        coordinator: FileOperationCoordinator,
        watcher: any FileSystemWatching,
        settings: SettingsStore,
        confirmation: ConfirmationPresenter
    ) {
        self.model = model
        self.lister = lister
        self.volumes = volumes
        self.coordinator = coordinator
        self.watcher = watcher
        self.settings = settings
        self.confirmation = confirmation
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var primaryFocusView: NSView { outlineView }

    private var selectedNode: Node? {
        let row = outlineView.selectedRow
        guard row >= 0 else { return nil }
        return outlineView.item(atRow: row) as? Node
    }

    private func role(for item: Any?) -> TreeItemRole? {
        switch item {
        case is FavoritesHeader:
            return .favoritesHeader
        case let entry as FavoriteEntry:
            return .favorite(entry.url)
        case let node as Node:
            return .folder(node.url)
        default:
            return nil
        }
    }

    /// 登録順に項目を並べ直す。同じ場所の既存の項目は使い回し、確認済みの availability と選択を保つ
    private func rebuildFavoriteEntries() {
        let existing = Dictionary(
            favoriteEntries.map { ($0.url.standardizedFileURL.path, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        favoriteEntries = favorites.urls.map { url in
            let key = url.standardizedFileURL.path
            let root = roots.first { $0.url.standardizedFileURL.path == key }
            let name = root?.folder.name ?? url.lastPathComponent
            let kind = root?.folder.kind ?? .folder
            if let entry = existing[key] {
                entry.name = name
                entry.kind = kind
                return entry
            }
            return FavoriteEntry(url: url, name: name, kind: kind)
        }
    }

    private var selectedItem: Any? {
        let row = outlineView.selectedRow
        guard row >= 0 else { return nil }
        return outlineView.item(atRow: row)
    }

    /// ⌘⌫ の対象。お気に入りの項目を選択中のときだけ返す（FR-064）
    private var selectedFavoriteEntry: FavoriteEntry? {
        let item = selectedItem
        guard FavoriteCommands.removalTarget(role(for: item)) != nil else { return nil }
        return item as? FavoriteEntry
    }

    /// 右クリックメニューの項目なら右クリックした行を、キー操作なら選択中の行を対象にする
    private func targetItem(for sender: Any?) -> Any? {
        if let menuItem = sender as? NSMenuItem, let represented = menuItem.representedObject {
            return represented
        }
        return selectedItem
    }

    /// ペースト・Finder に表示の対象。見出し・お気に入りの項目では nil
    private func fileTargetNode(for sender: Any?) -> Node? {
        let item = targetItem(for: sender)
        guard let role = role(for: item), FavoriteCommands.acceptsFiles(role) else { return nil }
        return item as? Node
    }

    /// 項目は menuNeedsUpdate で、対象の行の役割に合わせて作り直す
    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        menu.delegate = self
        return menu
    }

    private func makeContextMenuItem(
        _ kind: TreeContextMenuItem,
        representing item: Any
    ) -> NSMenuItem {
        let menuItem: NSMenuItem
        switch kind {
        case .pasteHere:
            menuItem = NSMenuItem(title: "ここにペースト", action: #selector(paste(_:)), keyEquivalent: "")
        case .movePasteHere:
            menuItem = NSMenuItem(title: "ここに移動ペースト", action: #selector(movePaste(_:)), keyEquivalent: "")
        case .addToFavorites:
            menuItem = NSMenuItem(
                title: "お気に入りに追加",
                action: #selector(addToFavorites(_:)),
                keyEquivalent: "t"
            )
            menuItem.keyEquivalentModifierMask = [.command, .control]
        case .revealInFinder:
            menuItem = NSMenuItem(title: "Finder に表示", action: #selector(revealInFinder(_:)), keyEquivalent: "")
        case .removeFromFavorites:
            menuItem = NSMenuItem(
                title: "お気に入りから削除",
                action: #selector(removeFavoriteFromMenu(_:)),
                keyEquivalent: String(UnicodeScalar(NSBackspaceCharacter)!)
            )
            menuItem.keyEquivalentModifierMask = [.command]
        case .separator:
            return .separator()
        }
        menuItem.target = self
        menuItem.representedObject = item
        return menuItem
    }

    @objc func paste(_ sender: Any?) {
        guard let node = fileTargetNode(for: sender) else { return }
        let destination = node.url
        Task { @MainActor in
            await coordinator.paste(into: destination, move: false)
        }
    }

    @objc func movePaste(_ sender: Any?) {
        guard let node = fileTargetNode(for: sender) else { return }
        let destination = node.url
        Task { @MainActor in
            await coordinator.paste(into: destination, move: true)
        }
    }

    /// ⌘⌫。お気に入りの項目を選択中のときだけ、確認のうえお気に入りから削除する（FR-064）
    @objc func moveToTrash(_ sender: Any?) {
        guard let entry = selectedFavoriteEntry else { return }
        Task { [weak self] in
            await self?.removeFavorite(entry)
        }
    }

    @objc private func addToFavorites(_ sender: Any?) {
        addFavorite(for: targetItem(for: sender))
    }

    @objc private func removeFavoriteFromMenu(_ sender: Any?) {
        guard let item = (sender as? NSMenuItem)?.representedObject,
              FavoriteCommands.removalTarget(role(for: item)) != nil,
              let entry = item as? FavoriteEntry else {
            return
        }
        Task { [weak self] in
            await self?.removeFavorite(entry)
        }
    }

    /// ⌃⌘T。どのペインにフォーカスがあっても MainSplitViewController から呼ばれる（FR-062）
    func addSelectedFolderToFavorites() {
        addFavorite(for: selectedItem)
    }

    var canAddSelectedFolderToFavorites: Bool {
        FavoriteCommands.canAdd(role(for: selectedItem), favorites: favorites)
    }

    /// ⇧⌘F。見出しを選択するだけで、ファイルリスト・プレビューは変えない（FR-065）
    func focusFavoritesHeader() {
        let row = outlineView.row(forItem: favoritesHeader)
        guard row >= 0 else { return }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
        if !outlineView.isItemExpanded(favoritesHeader) {
            outlineView.expandItem(favoritesHeader)
        }
        view.window?.makeFirstResponder(outlineView)
    }

    private func addFavorite(for item: Any?) {
        let role = role(for: item)
        guard FavoriteCommands.canAdd(role, favorites: favorites),
              case .folder(let url) = role else {
            return
        }
        // 見出しの開閉状態は変えない
        favorites.add(url)
        settings.favorites = favorites
        rebuildFavoriteEntries()
        reloadFavorites()
        updateWatchSet()
        refreshFavoriteAvailability()
    }

    /// 登録だけを取り除き、実際のフォルダには触れない（FR-064）
    private func removeFavorite(_ entry: FavoriteEntry) async {
        guard await confirmation.confirmRemovingFavorite(named: entry.name) else { return }
        guard favorites.contains(entry.url) else { return }

        // 消えた行の位置で別の項目が選ばれて一覧が切り替わらないよう、先に見出しを選ぶ
        if selectedItem as? FavoriteEntry === entry {
            let headerRow = outlineView.row(forItem: favoritesHeader)
            if headerRow >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: headerRow), byExtendingSelection: false)
            }
        }

        favorites.remove(entry.url)
        settings.favorites = favorites
        rebuildFavoriteEntries()
        reloadFavorites()
        updateWatchSet()
    }

    /// 見出しの子を読み直し、行の増減でずれた選択を同じ item に戻す
    private func reloadFavorites() {
        let previous = selectedItem
        isRestoringSelection = true
        defer { isRestoringSelection = false }

        outlineView.reloadItem(favoritesHeader, reloadChildren: true)
        if let previous {
            let row = outlineView.row(forItem: previous)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
    }

    @objc private func toggleClickedFolder(_ sender: Any?) {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }
        let item = outlineView.item(atRow: row)

        // 選択は1回目のクリックで outlineViewSelectionDidChange が行う。お気に入りの項目は開閉しない
        let isExpandable: Bool
        switch item {
        case is FavoritesHeader:
            isExpandable = true
        case let node as Node:
            isExpandable = node.folder.isExpandable
        default:
            return
        }

        switch FolderDisclosure.doubleClickToggle(
            isExpandable: isExpandable,
            isExpanded: outlineView.isItemExpanded(item)
        ) {
        case .expand:
            outlineView.expandItem(item)
        case .collapse:
            outlineView.collapseItem(item)
        case .none:
            break
        }
    }

    @objc private func revealInFinder(_ sender: Any?) {
        guard let node = fileTargetNode(for: sender) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    override func loadView() {
        let container = NSView()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.menu = makeContextMenu()
        outlineView.target = self
        outlineView.doubleAction = #selector(toggleClickedFolder(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        column.title = "フォルダ"
        column.width = 200
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        roots = volumes.rootNodes().map { Node(folder: $0) }
        favorites = settings.favorites
        rebuildFavoriteEntries()
        outlineView.reloadData()
        startProbes(for: roots, key: .roots)
        refreshFavoriteAvailability()

        volumeTask = Task { [weak self] in
            guard let self else { return }
            for await newRoots in self.volumes.changes {
                self.applyRoots(newRoots)
            }
        }

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await changed in self.watcher.events {
                await self.model.handleFileSystemEvent(changed)
                await self.reloadExpandedNodes(in: changed)
                self.recheckCollapsedNodes(in: changed)
                self.updateWatchSet()
                self.refreshFavoriteAvailabilityIfNeeded(in: changed)
            }
        }

        // ツリーはアプリの終了まで生きるため、volumeTask・eventTask と同じく解除しない
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshFavoriteAvailability()
            }
        }

        observeDisplayedFolder()
        updateWatchSet()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didReveal else { return }
        didReveal = true

        let target = model.listing.folder
        revealTask = Task { [weak self] in
            await self?.reveal(target)
        }
    }

    private func applyRoots(_ newRoots: [FolderNode]) {
        let existing = Dictionary(
            roots.map { ($0.url.standardizedFileURL, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        roots = newRoots.map { folder in
            let node = Node(folder: folder)
            if let previous = existing[folder.url.standardizedFileURL] {
                node.children = previous.children
                node.folder.subfolderState = previous.folder.subfolderState
                node.folder.accessState = previous.folder.accessState
            }
            return node
        }
        rebuildFavoriteEntries()

        // ボリュームの増減でも見出しの展開状態と、お気に入りの行の選択を保つ（FR-061）
        let headerWasExpanded = outlineView.isItemExpanded(favoritesHeader)
        let selected = selectedItem
        let keepsFavoriteSelection = selected is FavoritesHeader || selected is FavoriteEntry
        isRestoringSelection = keepsFavoriteSelection
        outlineView.reloadData()
        if headerWasExpanded {
            outlineView.expandItem(favoritesHeader)
        }
        if keepsFavoriteSelection, let selected {
            let row = outlineView.row(forItem: selected)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
        isRestoringSelection = false

        startProbes(for: roots, key: .roots)
        updateWatchSet()
        refreshFavoriteAvailability()
    }

    /// 登録した場所にフォルダがあるかを確かめ、変わった行だけ描き直す（FR-067）。stat は FavoriteProbe のタスク内で行う
    private func refreshFavoriteAvailability() {
        favoriteProbeTask?.cancel()
        favoriteProbeTask = nil
        let urls = favoriteEntries.map(\.url)
        guard !urls.isEmpty else { return }

        favoriteProbeTask = Task { [weak self] in
            for await result in FavoriteProbe.results(for: urls) {
                guard let self, !Task.isCancelled else { return }
                self.applyFavoriteProbe(result)
            }
        }
    }

    private func applyFavoriteProbe(_ result: FavoriteProbeResult) {
        let key = result.url.standardizedFileURL.path
        let availability: FavoriteAvailability = result.exists ? .available : .missing
        for entry in favoriteEntries
        where entry.url.standardizedFileURL.path == key && entry.availability != availability {
            entry.availability = availability
            if outlineView.row(forItem: entry) >= 0 {
                outlineView.reloadItem(entry)
            }
        }
    }

    /// 変更のあったフォルダに、登録したフォルダの親が含まれるときだけ確かめ直す
    private func refreshFavoriteAvailabilityIfNeeded(in changed: Set<URL>) {
        let changedPaths = Set(changed.map(\.standardizedFileURL.path))
        let affected = favoriteParentFolders().contains { changedPaths.contains($0.path) }
        if affected {
            refreshFavoriteAvailability()
        }
    }

    /// 登録した各フォルダの親。`/` の登録は親がないため除く
    private func favoriteParentFolders() -> [URL] {
        favorites.urls.compactMap { url in
            let standardized = url.standardizedFileURL
            guard standardized.path != "/" else { return nil }
            return standardized.deletingLastPathComponent().standardizedFileURL
        }
    }

    private func reveal(_ target: URL) async {
        let targetURL = target.standardizedFileURL
        let targetComponents = targetURL.pathComponents

        var root = roots.first { node in
            targetComponents.starts(with: node.url.standardizedFileURL.pathComponents)
        }
        if root == nil {
            root = roots.first { $0.folder.kind == .home }
        }
        guard var current = root else { return }

        await loadAndExpand(current)

        let rootComponents = current.url.standardizedFileURL.pathComponents
        if targetComponents.count > rootComponents.count {
            for component in targetComponents[rootComponents.count...] {
                guard let next = current.children?.first(where: {
                    $0.url.lastPathComponent == component
                }) else {
                    break
                }
                await loadAndExpand(next)
                current = next
            }
        }

        let row = outlineView.row(forItem: current)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
        }
    }

    /// 確認前のノードへの expandItem は isItemExpandable が false のため無視されるので、先に子を読み込む
    private func loadAndExpand(_ node: Node) async {
        await loadChildrenIfNeeded(node)
        if node.folder.isExpandable, !outlineView.isItemExpanded(node) {
            outlineView.expandItem(node)
        }
    }

    private func loadChildrenIfNeeded(_ node: Node) async {
        guard node.children == nil, !node.isLoading else { return }
        node.isLoading = true
        defer { node.isLoading = false }

        do {
            let urls = try await lister.subfolders(of: node.url)
            applyListing(.success(urls), to: node)
        } catch {
            applyListing(.failure(error), to: node)
        }
        updateWatchSet()
    }

    private func applyListing(_ result: Result<[URL], ListingError>, to node: Node) {
        switch result {
        case .success(let urls):
            let previous = Dictionary(
                (node.children ?? []).map { ($0.url.standardizedFileURL, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let children = urls.map { url in
                let child = Node(folder: FolderNode(
                    url: url,
                    name: url.lastPathComponent,
                    kind: .folder,
                    accessState: .accessible
                ))
                if let old = previous[url.standardizedFileURL] {
                    child.folder.subfolderState = old.folder.subfolderState
                    child.folder.accessState = old.folder.accessState
                }
                return child
            }
            node.children = children
            node.folder.children = children.map(\.folder)
            node.folder.applySubfolderListing(.success(children.count))
            outlineView.reloadItem(node, reloadChildren: true)
            if node.folder.isExpandable {
                outlineView.expandItem(node)
            } else {
                outlineView.collapseItem(node)
            }
            startProbes(for: children, key: .children(ObjectIdentifier(node)))
        case .failure(let error):
            node.folder.applySubfolderListing(.failure(error))
            // 権限なしは空のまま確定し、それ以外は次の展開で読み直す
            node.children = node.folder.accessState == .denied ? [] : nil
            outlineView.reloadItem(node, reloadChildren: true)
            outlineView.collapseItem(node)
        }
    }

    private func startProbes(for nodes: [Node], key: ProbeKey, force: Bool = false) {
        let targets = force ? nodes : nodes.filter {
            $0.folder.subfolderState == .unknown && $0.folder.accessState != .denied
        }
        probeTasks[key]?.task.cancel()
        probeTasks[key] = nil
        guard !targets.isEmpty else { return }

        let lookup = Dictionary(
            targets.map { ($0.url.standardizedFileURL, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let urls = targets.map(\.url)
        let lister = self.lister
        nextProbeID += 1
        let id = nextProbeID

        let task = Task { [weak self] in
            for await result in SubfolderProbe.results(for: urls, lister: lister) {
                guard let self, !Task.isCancelled else { return }
                guard let node = lookup[result.url.standardizedFileURL] else { continue }
                node.folder.applySubfolderProbe(result.result)
                if self.outlineView.row(forItem: node) >= 0 {
                    self.outlineView.reloadItem(node, reloadChildren: false)
                }
            }
            if let self, self.probeTasks[key]?.id == id {
                self.probeTasks[key] = nil
            }
        }
        probeTasks[key] = ProbeEntry(id: id, task: task)
    }

    private func observeDisplayedFolder() {
        withObservationTracking {
            _ = model.listing.folder
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateWatchSet()
                self?.observeDisplayedFolder()
            }
        }
    }

    private func updateWatchSet() {
        var folders: Set<URL> = [model.listing.folder.standardizedFileURL]
        for node in flattenedNodes(from: roots) where outlineView.isItemExpanded(node) {
            folders.insert(node.url.standardizedFileURL)
        }
        // 折りたたまれた表示中のフォルダも監視し、サブフォルダの増減で三角の有無を更新する
        for node in displayedNodes() {
            folders.insert(node.url.standardizedFileURL)
        }
        // お気に入りのフォルダの移動・削除を親フォルダの変更として受け取る（FR-067）
        folders.formUnion(favoriteParentFolders())
        watcher.watch(folders)
    }

    private func displayedNodes() -> [Node] {
        var result: [Node] = []
        func visit(_ nodes: [Node]) {
            for node in nodes {
                result.append(node)
                if outlineView.isItemExpanded(node), let children = node.children {
                    visit(children)
                }
            }
        }
        visit(roots)
        return result
    }

    private func recheckCollapsedNodes(in changed: Set<URL>) {
        let changedURLs = Set(changed.map(\.standardizedFileURL))
        let targets = displayedNodes().filter { node in
            !outlineView.isItemExpanded(node) && changedURLs.contains(node.url.standardizedFileURL)
        }
        for node in targets {
            if node.children != nil {
                // 折りたたみ中の変更を次の展開で反映するため、読み込み済みの子を捨てる
                node.children = nil
                node.folder.children = nil
                outlineView.reloadItem(node, reloadChildren: true)
            }
            startProbes(for: [node], key: .recheck(ObjectIdentifier(node)), force: true)
        }
    }

    private func reloadExpandedNodes(in changed: Set<URL>) async {
        let changedURLs = Set(changed.map(\.standardizedFileURL))
        let targets = flattenedNodes(from: roots).filter { node in
            node.children != nil
                && outlineView.isItemExpanded(node)
                && changedURLs.contains(node.url.standardizedFileURL)
        }
        for node in targets {
            await reloadChildren(of: node)
        }
    }

    private func reloadChildren(of node: Node) async {
        let selectedURL = selectedNode?.url

        do {
            let urls = try await lister.subfolders(of: node.url)
            applyListing(.success(urls), to: node)
        } catch {
            applyListing(.failure(error), to: node)
        }

        if let selectedURL, let row = rowForURL(selectedURL) {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    private func flattenedNodes(from nodes: [Node]) -> [Node] {
        var result: [Node] = []
        for node in nodes {
            result.append(node)
            if let children = node.children {
                result.append(contentsOf: flattenedNodes(from: children))
            }
        }
        return result
    }

    private func rowForURL(_ url: URL) -> Int? {
        let target = url.standardizedFileURL
        guard let node = flattenedNodes(from: roots).first(where: {
            $0.url.standardizedFileURL == target
        }) else {
            return nil
        }
        let row = outlineView.row(forItem: node)
        return row >= 0 ? row : nil
    }
}

extension DirectoryTreeViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        switch item {
        case let node as Node:
            return node.children?.count ?? 0
        case is FavoritesHeader:
            return favoriteEntries.count
        case nil:
            // トップレベルは [見出し] + roots
            return roots.count + 1
        default:
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? Node {
            return node.children![index]
        }
        if item is FavoritesHeader {
            return favoriteEntries[index]
        }
        return index == 0 ? favoritesHeader : roots[index - 1]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // 見出しは登録が0件でも開閉できる。お気に入りの項目は三角を持たない
        if item is FavoritesHeader { return true }
        guard let node = item as? Node else { return false }
        return node.folder.isExpandable
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        validateDrop info: any NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        // 見出し・お気に入りの項目はドロップ先にならない
        guard let role = role(for: item), FavoriteCommands.acceptsFiles(role) else { return [] }
        guard let node = item as? Node,
              node.folder.accessState != .denied,
              fileURLs(from: info.draggingPasteboard) != nil else {
            return []
        }

        outlineView.setDropItem(node, dropChildIndex: NSOutlineViewDropOnItemIndex)

        let mask = info.draggingSourceOperationMask
        let preferred: NSDragOperation = NSEvent.modifierFlags.contains(.option)
            ? .copy
            : .move
        if mask.contains(preferred) {
            return preferred
        }
        return mask.contains(.copy) ? .copy : []
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        acceptDrop info: any NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        guard let role = role(for: item), FavoriteCommands.acceptsFiles(role) else { return false }
        guard let node = item as? Node,
              node.folder.accessState != .denied,
              let urls = fileURLs(from: info.draggingPasteboard),
              !urls.isEmpty else {
            return false
        }

        let destination = node.url
        let shouldCopy = NSEvent.modifierFlags.contains(.option)
        Task { @MainActor in
            if shouldCopy {
                await coordinator.copy(urls, to: destination)
            } else {
                await coordinator.move(urls, to: destination)
            }
        }
        return true
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        guard pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: options
        ) else {
            return nil
        }
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [NSURL]
        return objects?.map { $0 as URL }
    }
}

extension DirectoryTreeViewController: NSOutlineViewDelegate {
    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        switch item {
        case let node as Node:
            let cell = makeFolderCell(in: outlineView)
            cell.imageView?.image = IconCatalog.treeIcon(for: node.folder.kind)
            cell.textField?.stringValue = node.folder.name
            if node.folder.accessState == .denied || node.folder.accessState == .unavailable {
                cell.textField?.textColor = .disabledControlTextColor
                cell.toolTip = "アクセスできません"
            } else {
                cell.textField?.textColor = .labelColor
                cell.toolTip = nil
            }
            return cell
        case is FavoritesHeader:
            let cell = makeFolderCell(in: outlineView)
            cell.imageView?.image = IconCatalog.favoritesIcon()
            cell.textField?.stringValue = "お気に入り"
            cell.textField?.textColor = .labelColor
            cell.toolTip = nil
            return cell
        case let entry as FavoriteEntry:
            let cell = makeFolderCell(in: outlineView)
            cell.imageView?.image = IconCatalog.treeIcon(for: entry.kind)
            cell.textField?.stringValue = entry.name
            if entry.availability == .missing {
                cell.textField?.textColor = .disabledControlTextColor
                cell.toolTip = "見つかりません"
            } else {
                cell.textField?.textColor = .labelColor
                cell.toolTip = nil
            }
            return cell
        default:
            return nil
        }
    }

    private func makeFolderCell(in outlineView: NSOutlineView) -> NSTableCellView {
        let identifier = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.imageScaling = .scaleProportionallyDown
            icon.setAccessibilityElement(false)
            cell.addSubview(icon)
            cell.imageView = icon

            let text = NSTextField(labelWithString: "")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(text)
            cell.textField = text

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                icon.widthAnchor.constraint(equalToConstant: 16),
                icon.heightAnchor.constraint(equalToConstant: 16),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

                text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        return cell
    }

    func outlineViewItemWillExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? Node else { return }
        Task { [weak self] in
            await self?.loadChildrenIfNeeded(node)
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isRestoringSelection else { return }
        updateWatchSet()
        let row = outlineView.selectedRow
        guard row >= 0, let role = role(for: outlineView.item(atRow: row)) else { return }
        if case .favorite = role {
            refreshFavoriteAvailability()
        }
        // 見出しでは一覧を切り替えない（FR-065）。お気に入りの項目でも実際の階層は動かさない（FR-063）
        guard let url = FavoriteCommands.folderToShow(for: role) else { return }
        Task { [weak self] in
            await self?.model.selectFolder(url)
        }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        updateWatchSet()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        updateWatchSet()
    }
}

extension DirectoryTreeViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(paste(_:)), #selector(movePaste(_:)):
            return fileTargetNode(for: menuItem) != nil
                && FileContextMenu.pasteboardHasFileURLs()
        case #selector(revealInFinder(_:)):
            return fileTargetNode(for: menuItem) != nil
        case #selector(moveToTrash(_:)):
            // ⌘⌫ はお気に入りの項目でだけ有効。ほかの行では何もしない（FR-064）
            if selectedFavoriteEntry != nil {
                menuItem.title = "お気に入りから削除"
                return true
            }
            menuItem.title = "ゴミ箱に入れる"
            return false
        case #selector(addToFavorites(_:)):
            return FavoriteCommands.canAdd(role(for: targetItem(for: menuItem)), favorites: favorites)
        case #selector(removeFavoriteFromMenu(_:)):
            return FavoriteCommands.removalTarget(role(for: menuItem.representedObject)) != nil
        default:
            return true
        }
    }
}

extension DirectoryTreeViewController: NSMenuDelegate {
    /// 右クリックした行の役割で項目を作り直す。キーボードで開いたときなどは選択中の行を使う
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0,
              let item = outlineView.item(atRow: row),
              let role = role(for: item) else {
            return
        }
        // 見出しは項目なし（メニューを出さない）
        for kind in FavoriteCommands.contextMenu(for: role) {
            menu.addItem(makeContextMenuItem(kind, representing: item))
        }
    }
}
