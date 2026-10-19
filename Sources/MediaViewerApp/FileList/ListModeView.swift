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

    private var lastURLs: [URL] = []
    private var isApplyingSelection = false

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
        tableView.addTableColumn(column)
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.listing.files
            _ = model.selection.selected
            _ = model.selection.focused
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
