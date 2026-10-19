import AppKit
import MediaViewerCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let store: SettingsStore

    private let autoplayCheckbox: NSButton
    private let loopCheckbox: NSButton

    private var hasShownOnce = false

    init(store: SettingsStore = SettingsStore(defaults: .standard)) {
        self.store = store

        let autoplayCheckbox = NSButton(
            checkboxWithTitle: "動画を自動再生する",
            target: nil,
            action: nil
        )
        let loopCheckbox = NSButton(
            checkboxWithTitle: "動画をループ再生する",
            target: nil,
            action: nil
        )
        self.autoplayCheckbox = autoplayCheckbox
        self.loopCheckbox = loopCheckbox

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "設定"
        window.isReleasedWhenClosed = false
        window.contentView = makeContentView()

        autoplayCheckbox.target = self
        autoplayCheckbox.action = #selector(toggleAutoplay(_:))
        loopCheckbox.target = self
        loopCheckbox.action = #selector(toggleLoop(_:))

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
            frame: NSRect(x: 0, y: 0, width: 400, height: 150)
        )

        let videoHeader = NSTextField(labelWithString: "動画")
        videoHeader.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let stack = NSStackView(views: [videoHeader, autoplayCheckbox, loopCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
        ])

        return contentView
    }

    private func syncFromStore() {
        let playback = store.playback
        autoplayCheckbox.state = playback.autoplay ? .on : .off
        loopCheckbox.state = playback.loop ? .on : .off
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
}
