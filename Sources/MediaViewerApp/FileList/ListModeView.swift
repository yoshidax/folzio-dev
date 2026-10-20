import AppKit
import MediaViewerCore

@MainActor
private final class FileListTableView: NSTableView {
    var onSpace: (() -> Bool)?
    var onReturn: (() -> Bool)?

    override func keyDown(with event: NSEvent) {
        if event.specialKey == .carriageReturn
            || event.specialKey == .enter
            || event.charactersIgnoringModifiers == "\r" {
            let disallowed: NSEvent.ModifierFlags = [.command, .option, .control]
            if event.modifierFlags.intersection(disallowed).isEmpty,
               onReturn?() == true {
                return
            }
        }

        if event.charactersIgnoringModifiers == " ", onSpace?() == true {
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
private final class FileListIconCell: NSTableCellView {
    let iconView = NSImageView()
    let nameField = NSTextField(labelWithString: "")
    var iconTask: Task<Void, Never>?
    var representedURL: URL?
    var iconPointSize: Double = 0
    var iconScale: Double = 0

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.setAccessibilityElement(false)
        addSubview(iconView)
        imageView = iconView

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.lineBreakMode = .byTruncatingMiddle
        addSubview(nameField)
        textField = nameField

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),

            nameField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func cancelIconRequest(using provider: any ThumbnailProviding) {
        iconTask?.cancel()
        iconTask = nil
        if let url = representedURL, iconPointSize > 0, iconScale > 0 {
            provider.cancel(
                for: url,
                pointSize: iconPointSize,
                scale: iconScale
            )
        }
        representedURL = nil
    }
}

@MainActor
final class ListModeView: NSView {
    private let model: BrowserModel
    private let provider: any ThumbnailProviding
    private let scrollView = NSScrollView()
    private let tableView = FileListTableView()
    private let dateFormatter: DateFormatter

    var onTogglePlayback: (() -> Void)?
    var onRename: ((URL, String) async -> Void)?

    var contextMenu: NSMenu? {
        get { tableView.menu }
        set { tableView.menu = newValue }
    }

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
    private var renamingURL: URL?
    private var renamingOriginalName: String?
    private var isFinishingRename = false

    init(model: BrowserModel, provider: any ThumbnailProviding) {
        self.model = model
        self.provider = provider
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
        tableView.rowHeight = 20
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
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
        tableView.onReturn = { [weak self] in
            self?.beginRenaming() ?? false
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
            if renamingURL != nil {
                finishRenaming(commit: false)
            }
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

    @discardableResult
    func beginRenaming() -> Bool {
        guard renamingURL == nil else { return false }

        let selected = model.selection.selected
        guard selected.count == 1,
              let focused = model.selection.focused,
              selected.contains(focused),
              let row = model.listing.files.firstIndex(where: { $0.url == focused }),
              let window = tableView.window else {
            return false
        }

        tableView.scrollRowToVisible(row)
        tableView.layoutSubtreeIfNeeded()
        guard let cell = tableView.view(
            atColumn: 0,
            row: row,
            makeIfNecessary: true
        ) as? NSTableCellView,
            let field = cell.textField else {
            return false
        }

        renamingURL = focused
        renamingOriginalName = field.stringValue
        field.stringValue = focused.lastPathComponent
        setEditingAppearance(field, editing: true)

        guard window.makeFirstResponder(field) else {
            finishRenaming(commit: false)
            return false
        }

        if let editor = field.currentEditor() as? NSTextView {
            let baseName = (field.stringValue as NSString).deletingPathExtension
            editor.selectedRange = NSRange(location: 0, length: (baseName as NSString).length)
        }
        return true
    }

    private func finishRenaming(commit: Bool, newNameOverride: String? = nil) {
        guard !isFinishingRename,
              let url = renamingURL,
              let oldName = renamingOriginalName else {
            return
        }
        isFinishingRename = true
        defer { isFinishingRename = false }

        renamingURL = nil
        renamingOriginalName = nil

        var newName = oldName
        if let row = model.listing.files.firstIndex(where: { $0.url == url }),
           let cell = tableView.view(
               atColumn: 0,
               row: row,
               makeIfNecessary: false
           ) as? NSTableCellView,
           let field = cell.textField {
            let rawName = newNameOverride ?? field.stringValue
            newName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            setEditingAppearance(field, editing: false)
            field.stringValue = oldName
        }

        if let window = tableView.window,
           window.firstResponder !== tableView {
            window.makeFirstResponder(tableView)
        }

        guard commit, !newName.isEmpty, newName != oldName else { return }
        let handler = onRename
        Task { @MainActor in
            await handler?(url, newName)
        }
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

        if tableColumn.identifier.rawValue == "name" {
            return nameCell(for: file, identifier: tableColumn.identifier, in: tableView)
        }

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
            text.delegate = self
            setEditingAppearance(text, editing: false)
            cell.addSubview(text)
            cell.textField = text

            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        if let textField = cell.textField, renamingURL != file.url {
            setEditingAppearance(textField, editing: false)
        }

        switch tableColumn.identifier.rawValue {
        case "creationDate":
            cell.textField?.stringValue = file.creationDate.map(dateFormatter.string(from:)) ?? "--"
        case "kind":
            cell.textField?.stringValue = file.typeDescription
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    private func nameCell(
        for file: MediaFile,
        identifier: NSUserInterfaceItemIdentifier,
        in tableView: NSTableView
    ) -> FileListIconCell {
        let cell: FileListIconCell
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self)
            as? FileListIconCell {
            cell = reused
        } else {
            cell = FileListIconCell(identifier: identifier)
            cell.nameField.delegate = self
        }

        if cell.representedURL != file.url {
            cell.cancelIconRequest(using: provider)
            cell.representedURL = file.url
            cell.iconView.image = IconCatalog.fallbackIcon(for: file.kind)

            let scale = Double(
                window?.backingScaleFactor
                    ?? NSScreen.main?.backingScaleFactor
                    ?? 2
            )
            let pointSize = 16.0
            cell.iconPointSize = pointSize
            cell.iconScale = scale

            let provider = self.provider
            let url = file.url
            cell.iconTask = Task { [weak cell] in
                let image = await provider.thumbnail(
                    for: url,
                    pointSize: pointSize,
                    scale: scale
                )
                guard !Task.isCancelled,
                      let cell,
                      cell.representedURL == url,
                      let image else {
                    return
                }
                cell.iconView.image = NSImage(
                    cgImage: image,
                    size: NSSize(width: 16, height: 16)
                )
            }
        }

        if renamingURL != file.url {
            setEditingAppearance(cell.nameField, editing: false)
        }
        cell.nameField.stringValue = file.name
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

extension ListModeView: NSTextFieldDelegate {
    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        guard renamingURL != nil else { return false }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finishRenaming(commit: true, newNameOverride: textView.string)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            finishRenaming(commit: false)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard renamingURL != nil, !isFinishingRename else { return }
        finishRenaming(commit: true)
    }
}

extension ListModeView {
    func tableView(
        _ tableView: NSTableView,
        pasteboardWriterForRow row: Int
    ) -> NSPasteboardWriting? {
        guard row >= 0, row < model.listing.files.count else { return nil }
        return model.listing.files[row].url as NSURL
    }
}
