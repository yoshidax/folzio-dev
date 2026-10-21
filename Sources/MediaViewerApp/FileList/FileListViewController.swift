import AppKit
import MediaViewerCore

@MainActor
final class FileListViewController: NSViewController {
    private let model: BrowserModel
    private let settings: SettingsStore
    private let thumbnailProvider: any ThumbnailProviding
    private let coordinator: FileOperationCoordinator
    private let listModeView: ListModeView
    private let thumbnailModeView: ThumbnailModeView
    private lazy var fileContextMenu = FileContextMenu(host: self)
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let bottomBar = NSView()
    /// 一覧を表示したまま出す、1行のメッセージの帯（R26）。一覧の下端、下部のサイズバーの上
    private let messageBand = NSView()
    private let messageBandLabel = NSTextField(labelWithString: "")
    private let sizeSlider = NSSlider()

    private var bottomBarHeightConstraint: NSLayoutConstraint?
    private var messageBandHeightConstraint: NSLayoutConstraint?
    private var displayMode: DisplayMode
    private let initialThumbnailSize: Double
    private var fullScreenNavigationLayout: FocusLayout?
    private var installedViewMenuItems = false
    private weak var thumbnailMenuItem: NSMenuItem?
    private weak var listMenuItem: NSMenuItem?
    private weak var imagesOnlyMenuItem: NSMenuItem?
    private weak var videosOnlyMenuItem: NSMenuItem?

    var onViewStateChange: ((DisplayMode, Double) -> Void)?
    var onMediaTypeFilterChange: ((MediaTypeFilter) -> Void)?

    var isToolbarShown = false {
        didSet {
            guard isToolbarShown != oldValue, isViewLoaded else { return }
            updateModeVisibility()
        }
    }

    var currentDisplayMode: DisplayMode {
        displayMode
    }

    var currentThumbnailSize: Double {
        thumbnailModeView.thumbnailSize
    }

    var currentMediaTypeFilter: MediaTypeFilter {
        model.mediaTypeFilter
    }

    init(
        model: BrowserModel,
        settings: SettingsStore,
        thumbnailProvider: any ThumbnailProviding,
        coordinator: FileOperationCoordinator
    ) {
        let viewSettings = settings.viewSettings
        self.model = model
        self.settings = settings
        self.thumbnailProvider = thumbnailProvider
        self.coordinator = coordinator
        self.listModeView = ListModeView(
            model: model,
            provider: thumbnailProvider
        )
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
        fileContextMenu.install(
            listModeView: listModeView,
            thumbnailModeView: thumbnailModeView
        )
        listModeView.onOpenItem = { [weak self] url in
            self?.openItem(url)
        }
        thumbnailModeView.onOpenItem = { [weak self] url in
            self?.openItem(url)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 一覧を隠したことで AppKit がフォーカスを移した先（次のキービュー。プレビューなど）。
    /// 一覧を出し直したとき、フォーカスがまだここにあればファイルリストへ戻す
    private weak var displacedFocus: NSResponder?

    var primaryFocusView: NSView {
        displayMode == .thumbnails
            ? thumbnailModeView.focusView
            : listModeView.focusView
    }

    var onTogglePlayback: (() -> Void)? {
        get { listModeView.onTogglePlayback }
        set { listModeView.onTogglePlayback = newValue }
    }

    var onRename: ((URL, String) async -> Void)? {
        get { listModeView.onRename }
        set {
            listModeView.onRename = newValue
            thumbnailModeView.onRename = newValue
        }
    }

    func beginFullScreenNavigation() {
        guard fullScreenNavigationLayout == nil else { return }
        fullScreenNavigationLayout = displayMode == .thumbnails
            ? .grid(columns: thumbnailModeView.currentColumnCount)
            : .list
    }

    @discardableResult
    func moveFocusInFullScreen(_ move: FocusMove) -> Bool {
        guard let layout = fullScreenNavigationLayout else { return false }
        let files = model.listing.files
        guard !files.isEmpty else { return true }

        let currentIndex = model.selection.focused.flatMap { focused in
            files.firstIndex { $0.url == focused }
        }
        guard let target = FocusNavigator.targetIndex(
            currentIndex: currentIndex,
            fileCount: files.count,
            move: move,
            layout: layout,
            isNavigable: { files[$0].kind.isMedia }
        ) else {
            return true
        }

        let url = files[target].url
        model.select([url], focused: url)
        return true
    }

    func endFullScreenNavigation() {
        guard let layout = fullScreenNavigationLayout else { return }
        fullScreenNavigationLayout = nil

        guard case .grid = layout else { return }
        DispatchQueue.main.async { [weak self] in
            self?.thumbnailModeView.scrollToFocused()
        }
    }

    /// ファイル操作の対象。一覧の並び順で、`..` の行を除く（R30）
    var selectedFileURLs: [URL] {
        model.operableSelection
    }

    /// フォーカス行と表示中の場所から決まる、操作ごとの可否
    var focusedItemCommands: ListItemCommands {
        model.focusedItemCommands
    }

    /// 選択に対するファイル操作の可否（フォーカスが `..` でも、ほかの選択の行で判断する）
    var selectionItemCommands: ListItemCommands {
        model.selectionItemCommands
    }

    var isEditingText: Bool {
        view.window?.firstResponder is NSTextView
    }

    override func loadView() {
        let container = NSView()

        setupBottomBar()

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

        setupMessageBand()
        messageBand.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(messageBand)
        let messageBandHeight = messageBand.heightAnchor.constraint(equalToConstant: 0)
        messageBandHeightConstraint = messageBandHeight
        NSLayoutConstraint.activate([
            messageBand.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            messageBand.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            messageBand.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            messageBandHeight,
        ])

        for modeView in [listModeView as NSView, thumbnailModeView as NSView] {
            modeView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(modeView)
            NSLayoutConstraint.activate([
                modeView.topAnchor.constraint(equalTo: container.topAnchor),
                modeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                modeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                modeView.bottomAnchor.constraint(equalTo: messageBand.topAnchor),
            ])
        }

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
        observeMediaTypeFilter()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installViewMenuItems()
    }

    private func setupMessageBand() {
        messageBand.isHidden = true
        messageBand.clipsToBounds = true

        messageBandLabel.translatesAutoresizingMaskIntoConstraints = false
        messageBandLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        messageBandLabel.textColor = .secondaryLabelColor
        messageBandLabel.alignment = .center
        messageBandLabel.lineBreakMode = .byTruncatingTail
        // ラベルの既定（hugging 251・圧縮抵抗 750）は NSSplitViewItem の holdingPriority（250）を上回り、
        // ペイン幅をラベルの幅へ引き戻してしまう。帯の幅はペインに従わせ、長い文言は省略する
        messageBandLabel.setContentHuggingPriority(.init(1), for: .horizontal)
        messageBandLabel.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        messageBand.addSubview(messageBandLabel)
        NSLayoutConstraint.activate([
            messageBandLabel.leadingAnchor.constraint(equalTo: messageBand.leadingAnchor, constant: 12),
            messageBandLabel.trailingAnchor.constraint(equalTo: messageBand.trailingAnchor, constant: -12),
            messageBandLabel.centerYAnchor.constraint(equalTo: messageBand.centerYAnchor),
        ])
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

    private func observeMediaTypeFilter() {
        withObservationTracking {
            _ = model.mediaTypeFilter
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateViewMenuState()
                self.onMediaTypeFilterChange?(self.model.mediaTypeFilter)
                self.refresh()
                self.observeMediaTypeFilter()
            }
        }
    }

    /// 一覧の行が残っているとき（`..` やディレクトリ）は、メッセージの状態でも一覧を表示し続ける。
    /// 読めないフォルダでも `..` が残れば一覧を出し、メッセージは下端の帯に出す（FR-077）
    private var showsFileList: Bool {
        switch model.listing.state {
        case .loaded:
            return true
        case .empty, .noMatches, .denied, .failed:
            return !model.listing.files.isEmpty
        case .loading:
            return false
        }
    }

    private func refresh() {
        messageLabel.isHidden = true
        messageLabel.stringValue = ""
        messageBandLabel.stringValue = ""
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true

        var message: String?
        switch model.listing.state {
        case .loaded:
            break
        case .loading:
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
            message = "読み込み中…"
        case .empty:
            message = "対応するメディアファイルがありません"
        case .noMatches:
            message = model.mediaTypeFilter.noMatchesMessage ?? ""
        case .denied:
            message = "アクセスできません"
        case let .failed(reason):
            message = reason
        }

        if let message {
            if showsFileList {
                messageBandLabel.stringValue = message
            } else {
                messageLabel.stringValue = message
                messageLabel.isHidden = false
            }
        }

        updateModeVisibility()
    }

    private func updateModeVisibility() {
        let showsFiles = showsFileList
        let firstResponder = view.window?.firstResponder as? NSView
        let focusWasInFileList = firstResponder.map {
            isView($0, inside: listModeView) || isView($0, inside: thumbnailModeView)
        } ?? false

        listModeView.isHidden = !(showsFiles && displayMode == .list)
        let thumbnailWasHidden = thumbnailModeView.isHidden
        thumbnailModeView.isHidden = !(showsFiles && displayMode == .thumbnails)
        if thumbnailWasHidden, !thumbnailModeView.isHidden {
            thumbnailModeView.needsLayout = true
        }

        // 読み込み中は一覧を隠すため、AppKit がフォーカスを次のキービュー（プレビューなど）へ移す。
        // フォルダへ入る・戻る間もキーボードフォーカスをファイルリストに残すよう、一覧を出し直したときに戻す（FR-078）
        if focusWasInFileList, !showsFiles, let window = view.window {
            displacedFocus = window.firstResponder
        }
        if showsFiles, let displaced = displacedFocus {
            displacedFocus = nil
            // 読み込み中にユーザーがほかのペインへ移ったときは、フォーカスを奪わない
            if let window = view.window, window.firstResponder === displaced {
                window.makeFirstResponder(primaryFocusView)
            }
        }

        let showsBand = showsFiles && !messageBandLabel.stringValue.isEmpty
        messageBand.isHidden = !showsBand
        messageBandHeightConstraint?.constant = showsBand ? 24 : 0

        let showsThumbnailBar = FileListChrome(
            displayMode: displayMode,
            toolbarShown: isToolbarShown
        ).showsBottomSizeBar
        bottomBar.isHidden = !showsThumbnailBar
        bottomBarHeightConstraint?.constant = showsThumbnailBar ? 32 : 0
        updateViewMenuState()
        onViewStateChange?(displayMode, thumbnailModeView.thumbnailSize)
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

        viewMenu.addItem(.separator())

        let imagesOnlyItem = NSMenuItem(
            title: "画像のみ表示",
            action: #selector(toggleImagesOnly(_:)),
            keyEquivalent: "I"
        )
        imagesOnlyItem.target = self
        viewMenu.addItem(imagesOnlyItem)
        imagesOnlyMenuItem = imagesOnlyItem

        let videosOnlyItem = NSMenuItem(
            title: "動画のみ表示",
            action: #selector(toggleVideosOnly(_:)),
            keyEquivalent: "M"
        )
        videosOnlyItem.target = self
        viewMenu.addItem(videosOnlyItem)
        videosOnlyMenuItem = videosOnlyItem

        updateViewMenuState()
    }

    private func updateViewMenuState() {
        thumbnailMenuItem?.state = displayMode == .thumbnails ? .on : .off
        listMenuItem?.state = displayMode == .list ? .on : .off
        imagesOnlyMenuItem?.state = model.mediaTypeFilter.imagesOnly ? .on : .off
        videosOnlyMenuItem?.state = model.mediaTypeFilter.videosOnly ? .on : .off
    }

    func applyMediaTypeFilter(_ filter: MediaTypeFilter) {
        guard !isEditingText else {
            onMediaTypeFilterChange?(model.mediaTypeFilter)
            return
        }
        model.setMediaTypeFilter(filter)
    }

    func selectDisplayMode(_ mode: DisplayMode) {
        setDisplayMode(mode)
    }

    func applyThumbnailSize(_ value: Double) {
        setThumbnailSize(value, persist: true)
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
        onViewStateChange?(displayMode, clamped)
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

    @objc func copy(_ sender: Any?) {
        guard selectionItemCommands.allowsFileOperations else { return }
        let urls = selectedFileURLs
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    @objc func paste(_ sender: Any?) {
        guard focusedItemCommands.allowsPaste else { return }
        guard !isEditingText else { return }
        let folder = model.listing.folder
        Task { @MainActor in
            await coordinator.paste(into: folder, move: false)
        }
    }

    @objc func movePaste(_ sender: Any?) {
        guard focusedItemCommands.allowsPaste else { return }
        guard !isEditingText else { return }
        let folder = model.listing.folder
        Task { @MainActor in
            await coordinator.paste(into: folder, move: true)
        }
    }

    @objc func duplicate(_ sender: Any?) {
        guard selectionItemCommands.allowsFileOperations else { return }
        guard !isEditingText else { return }
        let urls = selectedFileURLs
        guard !urls.isEmpty else { return }
        Task { @MainActor in
            await coordinator.duplicate(urls)
        }
    }

    @objc func rename(_ sender: Any?) {
        guard focusedItemCommands.allowsFileOperations else { return }
        guard !isEditingText else { return }
        let selected = model.selection.selected
        guard selected.count == 1,
              let focused = model.selection.focused,
              selected.contains(focused) else {
            return
        }

        switch displayMode {
        case .list:
            _ = listModeView.beginRenaming()
        case .thumbnails:
            guard let window = view.window else { return }
            window.makeFirstResponder(thumbnailModeView.focusView)
            guard let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: 36
            ) else {
                return
            }
            thumbnailModeView.focusView.keyDown(with: event)
        }
    }

    @objc func moveToTrash(_ sender: Any?) {
        guard selectionItemCommands.allowsFileOperations else { return }
        guard !isEditingText else { return }
        let urls = selectedFileURLs
        guard !urls.isEmpty else { return }
        Task { @MainActor in
            await coordinator.trash(urls)
        }
    }

    @objc func open(_ sender: Any?) {
        guard selectionItemCommands.allowsFileOperations else { return }
        guard !isEditingText else { return }
        for url in selectedFileURLs {
            _ = NSWorkspace.shared.open(url)
        }
    }

    @objc func revealInFinder(_ sender: Any?) {
        guard selectionItemCommands.allowsFileOperations else { return }
        let urls = selectedFileURLs
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// フォーカス行の zip ファイル・ディレクトリの中を表示する。`..` なら1つ上へ戻る（⌘↓、FR-069）
    @objc func openFocusedItem(_ sender: Any?) {
        guard !isEditingText,
              focusedItemCommands.canOpenContainer,
              let focused = model.selection.focused else {
            return
        }
        openItem(focused)
    }

    /// ダブルクリックと ⌘↓ から呼ぶ。メディアの行では何もしない（Core が判断する）
    func openItem(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.model.openItem(url)
            await self.scrollFocusedItemIntoViewAfterModelUpdate()
        }
    }

    /// zip の中なら1つ上の階層へ戻る。最上位なら zip を含むフォルダの一覧へ戻る（⌘↑、FR-070）
    @objc func goToEnclosingLevel(_ sender: Any?) {
        guard !isEditingText, focusedItemCommands.canGoUp else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.model.goToEnclosingLevel()
            await self.scrollFocusedItemIntoViewAfterModelUpdate()
        }
    }

    /// 一覧への反映（Observation の通知で動く Task）が済んでから、フォーカス行を見える位置へスクロールする
    private func scrollFocusedItemIntoViewAfterModelUpdate() async {
        await Task.yield()
        switch displayMode {
        case .list:
            listModeView.scrollToFocused()
        case .thumbnails:
            thumbnailModeView.scrollToFocused()
        }
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

    @objc private func toggleImagesOnly(_ sender: Any?) {
        var filter = model.mediaTypeFilter
        filter.imagesOnly.toggle()
        applyMediaTypeFilter(filter)
    }

    @objc private func toggleVideosOnly(_ sender: Any?) {
        var filter = model.mediaTypeFilter
        filter.videosOnly.toggle()
        applyMediaTypeFilter(filter)
    }

    @objc private func thumbnailSizeSliderChanged(_ sender: NSSlider) {
        setThumbnailSize(sender.doubleValue, persist: true)
    }
}

extension FileListViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleImagesOnly(_:))
            || menuItem.action == #selector(toggleVideosOnly(_:)) {
            return !isEditingText
        }

        if menuItem.action == #selector(openFocusedItem(_:)) {
            return !isEditingText && focusedItemCommands.canOpenContainer
        }
        if menuItem.action == #selector(goToEnclosingLevel(_:)) {
            return !isEditingText && focusedItemCommands.canGoUp
        }

        // zip の中は読み取り専用（FR-073）。`..` は操作の対象にならない（R30）。判断は ListItemCommands に任せる
        let commands = selectionItemCommands
        switch menuItem.action {
        case #selector(copy(_:)),
             #selector(open(_:)),
             #selector(revealInFinder(_:)),
             #selector(moveToTrash(_:)),
             #selector(duplicate(_:)):
            if !commands.allowsFileOperations { return false }
        case #selector(rename(_:)):
            if !focusedItemCommands.allowsFileOperations { return false }
        case #selector(paste(_:)), #selector(movePaste(_:)):
            if !commands.allowsPaste { return false }
        default:
            break
        }

        if isEditingText {
            switch menuItem.action {
            case #selector(open(_:)),
                 #selector(moveToTrash(_:)),
                 #selector(rename(_:)),
                 #selector(duplicate(_:)),
                 #selector(revealInFinder(_:)):
                return false
            default:
                break
            }
        }

        switch menuItem.action {
        case #selector(copy(_:)),
             #selector(open(_:)),
             #selector(revealInFinder(_:)),
             #selector(moveToTrash(_:)),
             #selector(duplicate(_:)):
            return !selectedFileURLs.isEmpty
        case #selector(rename(_:)):
            return model.selection.selected.count == 1
                && model.selection.focused != nil
        case #selector(paste(_:)), #selector(movePaste(_:)):
            return FileContextMenu.pasteboardHasFileURLs()
        default:
            return true
        }
    }
}
