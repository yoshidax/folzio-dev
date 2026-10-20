import AppKit

/// ツリーが検証で「お気に入りから削除」に変えた項目名を、メニューを開くたびに「ゴミ箱に入れる」へ戻す。
/// プレビューにフォーカスがあるときは誰も検証しないため、戻さないと前の項目名が残る
@MainActor
private final class TrashMenuTitleReset: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items where item.action == #selector(FileListViewController.moveToTrash(_:)) {
            item.title = "ゴミ箱に入れる"
        }
    }
}

@MainActor
final class MainMenu {
    /// NSMenu.delegate は weak のため保持する
    private static let trashTitleReset = TrashMenuTitleReset()

    static func install() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "MediaViewer")
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(
            title: "設定…",
            action: #selector(AppDelegate.showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = nil
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "ファイル")
        fileMenuItem.submenu = fileMenu

        let openItem = NSMenuItem(
            title: "開く",
            action: #selector(FileListViewController.open(_:)),
            keyEquivalent: "o"
        )
        openItem.target = nil
        fileMenu.addItem(openItem)

        let openContainerItem = NSMenuItem(
            title: "中を表示",
            action: #selector(FileListViewController.openFocusedItem(_:)),
            keyEquivalent: String(UnicodeScalar(NSDownArrowFunctionKey)!)
        )
        openContainerItem.keyEquivalentModifierMask = [.command]
        openContainerItem.target = nil
        fileMenu.addItem(openContainerItem)

        let goUpItem = NSMenuItem(
            title: "上の階層へ",
            action: #selector(FileListViewController.goToEnclosingLevel(_:)),
            keyEquivalent: String(UnicodeScalar(NSUpArrowFunctionKey)!)
        )
        goUpItem.keyEquivalentModifierMask = [.command]
        goUpItem.target = nil
        fileMenu.addItem(goUpItem)

        let revealItem = NSMenuItem(
            title: "Finder に表示",
            action: #selector(FileListViewController.revealInFinder(_:)),
            keyEquivalent: ""
        )
        revealItem.target = nil
        fileMenu.addItem(revealItem)

        let addFavoriteItem = NSMenuItem(
            title: "お気に入りに追加",
            action: #selector(MainSplitViewController.addSelectedFolderToFavorites(_:)),
            keyEquivalent: "t"
        )
        addFavoriteItem.keyEquivalentModifierMask = [.command, .control]
        addFavoriteItem.target = nil
        fileMenu.addItem(addFavoriteItem)
        fileMenu.addItem(.separator())

        let fileTrashItem = NSMenuItem(
            title: "ゴミ箱に入れる",
            action: #selector(FileListViewController.moveToTrash(_:)),
            keyEquivalent: String(UnicodeScalar(NSBackspaceCharacter)!)
        )
        fileTrashItem.target = nil
        fileMenu.addItem(fileTrashItem)
        fileMenu.delegate = trashTitleReset

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "編集")
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: "取り消す", action: Selector(("undo:")), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "やり直す", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "カット", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "コピー", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "ペースト", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))

        let movePasteItem = NSMenuItem(
            title: "移動ペースト",
            action: #selector(FileListViewController.movePaste(_:)),
            keyEquivalent: "v"
        )
        movePasteItem.keyEquivalentModifierMask = [.command, .option]
        movePasteItem.target = nil
        editMenu.addItem(movePasteItem)
        editMenu.addItem(.separator())

        let duplicateItem = NSMenuItem(
            title: "複製",
            action: #selector(FileListViewController.duplicate(_:)),
            keyEquivalent: "d"
        )
        duplicateItem.target = nil
        editMenu.addItem(duplicateItem)

        let renameItem = NSMenuItem(
            title: "名前を変更",
            action: #selector(FileListViewController.rename(_:)),
            keyEquivalent: "\r"
        )
        renameItem.keyEquivalentModifierMask = []
        renameItem.target = nil
        editMenu.addItem(renameItem)

        let editTrashItem = NSMenuItem(
            title: "ゴミ箱に入れる",
            action: #selector(FileListViewController.moveToTrash(_:)),
            keyEquivalent: String(UnicodeScalar(NSBackspaceCharacter)!)
        )
        editTrashItem.target = nil
        editMenu.addItem(editTrashItem)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "すべてを選択", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenu.delegate = trashTitleReset

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "表示")
        viewMenuItem.submenu = viewMenu

        let toolbarItem = NSMenuItem(
            title: "ツールバーを表示",
            action: #selector(MainWindowController.toggleMainToolbar(_:)),
            keyEquivalent: "T"
        )
        toolbarItem.target = nil
        viewMenu.addItem(toolbarItem)
        viewMenu.addItem(.separator())

        let fullScreenItem = NSMenuItem(
            title: "フルスクリーン",
            action: #selector(MainSplitViewController.togglePreviewFullScreen),
            keyEquivalent: "f"
        )
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]
        fullScreenItem.target = nil
        viewMenu.addItem(fullScreenItem)

        NSApp.mainMenu = mainMenu
    }
}
