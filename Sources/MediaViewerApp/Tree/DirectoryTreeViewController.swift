import AppKit
import MediaViewerCore
import MediaViewerLocalization

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
        /// 表示名。変更していなければ `defaultName`（FR-101）
        var name: String
        /// 登録したフォルダの名前（ルートならボリューム名）。空の名前で確定したときの戻り先（FR-100）
        var defaultName: String
        var kind: FolderNode.Kind
        var availability: FavoriteAvailability = .unknown

        init(url: URL, name: String, defaultName: String, kind: FolderNode.Kind) {
            self.url = url
            self.name = name
            self.defaultName = defaultName
            self.kind = kind
        }
    }

    private let model: BrowserModel
    private let lister: any DirectoryListing
    private let volumes: any VolumeProviding
    private let coordinator: FileOperationCoordinator
    private let watcher: any FileSystemWatching
    /// 外部の変更で消えた場所を履歴から取り除く（FR-109）
    weak var historyNavigator: HistoryNavigator?
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
    /// クリック（mouseDown）で選択が変わったときの、そのクリックのイベント番号。同じクリックの mouseUp で
    /// 送られる `action` では、選択の変化で始めた `selectFolder` を重ねて呼ばない
    private var selectionChangeClickNumber: Int?
    private var eventTask: Task<Void, Never>?
    private var favoriteProbeTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?
    private var didReveal = false
    private var isRestoringSelection = false
    /// 名前を変えたフォルダ（またはその配下）を選択していたとき、親の読み直しで並び位置が変わった後に見える位置まで
    /// スクロールする（FR-104）
    private var needsRevealSelectionAfterRename = false

    /// 行内編集の対象。お気に入りの表示名と、通常のフォルダの名前で編集の仕組みを共有する（R60）
    private enum EditingTarget {
        case favorite(FavoriteEntry)
        case folder(Node)

        var item: AnyObject {
            switch self {
            case .favorite(let entry): entry
            case .folder(let node): node
            }
        }

        var name: String {
            switch self {
            case .favorite(let entry): entry.name
            case .folder(let node): node.folder.name
            }
        }
    }

    /// 名前の変更中の行。nil 以外の間は「名前の変更中」（FR-102）
    private var editingTarget: EditingTarget?
    private var editingOriginalName: String?
    private var isFinishingEdit = false
    private var needsReloadAfterEdit = false
    private let favoriteNameFormatter = FavoriteNameFormatter()

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

    func scrollSelectedRowToVisible() {
        let row = outlineView.selectedRow
        guard row >= 0 else { return }
        outlineView.scrollRowToVisible(row)
    }

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
            let defaultName = root?.folder.name ?? url.lastPathComponent
            let name = favorites.displayName(for: url, defaultName: defaultName)
            let kind = root?.folder.kind ?? .folder
            if let entry = existing[key] {
                entry.name = name
                entry.defaultName = defaultName
                entry.kind = kind
                return entry
            }
            return FavoriteEntry(url: url, name: name, defaultName: defaultName, kind: kind)
        }
    }

    private var rootURLs: [URL] { roots.map(\.url) }

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
            menuItem = NSMenuItem(title: l10n.text(.contextPasteHere), action: #selector(paste(_:)), keyEquivalent: "")
        case .movePasteHere:
            menuItem = NSMenuItem(title: l10n.text(.contextMovePasteHere), action: #selector(movePaste(_:)), keyEquivalent: "")
        case .addToFavorites:
            menuItem = NSMenuItem(
                title: l10n.text(.menuFileAddToFavorites),
                action: #selector(addToFavorites(_:)),
                keyEquivalent: "t"
            )
            menuItem.keyEquivalentModifierMask = [.command, .control]
        case .revealInFinder:
            menuItem = NSMenuItem(title: l10n.text(.menuFileRevealInFinder), action: #selector(revealInFinder(_:)), keyEquivalent: "")
        case .removeFromFavorites:
            menuItem = NSMenuItem(
                title: l10n.text(.menuFileRemoveFromFavorites),
                action: #selector(removeFavoriteFromMenu(_:)),
                keyEquivalent: String(UnicodeScalar(NSBackspaceCharacter)!)
            )
            menuItem.keyEquivalentModifierMask = [.command]
        case .moveToTrash:
            menuItem = NSMenuItem(
                title: l10n.text(.menuFileTrash),
                action: #selector(trashFolderFromMenu(_:)),
                keyEquivalent: String(UnicodeScalar(NSBackspaceCharacter)!)
            )
            menuItem.keyEquivalentModifierMask = [.command]
        case .renameFavorite:
            menuItem = NSMenuItem(
                title: l10n.text(.menuEditRename),
                action: #selector(renameFavoriteFromMenu(_:)),
                keyEquivalent: "\r"
            )
            menuItem.keyEquivalentModifierMask = []
        case .renameFolder:
            menuItem = NSMenuItem(
                title: l10n.text(.menuEditRename),
                action: #selector(renameFolderFromMenu(_:)),
                keyEquivalent: "\r"
            )
            menuItem.keyEquivalentModifierMask = []
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

    /// ⌘⌫。お気に入りの項目ならお気に入りから削除（FR-064）、ルート以外のフォルダならゴミ箱に入れる（FR-079）
    @objc func moveToTrash(_ sender: Any?) {
        if let entry = selectedFavoriteEntry {
            Task { [weak self] in
                await self?.removeFavorite(entry)
            }
            return
        }
        guard let url = FavoriteCommands.trashTarget(role(for: selectedItem), roots: rootURLs) else { return }
        // ツリーのゴミ箱は確認の省略設定に関わらず確認する（FR-079、R66）
        Task { @MainActor [coordinator] in
            await coordinator.trash([url], origin: .tree)
        }
    }

    /// 右クリックメニューの「ゴミ箱に入れる」。右クリックした行を対象にし、キーボードフォーカスは移さない（R33）
    @objc private func trashFolderFromMenu(_ sender: Any?) {
        let role = role(for: targetItem(for: sender))
        guard let url = FavoriteCommands.trashTarget(role, roots: rootURLs) else { return }
        Task { @MainActor [coordinator] in
            await coordinator.trash([url], origin: .tree)
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

    /// ツリーにフォーカスがあるときの Return・「編集 > 名前を変更」。お気に入りの項目は表示名の編集（FR-099）、
    /// ルート以外の通常のフォルダは実際のフォルダの名前の編集（FR-103）を始める。
    /// zip の中・検索結果の表示中も `BrowserModel` の状態は見ない（EC-46）
    @objc func rename(_ sender: Any?) {
        guard let target = editingTarget(for: selectedItem) else { return }
        beginEditing(target)
    }

    /// 右クリックした行の「名前を変更」（お気に入りの項目）。ツリーの選択は変えない（A-21、FR-099）
    @objc private func renameFavoriteFromMenu(_ sender: Any?) {
        let item = (sender as? NSMenuItem)?.representedObject
        guard let target = editingTarget(for: item), case .favorite = target else { return }
        beginEditingFromMenu(target)
    }

    /// 右クリックした行の「名前を変更」（通常のフォルダ）。ツリーの選択は変えない（A-21・A-36、FR-103）
    @objc private func renameFolderFromMenu(_ sender: Any?) {
        let item = (sender as? NSMenuItem)?.representedObject
        guard let target = editingTarget(for: item), case .folder = target else { return }
        beginEditingFromMenu(target)
    }

    /// 行の名前を変更できるなら、その編集の対象（R59）
    private func editingTarget(for item: Any?) -> EditingTarget? {
        switch FavoriteCommands.renameTarget(role(for: item), roots: rootURLs) {
        case .favorite:
            return (item as? FavoriteEntry).map(EditingTarget.favorite)
        case .folder:
            return (item as? Node).map(EditingTarget.folder)
        case nil:
            return nil
        }
    }

    private func beginEditingFromMenu(_ target: EditingTarget) {
        if !beginEditing(target) {
            // メニューの追跡中は makeFirstResponder に失敗することがあるため、次のターンに回す（R52）
            Task { @MainActor [weak self] in
                self?.beginEditing(target)
            }
        }
    }

    @discardableResult
    private func beginEditing(_ target: EditingTarget) -> Bool {
        guard editingTarget == nil else { return false }
        guard let window = outlineView.window else { return false }
        let row = outlineView.row(forItem: target.item)
        guard row >= 0 else { return false }

        outlineView.scrollRowToVisible(row)
        outlineView.layoutSubtreeIfNeeded()
        guard let cell = outlineView.view(
            atColumn: 0,
            row: row,
            makeIfNecessary: true
        ) as? NSTableCellView,
            let field = cell.textField else {
            return false
        }

        let name = target.name
        editingTarget = target
        editingOriginalName = name
        needsReloadAfterEdit = false
        field.stringValue = name
        configureEditingField(field, for: target)

        guard window.makeFirstResponder(field) else {
            editingTarget = nil
            editingOriginalName = nil
            resetEditingState(of: cell)
            field.stringValue = name
            return false
        }
        if let editor = field.currentEditor() as? NSTextView {
            // お気に入りは全選択（FR-099）、フォルダはファイルリストと同じく最後の「.」より前（FR-103）
            let selected: String
            switch target {
            case .favorite:
                selected = field.stringValue
            case .folder:
                selected = (field.stringValue as NSString).deletingPathExtension
            }
            editor.selectedRange = NSRange(location: 0, length: (selected as NSString).length)
        }
        return true
    }

    /// 行内編集を終える。`restoresFocus` のときはキーボードフォーカスをツリーに戻す（R51）
    private func finishEditing(commit: Bool, restoresFocus: Bool) {
        guard !isFinishingEdit, let target = editingTarget else { return }
        isFinishingEdit = true
        defer { isFinishingEdit = false }

        let originalName = editingOriginalName ?? target.name
        editingTarget = nil
        editingOriginalName = nil

        let row = outlineView.row(forItem: target.item)
        var field: NSTextField?
        var input = originalName
        if row >= 0,
           let cell = outlineView.view(
               atColumn: 0,
               row: row,
               makeIfNecessary: false
           ) as? NSTableCellView,
           let textField = cell.textField {
            field = textField
            input = textField.stringValue
            resetEditingState(of: cell)
            textField.stringValue = originalName
        }

        if let window = outlineView.window {
            if restoresFocus {
                window.makeFirstResponder(outlineView)
            } else if let field, field.currentEditor() != nil {
                // クリック先のフォーカスは変えない（A-31）
                window.endEditing(for: field)
            }
        }

        if commit {
            switch target {
            case .favorite(let entry):
                if favorites.commitDisplayName(input, for: entry.url, defaultName: entry.defaultName) {
                    settings.favorites = favorites
                    rebuildFavoriteEntries()
                }
            case .folder(let node):
                // 空・編集前と同じ名前は何もしない（EC-48）。検証・確認・失敗の表示はファイルリストと同じくコーディネータが行う（R60）
                let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, name != originalName {
                    let url = node.url
                    Task { @MainActor [coordinator] in
                        await coordinator.rename(url, to: name, origin: .tree)
                    }
                }
            }
        }

        if row >= 0 {
            outlineView.reloadItem(target.item)
        }
        needsReloadAfterEdit = false
    }

    /// ツリーの側から編集を確定するとき、編集欄にフォーカスがあったかを確かめる（R51）
    private var editingFieldHasFocus: Bool {
        guard let target = editingTarget else { return false }
        let row = outlineView.row(forItem: target.item)
        guard row >= 0,
              let cell = outlineView.view(
                  atColumn: 0,
                  row: row,
                  makeIfNecessary: false
              ) as? NSTableCellView,
              let field = cell.textField else {
            return false
        }
        return field.currentEditor() != nil
    }

    /// お気に入りは改行と長さを制限する Formatter を付ける。フォルダはファイルリストの編集欄と同じく付けない（R60）
    private func configureEditingField(_ field: NSTextField, for target: EditingTarget) {
        switch target {
        case .favorite:
            field.formatter = favoriteNameFormatter
            field.setAccessibilityLabel(l10n.text(.treeA11yFavoriteName))
        case .folder:
            field.formatter = nil
            field.setAccessibilityLabel(l10n.text(.treeA11yFolderName))
        }
        field.delegate = self
        setEditingAppearance(field, editing: true)
    }

    private func setEditingAppearance(_ field: NSTextField, editing: Bool) {
        field.isEditable = editing
        field.isSelectable = editing
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = editing
        field.backgroundColor = editing ? .textBackgroundColor : .clear
        field.focusRingType = editing ? .default : .none
    }

    private func resetEditingState(of cell: NSTableCellView) {
        guard let field = cell.textField else { return }
        setEditingAppearance(field, editing: false)
        field.formatter = nil
        field.delegate = nil
        field.setAccessibilityLabel(nil)
    }

    /// セルは行の間で共有されるため、表示のたびに編集の状態を戻す（R51・R54）。
    /// 編集中の行だけは入力中の値を保つ
    private func prepareCell(_ cell: NSTableCellView, for item: Any) {
        guard let field = cell.textField else { return }
        if let target = editingTarget,
           (item as AnyObject) === target.item,
           field.currentEditor() != nil {
            configureEditingField(field, for: target)
            return
        }
        resetEditingState(of: cell)
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
        guard await confirmation.confirmRemovingFavorite(named: entry.name, path: entry.url.path) else { return }
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

    /// 検索結果の表示中に、選択中のフォルダの行をクリックしたら、そのフォルダの一覧に戻す（FR-086）。
    /// 開閉の三角と「お気に入り」の見出しでは何もしない。選択が変わるクリックは outlineViewSelectionDidChange に任せる
    @objc private func clickedRow(_ sender: Any?) {
        let event = NSApp.currentEvent
        defer { selectionChangeClickNumber = nil }
        guard model.isShowingSearchResults else { return }
        let row = outlineView.clickedRow
        guard row >= 0, row == outlineView.selectedRow else { return }
        if let event, let number = selectionChangeClickNumber, event.eventNumber == number { return }
        if let event {
            let point = outlineView.convert(event.locationInWindow, from: nil)
            if outlineView.frameOfOutlineCell(atRow: row).contains(point) { return }
        }
        guard let role = role(for: outlineView.item(atRow: row)),
              let url = FavoriteCommands.folderToShow(for: role) else { return }
        revealTask?.cancel()
        revealTask = nil
        Task { [weak self] in
            await self?.model.selectFolder(url)
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
        // 選択中の行のクリックは選択の変化を通知しないため、検索結果の表示を終えるのに action を使う（FR-086、R37）
        outlineView.action = #selector(clickedRow(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        column.title = l10n.text(.treeColumn)
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
                await self.historyNavigator?.revalidateAll()
                // 起点を含むボリュームが外されたとき、存在しなくなった検索結果を外す（Edge Cases、R38）
                if self.model.isShowingSearchResults {
                    await self.model.reloadCurrentFolder()
                }
            }
        }

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await changed in self.watcher.events {
                await self.model.handleFileSystemEvent(changed)
                await self.historyNavigator?.handleFileSystemEvent(changed)
                await self.refreshFolders(changed)
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
        observeTreeSyncRequest()
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
        // reloadData で全行のセルを作り直すため、その前に編集中の名前を確定する（R51、EC-43・quickstart 24）
        if editingTarget != nil {
            finishEditing(commit: true, restoresFocus: editingFieldHasFocus)
        }
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
        model.setNavigationRoots(roots.map(\.url))
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
            if entry === editingTarget?.item {
                // 編集中の行は描き直さず、終了時の reloadItem で淡色を反映する（R51、EC-43）
                needsReloadAfterEdit = true
            } else if outlineView.row(forItem: entry) >= 0 {
                outlineView.reloadItem(entry)
            }
        }
    }

    /// 変更のあったフォルダに、登録したフォルダの親か祖先が含まれるときだけ確かめ直す。祖先の名前の変更・戻しでも
    /// 見つからない表示が変わるため（FR-106、R65）
    private func refreshFavoriteAvailabilityIfNeeded(in changed: Set<URL>) {
        let changedComponents = changed.map(\.standardizedFileURL.pathComponents)
        let affected = favorites.urls.contains { url in
            let components = url.standardizedFileURL.pathComponents
            return changedComponents.contains { components.count > $0.count && components.starts(with: $0) }
        }
        if affected {
            refreshFavoriteAvailability()
        }
    }

    /// フォルダの名前の変更に成功したときに、読み込み済みのノードの場所を付け替える。ノードのオブジェクトは作り直さず、
    /// 展開状態・選択・サブフォルダの有無の確認結果を保つ。続く親の読み直しで並び順の位置へ移る（FR-104・106、R64・R65）
    func didRenameFolder(from oldURL: URL, to newURL: URL) {
        let renamed = RenamedFolder(from: oldURL, to: newURL)
        let oldPath = oldURL.standardizedFileURL.path
        let selected = selectedNode
        var changedNodes: [Node] = []
        let nodes = flattenedNodes(from: roots)
        for node in nodes {
            guard let url = renamed.rebase(node.url) else { continue }
            if node.url.standardizedFileURL.path == oldPath {
                node.folder.name = newURL.lastPathComponent
                changedNodes.append(node)
                if let selected, renamed.rebase(selected.url) != nil {
                    needsRevealSelectionAfterRename = true
                }
            }
            node.folder.url = url
        }
        for node in nodes where node.children != nil {
            node.folder.children = node.children?.map(\.folder)
        }
        for node in changedNodes where outlineView.row(forItem: node) >= 0 {
            outlineView.reloadItem(node, reloadChildren: false)
        }
        updateWatchSet()
        refreshFavoriteAvailability()
    }

    /// 登録した各フォルダの親。`/` の登録は親がないため除く
    private func favoriteParentFolders() -> [URL] {
        favorites.urls.compactMap { url in
            let standardized = url.standardizedFileURL
            guard standardized.path != "/" else { return nil }
            return standardized.deletingLastPathComponent().standardizedFileURL
        }
    }

    /// 変更のあったフォルダの子・サブフォルダの有無・お気に入りの存在を読み直す。FSEvents のバッチと、
    /// ファイル操作の完了（FSEvents を待たずに反映する。FR-027、R32）の両方から呼ぶ
    func refreshFolders(_ changed: Set<URL>) async {
        await reloadExpandedNodes(in: changed)
        recheckCollapsedNodes(in: changed)
        updateWatchSet()
        refreshFavoriteAvailabilityIfNeeded(in: changed)
    }

    private func reveal(_ target: URL) async {
        guard let node = await expandAncestors(of: target) else { return }
        let row = outlineView.row(forItem: node)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
        }
    }

    /// ルートから対象のフォルダまで、各段の子を読み込んで展開する。辿れた最も深いノードを返す（取り消されたら nil）
    private func expandAncestors(of target: URL) async -> Node? {
        let targetComponents = target.standardizedFileURL.pathComponents

        // 対象を含むルートのうち最も深いものから辿る（ホームの配下を起動ボリューム側から辿らない。R30）
        var root = roots
            .filter { targetComponents.starts(with: $0.url.standardizedFileURL.pathComponents) }
            .max { $0.url.standardizedFileURL.pathComponents.count < $1.url.standardizedFileURL.pathComponents.count }
        if root == nil {
            root = roots.first { $0.folder.kind == .home }
        }
        guard var current = root else { return nil }

        await loadAndExpand(current)
        guard !Task.isCancelled else { return nil }

        let rootComponents = current.url.standardizedFileURL.pathComponents
        if targetComponents.count > rootComponents.count {
            for component in targetComponents[rootComponents.count...] {
                guard let next = current.children?.first(where: {
                    $0.url.lastPathComponent == component
                }) else {
                    break
                }
                await loadAndExpand(next)
                guard !Task.isCancelled else { return nil }
                current = next
            }
        }
        return current
    }

    /// ファイルリストの中での移動（フォルダを開く・戻る）をツリーの選択に反映する（FR-078、R31）
    private func observeTreeSyncRequest() {
        withObservationTracking {
            _ = model.treeSyncRequest
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if let request = self.model.treeSyncRequest {
                    self.syncSelection(to: request)
                }
                self.observeTreeSyncRequest()
            }
        }
    }

    /// 実際の階層で依頼のフォルダまで展開し、その行を選択して必要最小限スクロールする。
    /// 選択の変更から selectFolder を呼び返さず、キーボードフォーカスも移さない
    private func syncSelection(to request: TreeSyncRequest) {
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            guard let self else { return }
            let node = await self.expandAncestors(of: request.folder)
            // 後の依頼・ツリーでの選択・一覧の別の移動があれば、古い同期で選択を上書きしない
            guard !Task.isCancelled,
                  let node,
                  self.model.treeSyncRequest?.id == request.id,
                  self.model.listing.folder.standardizedFileURL == request.folder.standardizedFileURL else {
                return
            }
            let row = self.outlineView.row(forItem: node)
            guard row >= 0 else { return }
            self.isRestoringSelection = true
            self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            self.isRestoringSelection = false
            self.outlineView.scrollRowToVisible(row)
            self.updateWatchSet()
            // 検索結果から開いたフォルダがツリーに出ない場合は、選択できた最も近い祖先を Core が保存する（EC-102）
            self.model.completeSearchResultTreeSync(request, selectedFolder: node.url)
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

        let requested = node.url
        let result: Result<[URL], ListingError>
        do {
            result = .success(try await lister.subfolders(of: requested))
        } catch {
            result = .failure(error)
        }
        // 読み込み中に名前が変わったノードには古い場所の結果を当てない。次の展開で新しい場所を読む（R64）
        guard node.url == requested else { return }
        applyListing(result, to: node)
        updateWatchSet()
    }

    private func applyListing(_ result: Result<[URL], ListingError>, to node: Node) {
        switch result {
        case .success(let urls):
            // 行を作り直すと編集欄が消えるため、編集中の子があれば先に確定する（R51）
            if case .folder(let editing) = editingTarget, node.children?.contains(where: { $0 === editing }) == true {
                finishEditing(commit: true, restoresFocus: editingFieldHasFocus)
            }
            let previous = Dictionary(
                (node.children ?? []).map { ($0.url.standardizedFileURL, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            // 同じ場所のノードは使い回し、展開状態と読み込み済みの子を保つ（名前を変えたノードも付け替え済み。R64）
            let children = urls.map { url -> Node in
                if let old = previous[url.standardizedFileURL] {
                    old.folder.url = url
                    old.folder.name = url.lastPathComponent
                    return old
                }
                return Node(folder: FolderNode(
                    url: url,
                    name: url.lastPathComponent,
                    kind: .folder,
                    accessState: .accessible
                ))
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
            // 検索の開始・解除で、起点以下の監視（subtrees）を差し替える
            _ = model.listing.search?.root
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
        // 検索結果の表示中は、起点以下のすべての階層の変更を受け取り、消えた結果を外す（FR-087、R38）
        watcher.watch(folders, subtrees: model.listing.search.map { [$0.root.standardizedFileURL] } ?? [])
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
        let requested = node.url
        let result: Result<[URL], ListingError>
        do {
            result = .success(try await lister.subfolders(of: requested))
        } catch {
            result = .failure(error)
        }
        guard node.url == requested else { return }
        let selectedURL = selectedNode?.url

        // 選択中の行が読み直しで消えても selectFolder が呼ばれないよう、反映と選び直しは isRestoringSelection の間に行う（R33）
        isRestoringSelection = true
        defer { isRestoringSelection = false }
        applyListing(result, to: node)

        guard let selectedURL else { return }
        // 選択中の行がなければ、残っている最も近い祖先の行を選ぶ
        var candidate: URL? = selectedURL
        while let url = candidate {
            if let row = rowForURL(url) {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                if needsRevealSelectionAfterRename {
                    needsRevealSelectionAfterRename = false
                    outlineView.scrollRowToVisible(row)
                }
                return
            }
            let parent = url.deletingLastPathComponent()
            candidate = parent.standardizedFileURL.path == url.standardizedFileURL.path ? nil : parent
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
              let urls = fileURLs(from: info.draggingPasteboard) else {
            return []
        }
        // フォルダを自分自身やその配下へはドロップできない（spec Edge Cases、R32）
        let destination = node.url.standardizedFileURL.pathComponents
        if urls.contains(where: { destination.starts(with: $0.standardizedFileURL.pathComponents) }) {
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
            prepareCell(cell, for: item)
            cell.imageView?.image = IconCatalog.treeIcon(for: node.folder.kind)
            if node !== editingTarget?.item {
                cell.textField?.stringValue = node.folder.name
            }
            cell.textField?.toolTip = node.folder.name
            if node.folder.accessState == .denied || node.folder.accessState == .unavailable {
                cell.textField?.textColor = .disabledControlTextColor
                cell.toolTip = l10n.text(.treeTooltipNotAccessible)
            } else {
                cell.textField?.textColor = .labelColor
                cell.toolTip = nil
            }
            return cell
        case is FavoritesHeader:
            let cell = makeFolderCell(in: outlineView)
            prepareCell(cell, for: item)
            cell.imageView?.image = IconCatalog.favoritesIcon()
            cell.textField?.stringValue = l10n.text(.treeFavorites)
            cell.textField?.toolTip = nil
            cell.textField?.textColor = .labelColor
            cell.toolTip = nil
            return cell
        case let entry as FavoriteEntry:
            let cell = makeFolderCell(in: outlineView)
            prepareCell(cell, for: item)
            cell.imageView?.image = IconCatalog.treeIcon(for: entry.kind)
            if entry !== editingTarget?.item {
                cell.textField?.stringValue = entry.name
            }
            cell.textField?.toolTip = entry.name
            if entry.availability == .missing {
                cell.textField?.textColor = .disabledControlTextColor
                cell.toolTip = l10n.text(.treeTooltipNotFound)
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
        if let event = NSApp.currentEvent, event.type == .leftMouseDown {
            selectionChangeClickNumber = event.eventNumber
        }
        updateWatchSet()
        let row = outlineView.selectedRow
        guard row >= 0, let role = role(for: outlineView.item(atRow: row)) else { return }
        if case .favorite = role {
            refreshFavoriteAvailability()
        }
        // 見出しでは一覧を切り替えない（FR-065）。お気に入りの項目でも実際の階層は動かさない（FR-063）
        guard let url = FavoriteCommands.folderToShow(for: role) else { return }
        // ツリーからの選択は treeSyncRequest を変えないため、進行中の同期がユーザーの選択を上書きしないよう取り消す（R31）
        revealTask?.cancel()
        revealTask = nil
        Task { [weak self] in
            await self?.model.selectFolder(url)
        }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        updateWatchSet()
    }

    func outlineViewItemWillCollapse(_ notification: Notification) {
        // 開閉ボタンのクリックでは first responder が変わらないことがある。行が消える前に確定する（R51）
        guard let target = editingTarget,
              let collapsing = notification.userInfo?["NSObject"] as AnyObject? else {
            return
        }
        var ancestor = outlineView.parent(forItem: target.item) as AnyObject?
        while let current = ancestor {
            if current === collapsing {
                finishEditing(commit: true, restoresFocus: true)
                return
            }
            ancestor = outlineView.parent(forItem: current) as AnyObject?
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        updateWatchSet()
    }
}

extension DirectoryTreeViewController: NSTextFieldDelegate {
    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        guard editingTarget != nil else { return false }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finishEditing(commit: true, restoresFocus: true)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Esc は編集前の表示名に戻す（US1-AS32）
            finishEditing(commit: false, restoresFocus: true)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        // ほかの場所のクリックなどで確定する。クリック先のフォーカスは変えない（A-31）
        guard editingTarget != nil, !isFinishingEdit else { return }
        finishEditing(commit: true, restoresFocus: false)
    }
}

extension DirectoryTreeViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Return と ⌘⌫ はメニューのキー等価がフィールドエディタより先に処理される。無効にしないと編集中の Return が
        // 確定にならず、⌘⌫ でお気に入りが削除される（R53、FR-102）
        if editingTarget != nil {
            switch menuItem.action {
            case #selector(rename(_:)),
                 #selector(renameFavoriteFromMenu(_:)),
                 #selector(renameFolderFromMenu(_:)),
                 #selector(moveToTrash(_:)),
                 #selector(trashFolderFromMenu(_:)),
                 #selector(paste(_:)),
                 #selector(movePaste(_:)),
                 #selector(revealInFinder(_:)),
                 #selector(addToFavorites(_:)),
                 #selector(removeFavoriteFromMenu(_:)):
                return false
            default:
                break
            }
        }

        switch menuItem.action {
        case #selector(rename(_:)):
            // お気に入りの項目とルート以外のフォルダだけ。見出し・ルート・未選択では無効（US1-AS35・45、FR-099・FR-103）
            return editingTarget(for: selectedItem) != nil
        case #selector(renameFavoriteFromMenu(_:)):
            if case .favorite = editingTarget(for: menuItem.representedObject) { return true }
            return false
        case #selector(renameFolderFromMenu(_:)):
            if case .folder = editingTarget(for: menuItem.representedObject) { return true }
            return false
        case #selector(paste(_:)), #selector(movePaste(_:)):
            return fileTargetNode(for: menuItem) != nil
                && FileContextMenu.pasteboardHasFileURLs()
        case #selector(revealInFinder(_:)):
            return fileTargetNode(for: menuItem) != nil
        case #selector(moveToTrash(_:)):
            // ⌘⌫ はお気に入りの項目なら「お気に入りから削除」（FR-064）、ルート以外のフォルダなら「ゴミ箱に入れる」（FR-079）
            if selectedFavoriteEntry != nil {
                menuItem.title = l10n.text(.menuFileRemoveFromFavorites)
                return true
            }
            menuItem.title = l10n.text(.menuFileTrash)
            return FavoriteCommands.trashTarget(role(for: selectedItem), roots: rootURLs) != nil
        case #selector(trashFolderFromMenu(_:)):
            return FavoriteCommands.trashTarget(role(for: targetItem(for: menuItem)), roots: rootURLs) != nil
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
        // メニューを開く前に編集中の名前を確定する。右クリック先はツリーなのでフォーカスを戻す（R51）
        if editingTarget != nil {
            finishEditing(commit: true, restoresFocus: editingFieldHasFocus)
        }
        menu.removeAllItems()
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0,
              let item = outlineView.item(atRow: row),
              let role = role(for: item) else {
            return
        }
        // 見出しは項目なし（メニューを出さない）
        for kind in FavoriteCommands.contextMenu(for: role, roots: rootURLs) {
            menu.addItem(makeContextMenuItem(kind, representing: item))
        }
    }
}
