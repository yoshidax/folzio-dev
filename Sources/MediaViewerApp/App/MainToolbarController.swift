import AppKit
import MediaViewerCore
import Observation

@MainActor
final class MainToolbarController: NSObject {
    private static let historyIdentifier = NSToolbarItem.Identifier("history")
    private static let paneLayoutIdentifier = NSToolbarItem.Identifier("paneLayout")
    private static let slideshowIdentifier = NSToolbarItem.Identifier("slideshow")
    private static let mediaTypeFilterIdentifier = NSToolbarItem.Identifier("mediaTypeFilter")
    private static let zipVisibilityIdentifier = NSToolbarItem.Identifier("zipVisibility")
    private static let viewModeIdentifier = NSToolbarItem.Identifier("viewMode")
    private static let thumbnailSizeIdentifier = NSToolbarItem.Identifier("thumbnailSize")

    let toolbar = NSToolbar(identifier: "MainToolbar")

    private let fileList: FileListViewController
    private let panes: MainSplitViewController
    private let settings: SettingsStore
    private let sizeSlider = NSSlider()
    private var historyControl: NSSegmentedControl?
    private var paneLayoutControl: NSSegmentedControl?
    private var mediaTypeFilterControl: NSSegmentedControl?
    private var zipVisibilityControl: NSSegmentedControl?
    private var viewModeControl: NSSegmentedControl?
    private var sizeItem: NSToolbarItem?
    private var slideshowButton: NSButton?
    private var visibilityObservation: NSKeyValueObservation?
    private var editingObservers: [NSObjectProtocol] = []

    init(fileList: FileListViewController, panes: MainSplitViewController, settings: SettingsStore) {
        self.fileList = fileList
        self.panes = panes
        self.settings = settings
        super.init()

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.allowsDisplayModeCustomization = false
        toolbar.autosavesConfiguration = false

        sizeSlider.minValue = ViewSettings.minimumThumbnailSize
        sizeSlider.maxValue = ViewSettings.maximumThumbnailSize
        sizeSlider.isContinuous = true
        sizeSlider.controlSize = .small
        sizeSlider.target = self
        sizeSlider.action = #selector(thumbnailSizeChanged(_:))
        sizeSlider.toolTip = "サムネイルのサイズ"
        sizeSlider.setAccessibilityLabel("サムネイルのサイズ")
        sizeSlider.translatesAutoresizingMaskIntoConstraints = false
        sizeSlider.widthAnchor.constraint(equalToConstant: 120).isActive = true

        fileList.onViewStateChange = { [weak self] mode, size in
            self?.apply(displayMode: mode, thumbnailSize: size)
        }

        fileList.onMediaTypeFilterChange = { [weak self] filter in
            self?.apply(mediaTypeFilter: filter)
        }

        fileList.onShowsZipFilesChange = { [weak self] shows in
            self?.apply(showsZipFiles: shows)
        }

        visibilityObservation = toolbar.observe(\.isVisible, options: [.new]) { [weak self] toolbar, _ in
            let isVisible = toolbar.isVisible
            MainActor.assumeIsolated {
                self?.toolbarVisibilityChanged(isVisible)
            }
        }

        panes.onPaneLayoutChange = { [weak self] layout in
            self?.apply(paneLayout: layout)
        }
        panes.onSlideshowAvailabilityChange = { [weak self] in
            self?.updateSlideshowAvailability()
        }
        observeEditingAvailability()
        observeHistoryAvailability()
    }

    private func updateSlideshowAvailability() {
        slideshowButton?.isEnabled = panes.canStartSlideshow
        applyHistoryAvailability()
        toolbar.validateVisibleItems()
    }

    private func observeEditingAvailability() {
        for name in [NSControl.textDidBeginEditingNotification, NSControl.textDidEndEditingNotification] {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.updateSlideshowAvailability()
                    }
                }
            }
            editingObservers.append(token)
        }
    }

    /// 戻る・進むを、履歴とペインの状態から有効・無効にする（FR-112）
    func applyHistoryAvailability() {
        let canNavigate = panes.paneCommands.canNavigateHistory
        historyControl?.setEnabled(canNavigate && panes.historyNavigator.canGoBack, forSegment: 0)
        historyControl?.setEnabled(canNavigate && panes.historyNavigator.canGoForward, forSegment: 1)
    }

    private func observeHistoryAvailability() {
        withObservationTracking {
            _ = panes.historyNavigator.canGoBack
            _ = panes.historyNavigator.canGoForward
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyHistoryAvailability()
                self.observeHistoryAvailability()
            }
        }
    }

    func apply(paneLayout: PaneLayout) {
        paneLayoutControl?.setSelected(paneLayout.soloPane == .fileList, forSegment: 0)
        paneLayoutControl?.setSelected(paneLayout.soloPane == .preview, forSegment: 1)
        paneLayoutControl?.isEnabled = panes.paneCommands.canChangeLayout
        applyHistoryAvailability()
    }

    func apply(displayMode: DisplayMode, thumbnailSize: Double) {
        viewModeControl?.selectedSegment = displayMode == .thumbnails ? 0 : 1
        if abs(sizeSlider.doubleValue - thumbnailSize) > 0.01 {
            sizeSlider.doubleValue = thumbnailSize
        }

        let sliderEnabled = FileListChrome(
            displayMode: displayMode,
            toolbarShown: toolbar.isVisible
        ).toolbarSliderEnabled
        sizeSlider.isEnabled = sliderEnabled
        sizeItem?.isEnabled = sliderEnabled
    }

    func apply(mediaTypeFilter: MediaTypeFilter) {
        mediaTypeFilterControl?.setSelected(mediaTypeFilter.imagesOnly, forSegment: 0)
        mediaTypeFilterControl?.setSelected(mediaTypeFilter.videosOnly, forSegment: 1)
    }

    func apply(showsZipFiles: Bool) {
        zipVisibilityControl?.setSelected(showsZipFiles, forSegment: 0)
        zipVisibilityControl?.isEnabled = !fileList.isEditingText
    }

    private func applyCurrentState() {
        apply(
            displayMode: fileList.currentDisplayMode,
            thumbnailSize: fileList.currentThumbnailSize
        )
    }

    private func toolbarVisibilityChanged(_ isVisible: Bool) {
        fileList.isToolbarShown = isVisible

        var viewSettings = settings.viewSettings
        guard viewSettings.showsToolbar != isVisible else { return }
        viewSettings.showsToolbar = isVisible
        settings.viewSettings = viewSettings
    }

    @objc private func historySelected(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            panes.goBack(sender)
        } else {
            panes.goForward(sender)
        }
    }

    @objc private func paneLayoutSelected(_ sender: NSSegmentedControl) {
        panes.applyToolbarSelection(
            fileListSelected: sender.isSelected(forSegment: 0),
            previewSelected: sender.isSelected(forSegment: 1)
        )
    }

    @objc private func mediaTypeFilterSelected(_ sender: NSSegmentedControl) {
        fileList.applyMediaTypeFilter(
            MediaTypeFilter(
                imagesOnly: sender.isSelected(forSegment: 0),
                videosOnly: sender.isSelected(forSegment: 1)
            )
        )
    }

    @objc private func zipVisibilitySelected(_ sender: NSSegmentedControl) {
        fileList.applyShowsZipFiles(sender.isSelected(forSegment: 0))
    }

    @objc private func viewModeSelected(_ sender: NSSegmentedControl) {
        fileList.selectDisplayMode(sender.selectedSegment == 0 ? .thumbnails : .list)
    }

    @objc private func thumbnailSizeChanged(_ sender: NSSlider) {
        fileList.applyThumbnailSize(sender.doubleValue)
    }

    /// 3つのボタングループを同じ見た目・同じ幅で並べる（FR-045・051・056・089）
    private func makeSegmentedControl(
        items: [(symbol: String, label: String)],
        trackingMode: NSSegmentedControl.SwitchTracking,
        action: Selector
    ) -> NSSegmentedControl? {
        let images = items.compactMap { item in
            NSImage(
                systemSymbolName: item.symbol,
                accessibilityDescription: item.label
            )
        }
        guard images.count == items.count else { return nil }

        let control = NSSegmentedControl(
            images: images,
            trackingMode: trackingMode,
            target: self,
            action: action
        )
        control.segmentStyle = .texturedRounded
        control.controlSize = .regular
        for index in items.indices {
            control.setWidth(36, forSegment: index)
            control.setToolTip(items[index].label, forSegment: index)
        }
        control.setAccessibilityLabel(items.map(\.label).joined(separator: "、"))
        control.sizeToFit()
        return control
    }

    private func makeGroupItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        control: NSSegmentedControl
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.view = control
        item.target = self
        item.action = control.action
        return item
    }
}

extension MainToolbarController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.historyIdentifier, Self.paneLayoutIdentifier, Self.slideshowIdentifier, Self.mediaTypeFilterIdentifier, Self.zipVisibilityIdentifier, Self.viewModeIdentifier, Self.thumbnailSizeIdentifier, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.historyIdentifier, Self.paneLayoutIdentifier, Self.slideshowIdentifier, Self.mediaTypeFilterIdentifier, Self.zipVisibilityIdentifier, Self.viewModeIdentifier, Self.thumbnailSizeIdentifier, .flexibleSpace]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.historyIdentifier:
            guard let control = makeSegmentedControl(
                items: [
                    ("chevron.left", "戻る"),
                    ("chevron.right", "進む"),
                ],
                trackingMode: .momentary,
                action: #selector(historySelected(_:))
            ) else {
                return nil
            }
            historyControl = control
            let item = makeGroupItem(
                identifier: itemIdentifier,
                label: "履歴",
                control: control
            )
            applyHistoryAvailability()
            return item
        case Self.paneLayoutIdentifier:
            guard let control = makeSegmentedControl(
                items: [
                    ("list.bullet.rectangle", "ファイルリストのみ表示"),
                    ("sidebar.right", "プレビューのみ表示"),
                ],
                trackingMode: .selectAny,
                action: #selector(paneLayoutSelected(_:))
            ) else {
                return nil
            }
            paneLayoutControl = control
            let item = makeGroupItem(
                identifier: itemIdentifier,
                label: "ペイン",
                control: control
            )
            apply(paneLayout: panes.paneLayout)
            return item
        case Self.slideshowIdentifier:
            let image = IconCatalog.slideshowIcon() ?? NSImage()
            let button = NSButton(
                image: image,
                target: panes,
                action: #selector(MainSplitViewController.startSlideshow(_:))
            )
            button.bezelStyle = .texturedRounded
            button.controlSize = .regular
            button.isBordered = true
            button.imagePosition = .imageOnly
            button.toolTip = "スライドショーを開始（⇧⌘S）"
            button.setAccessibilityLabel("スライドショーを開始")
            slideshowButton = button

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "スライドショーを開始"
            item.paletteLabel = "スライドショーを開始"
            item.toolTip = "スライドショーを開始（⇧⌘S）"
            item.view = button
            item.target = panes
            item.action = #selector(MainSplitViewController.startSlideshow(_:))
            item.autovalidates = true
            updateSlideshowAvailability()
            return item
        case Self.mediaTypeFilterIdentifier:
            guard let control = makeSegmentedControl(
                items: [
                    ("photo", "画像のみ表示"),
                    ("film", "動画のみ表示"),
                ],
                trackingMode: .selectAny,
                action: #selector(mediaTypeFilterSelected(_:))
            ) else {
                return nil
            }
            mediaTypeFilterControl = control
            let item = makeGroupItem(
                identifier: itemIdentifier,
                label: "種類",
                control: control
            )
            apply(mediaTypeFilter: fileList.currentMediaTypeFilter)
            return item
        case Self.zipVisibilityIdentifier:
            guard let control = makeSegmentedControl(
                items: [
                    ("doc.zipper", "zipファイルを表示"),
                ],
                trackingMode: .selectAny,
                action: #selector(zipVisibilitySelected(_:))
            ) else {
                return nil
            }
            zipVisibilityControl = control
            let item = makeGroupItem(
                identifier: itemIdentifier,
                label: "zipファイルを表示",
                control: control
            )
            apply(showsZipFiles: fileList.currentShowsZipFiles)
            return item
        case Self.viewModeIdentifier:
            guard let control = makeSegmentedControl(
                items: [
                    ("square.grid.2x2", "サムネイル"),
                    ("list.bullet", "リスト"),
                ],
                trackingMode: .selectOne,
                action: #selector(viewModeSelected(_:))
            ) else {
                return nil
            }
            viewModeControl = control
            let item = makeGroupItem(
                identifier: itemIdentifier,
                label: "表示形式",
                control: control
            )
            applyCurrentState()
            return item
        case Self.thumbnailSizeIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "サイズ"
            item.toolTip = "サムネイルのサイズ"
            item.view = sizeSlider
            item.autovalidates = false
            sizeItem = item
            applyCurrentState()
            return item
        default:
            return nil
        }
    }
}

extension MainToolbarController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case Self.historyIdentifier:
            applyHistoryAvailability()
            return panes.paneCommands.canNavigateHistory
                && (panes.historyNavigator.canGoBack || panes.historyNavigator.canGoForward)
        case Self.paneLayoutIdentifier:
            let enabled = panes.paneCommands.canChangeLayout
            paneLayoutControl?.isEnabled = enabled
            return enabled
        case Self.slideshowIdentifier:
            let enabled = panes.canStartSlideshow
            slideshowButton?.isEnabled = enabled
            return enabled
        case Self.zipVisibilityIdentifier:
            let enabled = !fileList.isEditingText
            zipVisibilityControl?.isEnabled = enabled
            return enabled
        default:
            return true
        }
    }
}
