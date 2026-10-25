import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let performanceSignposter = OSSignposter(
        subsystem: "local.my-img-viewer.MediaViewer",
        category: "Performance"
    )
    private var launchToListState: OSSignpostIntervalState?
    private var mainWindowController: MainWindowController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchToListState = performanceSignposter.beginInterval("LaunchToList")

        NSWindow.allowsAutomaticWindowTabbing = false
        MainMenu.install()

        let controller = MainWindowController()
        if let splitViewController = controller.window?.contentViewController as? MainSplitViewController {
            splitViewController.onInitialListingDisplayed = { [weak self] in
                self?.endLaunchToListInterval()
            }
        }
        controller.showWindow(nil)
        mainWindowController = controller

        NSApp.activate(ignoringOtherApps: true)
    }

    private func endLaunchToListInterval() {
        guard let state = launchToListState else { return }
        launchToListState = nil
        performanceSignposter.endInterval("LaunchToList", state)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        mainWindowController?.stopSlideshowImmediately()
    }

    @objc func showSettings(_ sender: Any?) {
        let controller: SettingsWindowController
        if let existing = settingsWindowController {
            controller = existing
        } else {
            controller = SettingsWindowController()
            settingsWindowController = controller
        }

        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
