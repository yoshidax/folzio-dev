import AppKit
import FolzioCore
import FolzioLocalization

@MainActor
final class ReceivingPanelController: NSObject {
    private let panel: NSPanel
    private let stack = NSStackView()
    private let cancel: (UUID) -> Void
    private var rows: [ImportProgressRow] = []
    private var languageObserver: LanguageChangeObserver?

    init(cancel: @escaping (UUID) -> Void) {
        self.cancel = cancel
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 120),
            styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        panel.contentView = stack
        panel.center()
        languageObserver = LanguageChangeObserver { [weak self] in
            guard let self else { return }
            self.update(self.rows)
        }
    }

    func update(_ rows: [ImportProgressRow]) {
        self.rows = rows
        panel.title = l10n.receivingStageText(isChecking: false)
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
        for row in rows {
            let title = NSTextField(labelWithString: row.destination)
            title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
            let size = ByteCountFormatter.string(fromByteCount: Int64(clamping: row.bytes), countStyle: .file)
            let detail = NSTextField(labelWithString: l10n.receivingProgressText(total: row.total, completed: row.completed, size: size))
            let stage = NSTextField(labelWithString: l10n.receivingStageText(isChecking: row.checking))
            let button = NSButton(title: l10n.receivingCancelTitle, target: self, action: #selector(cancelClicked(_:)))
            button.identifier = .init(row.id.uuidString)
            button.setAccessibilityLabel(l10n.receivingCancelTitle + " " + row.destination)
            let text = NSStackView(views: [title, detail, stage])
            text.orientation = .vertical; text.alignment = .leading
            let line = NSStackView(views: [text, button])
            line.spacing = 16
            stack.addArrangedSubview(line)
        }
        if rows.isEmpty { panel.orderOut(nil) }
        else {
            panel.setContentSize(NSSize(width: 460, height: max(120, rows.count * 90 + 32)))
            panel.orderFront(nil)
        }
    }

    @objc private func cancelClicked(_ sender: NSButton) {
        if let text = sender.identifier?.rawValue, let id = UUID(uuidString: text) { cancel(id) }
    }
}
