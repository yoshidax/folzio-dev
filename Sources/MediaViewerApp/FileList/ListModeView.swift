import AppKit
import MediaViewerCore

@MainActor
private final class FileListTableView: NSTableView {
    var onSpace: (() -> Bool)?

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " ", onSpace?() == true {
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
final class ListModeView: NSView {
    private let model: BrowserModel
    private let scrollView = NSScrollView()
    private let tableView = FileListTableView()
    private let dateFormatter: DateFormatter

    var onTogglePlayback: (() -> Void)?

    private static let sortEntries: [(column: SortColumn, title: String)] = [
        (.name, "名前"),
        (.creationDate, "作成日"),
        (.kind, "種類"),
    ]

    private var lastURLs: [URL] = []
    private var isApplyingSelection = false
    private var isSyncingSortDescriptors = false
    private var sortMenuInstalled = false
    private var sortMenuItems: [NSMenuItem] = []

    init(model: BrowserModel) {
        self.model = model
        self.dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        super.init(frame: .zero)
        setup()
        applyModel()
        observeModel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var focusView: NSView { tableView }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        installSortMenuIfNeeded()
    }

    private func setup() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.onSpace = { [weak self] in
            guard let self,
                  let focused = self.model.selection.focused,
                  let kind = MediaKind(fileExtension: focused.pathExtension),
                  kind.isVideo else {
                return false
            }
            self.onTogglePlayback?()
            return true
        }

        addColumn(identifier: "name", title: "名前", width: 220)
        addColumn(identifier: "creationDate", title: "作成日", width: 150)
        addColumn(identifier: "kind", title: "種類", width: 150)

        scrollView.documentView = tableView
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func addColumn(identifier: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        column.minWidth = 80
        column.sortDescriptorPrototype = NSSortDescriptor(key: identifier, ascending: true)
        tableView.addTableColumn(column)
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.listing.files
            _ = model.selection.selected
            _ = model.selection.focused
            _ = model.sortOrder
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applyModel()
                self?.observeModel()
            }
        }
    }

    private func applyModel() {
        let urls = model.listing.files.map(\.url)
        let selected = IndexSet(model.selection.selected.compactMap { url in
            urls.firstIndex(of: url)
        })

        isApplyingSelection = true
        if urls != lastURLs {
            lastURLs = urls
            tableView.reloadData()
        }
        if tableView.selectedRowIndexes != selected {
            tableView.selectRowIndexes(selected, byExtendingSelection: false)
        }
        isApplyingSelection = false

        if let focused = model.selection.focused, let row = urls.firstIndex(of: focused) {
            tableView.scrollRowToVisible(row)
        }

        syncSortDescriptors()
        updateSortMenuItems()
    }

    private func syncSortDescriptors() {
        let order = model.sortOrder
        let current = tableView.sortDescriptors.first
        guard current?.key != order.column.rawValue
            || current?.ascending != order.ascending else {
            return
        }

        isSyncingSortDescriptors = true
        tableView.sortDescriptors = [
            NSSortDescriptor(key: order.column.rawValue, ascending: order.ascending)
        ]
        isSyncingSortDescriptors = false
    }

    private func installSortMenuIfNeeded() {
        guard !sortMenuInstalled else { return }
        guard let viewMenu = NSApp.mainMenu?.items
            .first(where: { $0.submenu?.title == "表示" })?
            .submenu else {
            return
        }
        sortMenuInstalled = true

        let submenu: NSMenu
        if let existing = viewMenu.items
            .first(where: { $0.title == "並べ替え" })?
            .submenu {
            submenu = existing
        } else {
            submenu = NSMenu(title: "並べ替え")
            let parentItem = NSMenuItem(title: "並べ替え", action: nil, keyEquivalent: "")
            parentItem.submenu = submenu
            viewMenu.addItem(parentItem)
        }

        sortMenuItems = Self.sortEntries.enumerated().map { index, entry in
            let item = NSMenuItem(
                title: entry.title,
                action: #selector(chooseSortColumn(_:)),
                keyEquivalent: ""
            )
            item.tag = index
            item.target = self
            submenu.addItem(item)
            return item
        }
        updateSortMenuItems()
    }

    private func updateSortMenuItems() {
        guard !sortMenuItems.isEmpty else { return }
        let order = model.sortOrder
        for (index, item) in sortMenuItems.enumerated() {
            guard index < Self.sortEntries.count else { break }
            let entry = Self.sortEntries[index]
            let isActive = entry.column == order.column
            item.state = isActive ? .on : .off
            item.title = isActive
                ? "\(entry.title)（\(order.ascending ? "昇順" : "降順")）"
                : entry.title
        }
    }

    @objc private func chooseSortColumn(_ sender: NSMenuItem) {
        guard sender.tag >= 0, sender.tag < Self.sortEntries.count else { return }
        let column = Self.sortEntries[sender.tag].column
        let current = model.sortOrder
        let ascending = current.column == column ? !current.ascending : true
        model.sortOrder = SortOrder(column: column, ascending: ascending)
        updateSortMenuItems()
    }
}

extension ListModeView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        model.listing.files.count
    }
}

extension ListModeView: NSTableViewDelegate {
    func tableView(
        _ tableView: NSTableView,
        sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]
    ) {
        guard !isSyncingSortDescriptors else { return }
        guard let descriptor = tableView.sortDescriptors.first,
              let key = descriptor.key,
              let column = SortColumn(rawValue: key) else {
            return
        }

        model.sortOrder = SortOrder(column: column, ascending: descriptor.ascending)
        updateSortMenuItems()
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard let tableColumn, row < model.listing.files.count else { return nil }
        let file = model.listing.files[row]

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self)
            as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = tableColumn.identifier

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

        switch tableColumn.identifier.rawValue {
        case "name":
            cell.textField?.stringValue = file.name
        case "creationDate":
            cell.textField?.stringValue = file.creationDate.map(dateFormatter.string(from:)) ?? "--"
        case "kind":
            cell.textField?.stringValue = file.typeDescription
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingSelection else { return }

        let files = model.listing.files
        let urls = tableView.selectedRowIndexes.compactMap { row in
            row < files.count ? files[row].url : nil
        }

        let focusedRow: Int
        if tableView.selectedRow >= 0 {
            focusedRow = tableView.selectedRow
        } else {
            focusedRow = tableView.selectedRowIndexes.first ?? -1
        }
        let focused = focusedRow >= 0 && focusedRow < files.count
            ? files[focusedRow].url
            : nil

        model.select(Set(urls), focused: focused)
    }
}
