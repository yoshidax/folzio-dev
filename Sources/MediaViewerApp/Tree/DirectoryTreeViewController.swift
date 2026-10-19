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

    private let model: BrowserModel
    private let lister: any DirectoryListing
    private let volumes: any VolumeProviding
    private let coordinator: FileOperationCoordinator
    private let watcher: any FileSystemWatching
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()

    private var roots: [Node] = []
    private var volumeTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var didReveal = false

    init(
        model: BrowserModel,
        lister: any DirectoryListing,
        volumes: any VolumeProviding,
        coordinator: FileOperationCoordinator,
        watcher: any FileSystemWatching
    ) {
        self.model = model
        self.lister = lister
        self.volumes = volumes
        self.coordinator = coordinator
        self.watcher = watcher
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
        outlineView.reloadData()

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
            node.children = existing[folder.url.standardizedFileURL]?.children
            return node
        }
        outlineView.reloadData()
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

        outlineView.expandItem(current)
        await loadChildrenIfNeeded(current)

        let rootComponents = current.url.standardizedFileURL.pathComponents
        if targetComponents.count > rootComponents.count {
            for component in targetComponents[rootComponents.count...] {
                guard let next = current.children?.first(where: {
                    $0.url.lastPathComponent == component
                }) else {
                    break
                }
                outlineView.expandItem(next)
                await loadChildrenIfNeeded(next)
                current = next
            }
        }

        let row = outlineView.row(forItem: current)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
        }
    }

    private func loadChildrenIfNeeded(_ node: Node) async {
        guard node.children == nil, !node.isLoading else { return }
        node.isLoading = true
        defer { node.isLoading = false }

        do {
            let urls = try await lister.subfolders(of: node.url)
            let children = urls.map { url in
                Node(folder: FolderNode(
                    url: url,
                    name: url.lastPathComponent,
                    kind: .folder,
                    accessState: .accessible
                ))
            }
            node.children = children
            node.folder.children = children.map(\.folder)
            node.folder.accessState = .accessible
            outlineView.reloadItem(node, reloadChildren: true)
            outlineView.expandItem(node)
        } catch {
            node.children = []
            node.folder.children = []
            node.folder.accessState = error == .accessDenied ? .denied : .accessible
            outlineView.reloadItem(node, reloadChildren: true)
        }
        updateWatchSet()
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
        watcher.watch(folders)
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
            let children = urls.map { url in
                Node(folder: FolderNode(
                    url: url,
                    name: url.lastPathComponent,
                    kind: .folder,
                    accessState: .accessible
                ))
            }
            node.children = children
            node.folder.children = children.map(\.folder)
            node.folder.accessState = .accessible
            outlineView.reloadItem(node, reloadChildren: true)
            outlineView.expandItem(node)
        } catch {
            node.children = []
            node.folder.children = []
            node.folder.accessState = error == .accessDenied ? .denied : .accessible
            outlineView.reloadItem(node, reloadChildren: true)
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
        if let node = item as? Node {
            return node.children?.count ?? 0
        }
        return roots.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? Node {
            return node.children![index]
        }
        return roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? Node else { return false }
        return node.folder.accessState != .denied
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
        guard let node = item as? Node else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("FolderCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let text = NSTextField(labelWithString: "")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(text)
            cell.textField = text

            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = node.folder.name
        if node.folder.accessState == .denied {
            cell.textField?.textColor = .disabledControlTextColor
            cell.toolTip = "アクセスできません"
        } else {
            cell.textField?.textColor = .labelColor
            cell.toolTip = nil
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
        guard row >= 0, let node = outlineView.item(atRow: row) as? Node else { return }
        Task { [weak self] in
            await self?.model.selectFolder(node.url)
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
