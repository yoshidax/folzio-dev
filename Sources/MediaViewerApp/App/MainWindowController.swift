import AppKit
import MediaViewerCore

@MainActor
final class MainWindowController: NSWindowController {
    private let splitViewController: MainSplitViewController
    private let toolbarController: MainToolbarController

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let splitViewController = MainSplitViewController()
        self.splitViewController = splitViewController
        let settings = SettingsStore(defaults: .standard)
        let fileList = splitViewController.fileListViewController
        let toolbarController = MainToolbarController(
            fileList: fileList,
            panes: splitViewController,
            settings: settings
        )
        self.toolbarController = toolbarController
        super.init(window: window)

        window.contentViewController = splitViewController
        window.title = "MediaViewer"

        let showsToolbar = settings.viewSettings.showsToolbar
        toolbarController.toolbar.isVisible = showsToolbar
        fileList.isToolbarShown = showsToolbar
        window.toolbarStyle = .unified
        window.toolbar = toolbarController.toolbar

        let dividerWidth = splitViewController.splitView.dividerThickness
        window.minSize = NSSize(width: 720 + dividerWidth * 2, height: 400)

        let autosaveKey = "NSWindow Frame MainWindow"
        let hasSavedFrame = UserDefaults.standard.object(forKey: autosaveKey) != nil
        window.setFrameAutosaveName("MainWindow")
        if !hasSavedFrame {
            window.center()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func cancelOperation(_ sender: Any?) {
        splitViewController.exitPreviewFullScreenIfNeeded()
        super.cancelOperation(sender)
    }

    @objc func toggleMainToolbar(_ sender: Any?) {
        guard let toolbar = window?.toolbar else { return }
        toolbar.isVisible.toggle()
    }
}

extension MainWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleMainToolbar(_:)) {
            let isVisible = window?.toolbar?.isVisible ?? false
            menuItem.title = isVisible ? "ツールバーを隠す" : "ツールバーを表示"
            return window?.toolbar != nil
        }
        return true
    }
}
