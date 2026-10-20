import AppKit
import MediaViewerCore

@MainActor
final class MainToolbarController: NSObject {
    private static let viewModeIdentifier = NSToolbarItem.Identifier("viewMode")
    private static let thumbnailSizeIdentifier = NSToolbarItem.Identifier("thumbnailSize")

    let toolbar = NSToolbar(identifier: "MainToolbar")

    private let fileList: FileListViewController
    private let settings: SettingsStore
    private let sizeSlider = NSSlider()
    private var viewModeGroup: NSToolbarItemGroup?
    private var sizeItem: NSToolbarItem?
    private var visibilityObservation: NSKeyValueObservation?

    init(fileList: FileListViewController, settings: SettingsStore) {
        self.fileList = fileList
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

        visibilityObservation = toolbar.observe(\.isVisible, options: [.new]) { [weak self] toolbar, _ in
            let isVisible = toolbar.isVisible
            MainActor.assumeIsolated {
                self?.toolbarVisibilityChanged(isVisible)
            }
        }
    }

    func apply(displayMode: DisplayMode, thumbnailSize: Double) {
        viewModeGroup?.selectedIndex = displayMode == .thumbnails ? 0 : 1
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

    @objc private func viewModeSelected(_ sender: NSToolbarItemGroup) {
        fileList.selectDisplayMode(sender.selectedIndex == 0 ? .thumbnails : .list)
    }

    @objc private func thumbnailSizeChanged(_ sender: NSSlider) {
        fileList.applyThumbnailSize(sender.doubleValue)
    }
}

extension MainToolbarController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.viewModeIdentifier, Self.thumbnailSizeIdentifier, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.viewModeIdentifier, Self.thumbnailSizeIdentifier, .flexibleSpace]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.viewModeIdentifier:
            let images = [
                NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "サムネイル"),
                NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "リスト"),
            ].compactMap { $0 }
            let group = NSToolbarItemGroup(
                itemIdentifier: itemIdentifier,
                images: images,
                selectionMode: .selectOne,
                labels: ["サムネイル", "リスト"],
                target: self,
                action: #selector(viewModeSelected(_:))
            )
            group.label = "表示形式"
            group.toolTip = "表示形式"
            viewModeGroup = group
            applyCurrentState()
            return group
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
