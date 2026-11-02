import AppKit
import FolzioCore
import FolzioLocalization

/// A button that captures the next key press while it is recording (FR-258).
///
/// The window offers a key press to its view hierarchy before the main menu, so returning true from
/// `performKeyEquivalent` keeps the menu from running the command that already uses the key (EC-178).
final class ShortcutRecordButton: NSButton {
    var isRecording = false
    var onCapture: ((KeyCombination) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        return handle(event)
    }

    override func keyDown(with event: NSEvent) {
        if isRecording {
            _ = handle(event)
        } else {
            super.keyDown(with: event)
        }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { onCancel?() }
        return super.resignFirstResponder()
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let modifiers = MenuShortcutApplier.modifiers(from: event.modifierFlags)
        // Esc without modifiers cancels. It is never a candidate.
        if event.keyCode == 53, modifiers.isEmpty {
            onCancel?()
            return true
        }
        if event.isARepeat { return true }
        // Keys without a menu key equivalent (function keys, dead keys) are ignored while recording continues.
        guard let characters = event.charactersIgnoringModifiers,
              let combination = KeyCombination.normalized(key: characters, modifiers: modifiers) else {
            return true
        }
        onCapture?(combination)
        return true
    }
}

private final class ShortcutResetButton: NSButton {
    override var canBecomeKeyView: Bool { true }
}

/// One command's row in the Shortcuts tab: its name, current key, state, and the Record and Reset buttons.
@MainActor
final class ShortcutRecorderRow: NSView {
    let command: ShortcutCommandID
    let recordButton = ShortcutRecordButton()
    let resetButton: NSButton = ShortcutResetButton()

    private let nameLabel = NSTextField(labelWithString: "")
    private let keyLabel = NSTextField(labelWithString: "")
    private let changedLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private var keyText = ""
    private var isChanged = false
    private(set) var isRecording = false

    var onRecordTapped: ((ShortcutCommandID) -> Void)?
    var onResetTapped: ((ShortcutCommandID) -> Void)?

    init(command: ShortcutCommandID) {
        self.command = command
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        keyLabel.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        keyLabel.alignment = .left
        changedLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        changedLabel.textColor = .secondaryLabelColor
        changedLabel.setAccessibilityElement(false)

        for button in [recordButton, resetButton] {
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            button.target = self
        }
        recordButton.action = #selector(recordTapped(_:))
        resetButton.action = #selector(resetTapped(_:))

        errorLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true
        errorLabel.setAccessibilityElement(false)

        let line = NSStackView(views: [nameLabel, keyLabel, changedLabel, recordButton, resetButton])
        line.orientation = .horizontal
        line.alignment = .firstBaseline
        line.spacing = 8
        let column = NSStackView(views: [line, errorLabel])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 2
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            line.widthAnchor.constraint(equalTo: column.widthAnchor),
            errorLabel.widthAnchor.constraint(equalTo: column.widthAnchor),
            nameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            keyLabel.widthAnchor.constraint(equalToConstant: 120),
            changedLabel.widthAnchor.constraint(equalToConstant: 64),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the command name, its current key, and whether it differs from the default.
    func update(name: String, keyText: String, isChanged: Bool, canReset: Bool) {
        self.keyText = keyText
        self.isChanged = isChanged
        nameLabel.stringValue = name
        changedLabel.stringValue = isChanged ? l10n.text(.settingsShortcutsChanged) : ""
        recordButton.title = l10n.text(.settingsShortcutsRecord)
        resetButton.title = l10n.text(.settingsShortcutsReset)
        resetButton.isEnabled = canReset && !isRecording
        recordButton.setAccessibilityLabel(l10n.text(.settingsShortcutsRecordFor, .text(name)))
        resetButton.setAccessibilityLabel(l10n.text(.settingsShortcutsResetFor, .text(name)))
        renderKey(name: name)
    }

    private func renderKey(name: String) {
        keyLabel.stringValue = isRecording ? l10n.text(.settingsShortcutsRecording) : keyText
        // Read the name, the key, and the state as one unit; the state is not conveyed by color alone (FR-265).
        let state = isChanged ? l10n.text(.settingsShortcutsChanged) : ""
        keyLabel.setAccessibilityLabel([name, state].filter { !$0.isEmpty }.joined(separator: ", "))
        keyLabel.setAccessibilityValue(keyLabel.stringValue)
    }

    func beginRecording() {
        isRecording = true
        recordButton.isRecording = true
        resetButton.isEnabled = false
        showError(nil)
        renderKey(name: nameLabel.stringValue)
    }

    func endRecording() {
        isRecording = false
        recordButton.isRecording = false
        showError(nil)
        renderKey(name: nameLabel.stringValue)
    }

    /// Enables or disables the Record button, so that only one row records at a time.
    func setRecordEnabled(_ enabled: Bool) {
        recordButton.isEnabled = enabled
    }

    /// Shows the reason a key was refused, and announces it, or hides it when `message` is nil.
    func showError(_ message: String?) {
        guard let message else {
            errorLabel.isHidden = true
            errorLabel.stringValue = ""
            return
        }
        errorLabel.stringValue = "⚠︎ " + message
        errorLabel.isHidden = false
        let element: Any
        if let window { element = window } else { element = self }
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: nameLabel.stringValue + ". " + message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    @objc private func recordTapped(_ sender: Any?) {
        onRecordTapped?(command)
    }

    @objc private func resetTapped(_ sender: Any?) {
        onResetTapped?(command)
    }
}
