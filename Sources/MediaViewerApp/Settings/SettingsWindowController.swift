import AppKit
import MediaViewerCore

/// システムのキーボードナビゲーションの設定にかかわらず Tab で止まる。
private final class KeyViewCheckbox: NSButton {
    override var canBecomeKeyView: Bool { true }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate, NSWindowDelegate {
    private let store: SettingsStore

    private let autoplayCheckbox: NSButton
    private let loopCheckbox: NSButton
    private let confirmFileOperationsCheckbox: NSButton
    private let intervalField = NSTextField(string: "3")
    private let repeatsCheckbox = KeyViewCheckbox(
        checkboxWithTitle: "最後まで表示したら先頭から繰り返す",
        target: nil,
        action: nil
    )

    private var hasShownOnce = false

    init(store: SettingsStore = SettingsStore(defaults: .standard)) {
        self.store = store

        let autoplayCheckbox = KeyViewCheckbox(
            checkboxWithTitle: "動画を自動再生する",
            target: nil,
            action: nil
        )
        let loopCheckbox = KeyViewCheckbox(
            checkboxWithTitle: "動画をループ再生する",
            target: nil,
            action: nil
        )
        let confirmFileOperationsCheckbox = KeyViewCheckbox(
            checkboxWithTitle: "コピー・ゴミ箱に入れる・お気に入りから削除する前に確認する（名前の変更・移動・ツリーのフォルダのゴミ箱は常に確認する）",
            target: nil,
            action: nil
        )
        self.autoplayCheckbox = autoplayCheckbox
        self.loopCheckbox = loopCheckbox
        self.confirmFileOperationsCheckbox = confirmFileOperationsCheckbox

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "設定"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = makeContentView()
        window.autorecalculatesKeyViewLoop = false
        autoplayCheckbox.nextKeyView = loopCheckbox
        loopCheckbox.nextKeyView = confirmFileOperationsCheckbox
        confirmFileOperationsCheckbox.nextKeyView = intervalField
        intervalField.nextKeyView = repeatsCheckbox
        repeatsCheckbox.nextKeyView = autoplayCheckbox
        window.initialFirstResponder = autoplayCheckbox

        autoplayCheckbox.target = self
        autoplayCheckbox.action = #selector(toggleAutoplay(_:))
        loopCheckbox.target = self
        loopCheckbox.action = #selector(toggleLoop(_:))
        confirmFileOperationsCheckbox.target = self
        confirmFileOperationsCheckbox.action = #selector(toggleConfirmFileOperations(_:))
        repeatsCheckbox.target = self
        repeatsCheckbox.action = #selector(toggleRepeats(_:))
        intervalField.delegate = self
        intervalField.setAccessibilityLabel("切り替え間隔（秒）")
        repeatsCheckbox.setAccessibilityLabel("最後まで表示したら先頭から繰り返す")

        syncFromStore()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        syncFromStore()
        if !hasShownOnce {
            hasShownOnce = true
            window?.center()
        }
        super.showWindow(sender)
    }

    private func makeContentView() -> NSView {
        let contentView = NSView(
            frame: NSRect(x: 0, y: 0, width: 620, height: 340)
        )

        let videoHeader = NSTextField(labelWithString: "動画")
        videoHeader.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let fileOperationsHeader = NSTextField(labelWithString: "ファイル操作")
        fileOperationsHeader.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let slideshowHeader = NSTextField(labelWithString: "スライドショー")
        slideshowHeader.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let intervalRow = NSStackView(views: [
            NSTextField(labelWithString: "切り替え間隔"),
            intervalField,
            NSTextField(labelWithString: "秒"),
        ])
        intervalRow.orientation = .horizontal
        intervalRow.alignment = .firstBaseline
        intervalRow.spacing = 8

        confirmFileOperationsCheckbox.cell?.wraps = true
        confirmFileOperationsCheckbox.cell?.isScrollable = false
        confirmFileOperationsCheckbox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [
            videoHeader,
            autoplayCheckbox,
            loopCheckbox,
            fileOperationsHeader,
            confirmFileOperationsCheckbox,
            slideshowHeader,
            intervalRow,
            repeatsCheckbox,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
            confirmFileOperationsCheckbox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            confirmFileOperationsCheckbox.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            intervalField.widthAnchor.constraint(equalToConstant: 80),
        ])

        return contentView
    }

    private func syncFromStore() {
        let playback = store.playback
        autoplayCheckbox.state = playback.autoplay ? .on : .off
        loopCheckbox.state = playback.loop ? .on : .off
        confirmFileOperationsCheckbox.state =
            store.confirmation.confirmBeforeFileOperations ? .on : .off
        let slideshow = store.slideshow
        intervalField.stringValue = String(slideshow.intervalSeconds)
        repeatsCheckbox.state = slideshow.repeats ? .on : .off
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === intervalField else { return }
        if let seconds = SlideshowIntervalInput.parse(intervalField.stringValue) {
            var options = store.slideshow
            options.intervalSeconds = seconds
            store.slideshow = options
        }
        intervalField.stringValue = String(store.slideshow.intervalSeconds)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === intervalField,
              commandSelector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        let saved = String(store.slideshow.intervalSeconds)
        intervalField.stringValue = saved
        textView.string = saved
        return true
    }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }

    @objc private func toggleRepeats(_ sender: NSButton) {
        var options = store.slideshow
        options.repeats = sender.state == .on
        store.slideshow = options
    }

    @objc private func toggleAutoplay(_ sender: NSButton) {
        var playback = store.playback
        playback.autoplay = sender.state == .on
        store.playback = playback
    }

    @objc private func toggleLoop(_ sender: NSButton) {
        var playback = store.playback
        playback.loop = sender.state == .on
        store.playback = playback
    }

    @objc private func toggleConfirmFileOperations(_ sender: NSButton) {
        var confirmation = store.confirmation
        confirmation.confirmBeforeFileOperations = sender.state == .on
        store.confirmation = confirmation
    }
}
