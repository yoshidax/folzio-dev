import AppKit
import MediaViewerCore

@MainActor
final class FileListViewController: NSViewController {
    private let model: BrowserModel
    private let settings: SettingsStore
    private let thumbnailProvider: any ThumbnailProviding
    private let listModeView: ListModeView
    private let thumbnailModeView: ThumbnailModeView
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let bottomBar = NSView()
    private let sizeSlider = NSSlider()

    private var bottomBarHeightConstraint: NSLayoutConstraint?
    private var displayMode: DisplayMode
    private let initialThumbnailSize: Double
    private var installedViewMenuItems = false
    private weak var thumbnailMenuItem: NSMenuItem?
    private weak var listMenuItem: NSMenuItem?

    init(
        model: BrowserModel,
        settings: SettingsStore,
        thumbnailProvider: any ThumbnailProviding
    ) {
        let viewSettings = settings.viewSettings
        self.model = model
        self.settings = settings
        self.thumbnailProvider = thumbnailProvider
        self.listModeView = ListModeView(model: model)
        self.thumbnailModeView = ThumbnailModeView(
            model: model,
            provider: thumbnailProvider
        )
        self.displayMode = viewSettings.displayMode
        self.initialThumbnailSize = ViewSettings.clampThumbnailSize(
            viewSettings.thumbnailSize
        )
        super.init(nibName: nil, bundle: nil)
        thumbnailModeView.thumbnailSize = initialThumbnailSize
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var primaryFocusView: NSView {
        displayMode == .thumbnails
            ? thumbnailModeView.focusView
            : listModeView.focusView
    }

    var onTogglePlayback: (() -> Void)? {
        get { listModeView.onTogglePlayback }
        set { listModeView.onTogglePlayback = newValue }
    }

    override func loadView() {
        let container = NSView()

        setupBottomBar()

        for modeView in [listModeView as NSView, thumbnailModeView as NSView] {
            modeView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(modeView)
            NSLayoutConstraint.activate([
                modeView.topAnchor.constraint(equalTo: container.topAnchor),
                modeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                modeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                modeView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            ])
        }

        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bottomBar)
        let bottomBarHeight = bottomBar.heightAnchor.constraint(equalToConstant: 0)
        bottomBarHeightConstraint = bottomBarHeight
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomBarHeight,
        ])

        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.alignment = .center
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.isHidden = true

        container.addSubview(progressIndicator)
        container.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            messageLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installViewMenuItems()
        refresh()
        observeModel()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installViewMenuItems()
    }

    private func setupBottomBar() {
        let label = NSTextField(labelWithString: "サイズ")
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor

        sizeSlider.minValue = ViewSettings.minimumThumbnailSize
        sizeSlider.maxValue = ViewSettings.maximumThumbnailSize
        sizeSlider.doubleValue = initialThumbnailSize
        sizeSlider.isContinuous = true
        sizeSlider.controlSize = .small
        sizeSlider.target = self
        sizeSlider.action = #selector(thumbnailSizeSliderChanged(_:))
        sizeSlider.translatesAutoresizingMaskIntoConstraints = false
        sizeSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let stack = NSStackView(views: [label, sizeSlider])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: bottomBar.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.listing.state
            _ = model.listing.files
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refresh()
                self?.observeModel()
            }
        }
    }

    private func refresh() {
        messageLabel.isHidden = true
        messageLabel.stringValue = ""
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true

        switch model.listing.state {
        case .loaded:
            break
        case .loading:
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
            messageLabel.stringValue = "読み込み中…"
            messageLabel.isHidden = false
        case .empty:
            messageLabel.stringValue = "対応するメディアファイルがありません"
            messageLabel.isHidden = false
        case .denied:
            messageLabel.stringValue = "アクセスできません"
            messageLabel.isHidden = false
        case let .failed(reason):
            messageLabel.stringValue = reason
            messageLabel.isHidden = false
        }

        updateModeVisibility()
    }

    private func updateModeVisibility() {
        var showsFiles = false
        if case .loaded = model.listing.state {
            showsFiles = true
        }

        listModeView.isHidden = !(showsFiles && displayMode == .list)
        let thumbnailWasHidden = thumbnailModeView.isHidden
        thumbnailModeView.isHidden = !(showsFiles && displayMode == .thumbnails)
        if thumbnailWasHidden, !thumbnailModeView.isHidden {
            thumbnailModeView.needsLayout = true
        }

        let showsThumbnailBar = displayMode == .thumbnails
        bottomBar.isHidden = !showsThumbnailBar
        bottomBarHeightConstraint?.constant = showsThumbnailBar ? 32 : 0
        updateViewMenuState()
    }

    private func installViewMenuItems() {
        guard !installedViewMenuItems else { return }
        guard let viewMenu = NSApp.mainMenu?.items
            .first(where: { $0.submenu?.title == "表示" })?
            .submenu else {
            return
        }
        installedViewMenuItems = true

        let thumbnailsItem = NSMenuItem(
            title: "サムネイル",
            action: #selector(showThumbnails(_:)),
            keyEquivalent: "1"
        )
        thumbnailsItem.target = self
        viewMenu.addItem(thumbnailsItem)
        thumbnailMenuItem = thumbnailsItem

        let listItem = NSMenuItem(
            title: "リスト",
            action: #selector(showList(_:)),
            keyEquivalent: "2"
        )
        listItem.target = self
        viewMenu.addItem(listItem)
        listMenuItem = listItem

        let zoomInItem = NSMenuItem(
            title: "サムネイルを拡大",
            action: #selector(increaseThumbnailSize(_:)),
            keyEquivalent: "+"
        )
        zoomInItem.target = self
        viewMenu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(
            title: "サムネイルを縮小",
            action: #selector(decreaseThumbnailSize(_:)),
            keyEquivalent: "-"
        )
        zoomOutItem.target = self
        viewMenu.addItem(zoomOutItem)

        updateViewMenuState()
    }

    private func updateViewMenuState() {
        thumbnailMenuItem?.state = displayMode == .thumbnails ? .on : .off
        listMenuItem?.state = displayMode == .list ? .on : .off
    }

    private func setDisplayMode(_ mode: DisplayMode) {
        guard mode != displayMode else {
            if mode == .thumbnails {
                thumbnailModeView.scrollToFocused()
            }
            return
        }

        let firstResponder = view.window?.firstResponder as? NSView
        let focusWasInFileList = firstResponder.map {
            isView($0, inside: listModeView) || isView($0, inside: thumbnailModeView)
        } ?? false

        displayMode = mode
        persistDisplayMode(mode)
        updateModeVisibility()

        if mode == .thumbnails {
            thumbnailModeView.scrollToFocused()
        }

        if focusWasInFileList {
            view.window?.makeFirstResponder(primaryFocusView)
        }
    }

    private func persistDisplayMode(_ mode: DisplayMode) {
        var viewSettings = settings.viewSettings
        guard viewSettings.displayMode != mode else { return }
        viewSettings.displayMode = mode
        settings.viewSettings = viewSettings
    }

    private func setThumbnailSize(_ value: Double, persist: Bool) {
        let clamped = ViewSettings.clampThumbnailSize(value)
        let previous = thumbnailModeView.thumbnailSize
        thumbnailModeView.thumbnailSize = clamped
        if abs(sizeSlider.doubleValue - clamped) > 0.01 {
            sizeSlider.doubleValue = clamped
        }
        guard persist, previous != clamped else { return }

        var viewSettings = settings.viewSettings
        viewSettings.thumbnailSize = clamped
        settings.viewSettings = viewSettings
    }

    private func isView(_ view: NSView, inside ancestor: NSView) -> Bool {
        var current: NSView? = view
        while let candidate = current {
            if candidate === ancestor {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    @objc private func showThumbnails(_ sender: Any?) {
        setDisplayMode(.thumbnails)
    }

    @objc private func showList(_ sender: Any?) {
        setDisplayMode(.list)
    }

    @objc private func increaseThumbnailSize(_ sender: Any?) {
        setThumbnailSize(thumbnailModeView.thumbnailSize + 16, persist: true)
    }

    @objc private func decreaseThumbnailSize(_ sender: Any?) {
        setThumbnailSize(thumbnailModeView.thumbnailSize - 16, persist: true)
    }

    @objc private func thumbnailSizeSliderChanged(_ sender: NSSlider) {
        setThumbnailSize(sender.doubleValue, persist: true)
    }
}
