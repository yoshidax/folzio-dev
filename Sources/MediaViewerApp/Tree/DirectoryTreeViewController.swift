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
    private var didReveal = false

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

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: "")

        let pasteItem = NSMenuItem(
            title: "ここにペースト",
            action: #selector(paste(_:)),
            keyEquivalent: ""
        )
        pasteItem.target = self
        menu.addItem(pasteItem)

        let movePasteItem = NSMenuItem(
            title: "ここに移動ペースト",
            action: #selector(movePaste(_:)),
            keyEquivalent: ""
        )
        movePasteItem.target = self
        menu.addItem(movePasteItem)

        menu.addItem(.separator())

        let revealItem = NSMenuItem(
            title: "Finder に表示",
            action: #selector(revealInFinder(_:)),
            keyEquivalent: ""
        )
        revealItem.target = self
        menu.addItem(revealItem)

        return menu
    }

    @objc func paste(_ sender: Any?) {
        guard let node = selectedNode else { return }
        let destination = node.url
        Task { @MainActor in
            await coordinator.paste(into: destination, move: false)
        }
    }

    @objc func movePaste(_ sender: Any?) {
        guard let node = selectedNode else { return }
        let destination = node.url
        Task { @MainActor in
            await coordinator.paste(into: destination, move: true)
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
        guard let node = selectedNode else { return }
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
        outlineView.reloadData()
        startProbes(for: roots, key: .roots)
        updateWatchSet()
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
        updateWatchSet()
        let row = outlineView.selectedRow
        guard row >= 0, let role = role(for: outlineView.item(atRow: row)) else { return }
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
            return selectedNode != nil
                && FileContextMenu.pasteboardHasFileURLs()
        case #selector(revealInFinder(_:)):
            return selectedNode != nil
        default:
            return true
        }
    }
}
