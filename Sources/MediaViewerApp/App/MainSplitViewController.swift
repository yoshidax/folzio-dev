import AppKit
import MediaViewerCore
import Observation

private final class NotificationTokens: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []
}

@MainActor
final class MainSplitViewController: NSSplitViewController {
    private let model: BrowserModel
    private let treeViewController: DirectoryTreeViewController
    private let fileListViewController: FileListViewController
    private let previewViewController: PreviewViewController
    private let fileOperationCoordinator: FileOperationCoordinator
    private var didObserveInitialListingChange = false
    private var didNotifyInitialListingDisplayed = false
    private var appliedInitialPositions = false
    private var installedFocusMenu = false
    private var treeSplitItem: NSSplitViewItem?
    private var fileListSplitItem: NSSplitViewItem?
    private var panesCollapsedForFullScreen = false
    private var isAppInitiatedFullScreenTransition = false

    var onInitialListingDisplayed: (() -> Void)? {
        didSet {
            deliverInitialListingIfReady()
        }
    }

    init() {
        let settings = SettingsStore(defaults: .standard)
        let lister = DirectoryLister()
        let decoder = ImageDecoder()
        let cache = DecodedImageCache()
        let model = BrowserModel(
            lister: lister,
            decoder: decoder,
            cache: cache,
            settings: settings
        )
        let volumes = VolumeProvider(changes: MainSplitViewController.makeVolumeChanges())
        let fileSystemWatcher = FileSystemWatcher()
        let thumbnailProvider = ThumbnailProvider()
        let coordinator = FileOperationCoordinator(
            model: model,
            service: FileOperationService(),
            settings: settings
        )
        self.fileOperationCoordinator = coordinator
        self.model = model

        self.treeViewController = DirectoryTreeViewController(
            model: model,
            lister: lister,
            volumes: volumes,
            coordinator: coordinator,
            watcher: fileSystemWatcher
        )
        self.fileListViewController = FileListViewController(
            model: model,
            settings: settings,
            thumbnailProvider: thumbnailProvider,
            coordinator: coordinator
        )
        self.previewViewController = PreviewViewController(model: model, decoder: decoder)

        super.init(nibName: nil, bundle: nil)

        fileListViewController.onRename = { [weak self] url, newName in
            guard let self else { return }
            await self.fileOperationCoordinator.rename(url, to: newName)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let treeItem = makeItem(
            for: treeViewController,
            minimumThickness: 160,
            holdingPriority: 251
        )
        treeSplitItem = treeItem
        addSplitViewItem(treeItem)

        let fileListItem = makeItem(
            for: fileListViewController,
            minimumThickness: 240,
            holdingPriority: 250
        )
        fileListSplitItem = fileListItem
        addSplitViewItem(fileListItem)

        addSplitViewItem(makeItem(
            for: previewViewController,
            minimumThickness: 320,
            holdingPriority: 249
        ))

        splitView.autosaveName = "MainSplit"
        fileListViewController.onTogglePlayback = { [weak self] in
            self?.previewViewController.togglePlayback()
        }
        previewViewController.onDoubleClick = { [weak self] in
            self?.togglePreviewFullScreen()
        }
        installFocusMenuItems()
        observeInitialListingState()
    }

    private func observeInitialListingState() {
        withObservationTracking {
            _ = model.listing.state
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.handleInitialListingStateChange()
            }
        }
    }

    private func handleInitialListingStateChange() {
        didObserveInitialListingChange = true
        deliverInitialListingIfReady()
        if !didNotifyInitialListingDisplayed {
            observeInitialListingState()
        }
    }

    private func deliverInitialListingIfReady() {
        guard didObserveInitialListingChange, !didNotifyInitialListingDisplayed else { return }

        switch model.listing.state {
        case .loading:
            return
        case .loaded, .empty, .denied, .failed:
            break
        }

        guard let onInitialListingDisplayed else { return }
        didNotifyInitialListingDisplayed = true
        onInitialListingDisplayed()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window, window.delegate == nil {
            window.delegate = self
        }
        configureKeyViewLoop()
        applyInitialPositionsIfNeeded()
    }

    @objc func togglePreviewFullScreen() {
        guard let window = view.window else { return }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
            return
        }

        collapsePanesForFullScreen()
        isAppInitiatedFullScreenTransition = true
        window.toggleFullScreen(nil)
    }

    func exitPreviewFullScreenIfNeeded() {
        guard let window = view.window else { return }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        } else {
            restorePanesAfterFullScreen()
        }
    }

    private func collapsePanesForFullScreen() {
        guard !panesCollapsedForFullScreen else { return }
        panesCollapsedForFullScreen = true
        treeSplitItem?.canCollapse = true
        fileListSplitItem?.canCollapse = true
        treeSplitItem?.isCollapsed = true
        fileListSplitItem?.isCollapsed = true
    }

    private func restorePanesAfterFullScreen() {
        guard panesCollapsedForFullScreen else { return }
        panesCollapsedForFullScreen = false
        treeSplitItem?.isCollapsed = false
        fileListSplitItem?.isCollapsed = false
        treeSplitItem?.canCollapse = false
        fileListSplitItem?.canCollapse = false
    }

    private func makeItem(
        for viewController: NSViewController,
        minimumThickness: CGFloat,
        holdingPriority: Float,
        canCollapse: Bool = false
    ) -> NSSplitViewItem {
        let item = NSSplitViewItem(viewController: viewController)
        item.minimumThickness = minimumThickness
        item.canCollapse = canCollapse
        item.holdingPriority = NSLayoutConstraint.Priority(holdingPriority)
        return item
    }

    private func applyInitialPositionsIfNeeded() {
        guard !appliedInitialPositions else { return }
        appliedInitialPositions = true

        let autosaveKey = "NSSplitView Subview Frames MainSplit"
        guard UserDefaults.standard.object(forKey: autosaveKey) == nil else { return }

        splitView.setPosition(220, ofDividerAt: 0)
        let secondDivider = 220 + splitView.dividerThickness + 360
        splitView.setPosition(secondDivider, ofDividerAt: 1)
    }

    private func configureKeyViewLoop() {
        let tree = treeViewController.primaryFocusView
        let list = fileListViewController.primaryFocusView
        let preview = previewViewController.primaryFocusView

        tree.nextKeyView = list
        list.nextKeyView = preview
        preview.nextKeyView = tree

        view.window?.initialFirstResponder = tree
    }

    private func installFocusMenuItems() {
        guard !installedFocusMenu else { return }
        guard let viewMenu = NSApp.mainMenu?.items
            .first(where: { $0.submenu?.title == "表示" })?
            .submenu else {
            return
        }
        installedFocusMenu = true

        viewMenu.addItem(.separator())
        addFocusItem(
            to: viewMenu,
            title: "ディレクトリツリーへフォーカス",
            keyEquivalent: "1",
            action: #selector(focusTreePane(_:))
        )
        addFocusItem(
            to: viewMenu,
            title: "ファイルリストへフォーカス",
            keyEquivalent: "2",
            action: #selector(focusFileListPane(_:))
        )
        addFocusItem(
            to: viewMenu,
            title: "プレビューへフォーカス",
            keyEquivalent: "3",
            action: #selector(focusPreviewPane(_:))
        )
    }

    private func addFocusItem(
        to menu: NSMenu,
        title: String,
        keyEquivalent: String,
        action: Selector
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = [.command, .option]
        item.target = self
        menu.addItem(item)
    }

    @objc private func focusTreePane(_ sender: Any?) {
        focusPane(treeViewController.primaryFocusView)
    }

    @objc private func focusFileListPane(_ sender: Any?) {
        focusPane(fileListViewController.primaryFocusView)
    }

    @objc private func focusPreviewPane(_ sender: Any?) {
        focusPane(previewViewController.primaryFocusView)
    }

    private func focusPane(_ view: NSView) {
        view.window?.makeFirstResponder(view)
    }

    private static func makeVolumeChanges() -> AsyncStream<[FolderNode]> {
        AsyncStream { continuation in
            let tokens = NotificationTokens()
            let center = NSWorkspace.shared.notificationCenter

            for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
                let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
                    continuation.yield(VolumeProvider.computeRootNodes())
                }
                tokens.tokens.append(token)
            }

            continuation.onTermination = { _ in
                for token in tokens.tokens {
                    center.removeObserver(token)
                }
            }
        }
    }
}

extension MainSplitViewController: NSWindowDelegate {
    func windowWillEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === view.window else { return }

        if isAppInitiatedFullScreenTransition {
            isAppInitiatedFullScreenTransition = false
        } else {
            collapsePanesForFullScreen()
        }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === view.window else { return }

        isAppInitiatedFullScreenTransition = false
        restorePanesAfterFullScreen()
    }
}
