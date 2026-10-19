import AppKit
import MediaViewerCore

private final class NotificationTokens: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []
}

@MainActor
final class MainSplitViewController: NSSplitViewController {
    private let treeViewController: DirectoryTreeViewController
    private let fileListViewController: FileListViewController
    private let previewViewController: PreviewViewController
    private var appliedInitialPositions = false
    private var installedFocusMenu = false

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
        let thumbnailProvider = ThumbnailProvider()

        self.treeViewController = DirectoryTreeViewController(
            model: model,
            lister: lister,
            volumes: volumes
        )
        self.fileListViewController = FileListViewController(
            model: model,
            settings: settings,
            thumbnailProvider: thumbnailProvider
        )
        self.previewViewController = PreviewViewController(model: model, decoder: decoder)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        addSplitViewItem(makeItem(
            for: treeViewController,
            minimumThickness: 160,
            holdingPriority: 251
        ))
        addSplitViewItem(makeItem(
            for: fileListViewController,
            minimumThickness: 240,
            holdingPriority: 250
        ))
        addSplitViewItem(makeItem(
            for: previewViewController,
            minimumThickness: 320,
            holdingPriority: 249
        ))

        splitView.autosaveName = "MainSplit"
        fileListViewController.onTogglePlayback = { [weak self] in
            self?.previewViewController.togglePlayback()
        }
        installFocusMenuItems()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureKeyViewLoop()
        applyInitialPositionsIfNeeded()
    }

    private func makeItem(
        for viewController: NSViewController,
        minimumThickness: CGFloat,
        holdingPriority: Float
    ) -> NSSplitViewItem {
        let item = NSSplitViewItem(viewController: viewController)
        item.minimumThickness = minimumThickness
        item.canCollapse = false
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
