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

    /// `zoomTarget` は表示メニューの「拡大」「縮小」「表示領域に合わせる」の target。
    /// キー入力先のウインドウに依存せずメインウインドウのプレビューを操作するため、明示的に渡す（FR-135、A-73）
    static func install(zoomTarget: AppDelegate) {
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

        // ⌘F。⇧⌘F（お気に入りへ移動）・⌃⌘F（フルスクリーン）とは修飾キーで区別する（FR-080、R39）
        let searchItem = NSMenuItem(
            title: "検索…",
            action: #selector(MainSplitViewController.showSearch(_:)),
            keyEquivalent: "f"
        )
        searchItem.keyEquivalentModifierMask = [.command]
        searchItem.target = nil
        fileMenu.addItem(searchItem)
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
        viewMenu.addItem(.separator())

        // プレビューの表示倍率（FR-135）。⌘+ は `+` の入力に Shift を含む
        let zoomInItem = NSMenuItem(
            title: "拡大",
            action: #selector(AppDelegate.previewZoomIn(_:)),
            keyEquivalent: "+"
        )
        zoomInItem.keyEquivalentModifierMask = [.command]
        zoomInItem.target = zoomTarget
        viewMenu.addItem(zoomInItem)

        // Shift なしの ⌘= でも拡大する（A-72）。表示は ⌘+ のままにするため非表示にする。
        // 非表示の項目は allowsKeyEquivalentWhenHidden を true にしないとキー等価に反応しない
        let zoomInAlternateItem = NSMenuItem(
            title: "拡大",
            action: #selector(AppDelegate.previewZoomIn(_:)),
            keyEquivalent: "="
        )
        zoomInAlternateItem.keyEquivalentModifierMask = [.command]
        zoomInAlternateItem.target = zoomTarget
        zoomInAlternateItem.isHidden = true
        zoomInAlternateItem.allowsKeyEquivalentWhenHidden = true
        viewMenu.addItem(zoomInAlternateItem)

        let zoomOutItem = NSMenuItem(
            title: "縮小",
            action: #selector(AppDelegate.previewZoomOut(_:)),
            keyEquivalent: "-"
        )
        zoomOutItem.keyEquivalentModifierMask = [.command]
        zoomOutItem.target = zoomTarget
        viewMenu.addItem(zoomOutItem)

        let zoomToFitItem = NSMenuItem(
            title: "表示領域に合わせる",
            action: #selector(AppDelegate.previewZoomToFit(_:)),
            keyEquivalent: "0"
        )
        zoomToFitItem.keyEquivalentModifierMask = [.command]
        zoomToFitItem.target = zoomTarget
        viewMenu.addItem(zoomToFitItem)

        // 大文字の S で ⇧⌘S になる
        let slideshowItem = NSMenuItem(
            title: "スライドショーを開始",
            action: #selector(MainSplitViewController.startSlideshow(_:)),
            keyEquivalent: "S"
        )
        slideshowItem.keyEquivalentModifierMask = [.command]
        slideshowItem.target = nil
        viewMenu.addItem(slideshowItem)

        let navigateMenuItem = NSMenuItem()
        mainMenu.addItem(navigateMenuItem)
        let navigateMenu = NSMenu(title: "移動")
        navigateMenuItem.submenu = navigateMenu

        let backItem = NSMenuItem(
            title: "戻る",
            action: #selector(MainSplitViewController.goBack(_:)),
            keyEquivalent: "["
        )
        backItem.target = nil
        navigateMenu.addItem(backItem)

        let forwardItem = NSMenuItem(
            title: "進む",
            action: #selector(MainSplitViewController.goForward(_:)),
            keyEquivalent: "]"
        )
        forwardItem.target = nil
        navigateMenu.addItem(forwardItem)

        NSApp.mainMenu = mainMenu
    }
}
