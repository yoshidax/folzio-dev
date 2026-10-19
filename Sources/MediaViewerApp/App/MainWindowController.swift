import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    private let splitViewController: MainSplitViewController

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let splitViewController = MainSplitViewController()
        self.splitViewController = splitViewController
        super.init(window: window)

        window.contentViewController = splitViewController
        window.title = "MediaViewer"

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
}
