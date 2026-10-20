import AppKit

@MainActor
final class FileContextMenu: NSObject, NSMenuDelegate {
    let menu: NSMenu

    private weak var host: FileListViewController?
    private let copyItem = NSMenuItem()
    private let pasteItem = NSMenuItem()
    private let movePasteItem = NSMenuItem()
    private let openContainerItem = NSMenuItem()
    private let goUpItem = NSMenuItem()

    init(host: FileListViewController) {
        self.host = host
        self.menu = NSMenu(title: "")
        super.init()
        buildMenu()
        menu.delegate = self
    }

    func install(listModeView: ListModeView, thumbnailModeView: ThumbnailModeView) {
        listModeView.contextMenu = menu
        thumbnailModeView.contextMenu = menu
    }

    static func pasteboardHasFileURLs() -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        return NSPasteboard.general.canReadObject(
            forClasses: [NSURL.self],
            options: options
        )
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let urls = host?.selectedFileURLs ?? []
        if urls.count == 1, let name = urls.first?.lastPathComponent {
            copyItem.title = "\"\(name)\" をコピー"
        } else if urls.count > 1 {
            copyItem.title = "\(urls.count) 項目をコピー"
        } else {
            copyItem.title = "コピー"
        }

        // 「上の階層へ」は zip の中だけ出す。有効・無効は validateMenuItem に任せる
        goUpItem.isHidden = !(host?.isBrowsingArchive ?? false)

        // zip の中ではペースト・移動ペーストを使えない（FR-073）
        let allowsPaste = host?.focusedItemCommands.allowsPaste ?? true
        let canPaste = allowsPaste && Self.pasteboardHasFileURLs()
        pasteItem.isEnabled = canPaste
        movePasteItem.isEnabled = canPaste
    }

    private func buildMenu() {
        menu.autoenablesItems = true

        openContainerItem.title = "中を表示"
        openContainerItem.action = #selector(FileListViewController.openFocusedItem(_:))
        openContainerItem.keyEquivalent = String(UnicodeScalar(NSDownArrowFunctionKey)!)
        openContainerItem.keyEquivalentModifierMask = [.command]
        openContainerItem.target = host
        menu.addItem(openContainerItem)

        goUpItem.title = "上の階層へ"
        goUpItem.action = #selector(FileListViewController.goToEnclosingLevel(_:))
        goUpItem.keyEquivalent = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        goUpItem.keyEquivalentModifierMask = [.command]
        goUpItem.target = host
        goUpItem.isHidden = true
        menu.addItem(goUpItem)
        menu.addItem(.separator())

        addItem(
            title: "開く",
            action: #selector(FileListViewController.open(_:)),
            keyEquivalent: "",
            modifiers: [.command]
        )
        menu.addItem(.separator())
        addItem(
            title: "ゴミ箱に入れる",
            action: #selector(FileListViewController.moveToTrash(_:)),
            keyEquivalent: String(UnicodeScalar(NSBackspaceCharacter)!),
            modifiers: [.command]
        )
        menu.addItem(.separator())
        addItem(
            title: "名前を変更",
            action: #selector(FileListViewController.rename(_:)),
            keyEquivalent: "\r",
            modifiers: []
        )
        addItem(
            title: "複製",
            action: #selector(FileListViewController.duplicate(_:)),
            keyEquivalent: "d",
            modifiers: [.command]
        )
        menu.addItem(.separator())

        copyItem.title = "コピー"
        copyItem.action = #selector(FileListViewController.copy(_:))
        copyItem.keyEquivalent = "c"
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = host
        menu.addItem(copyItem)

        pasteItem.title = "ペースト"
        pasteItem.action = #selector(FileListViewController.paste(_:))
        pasteItem.keyEquivalent = "v"
        pasteItem.keyEquivalentModifierMask = [.command]
        pasteItem.target = host
        menu.addItem(pasteItem)

        movePasteItem.title = "移動ペースト"
        movePasteItem.action = #selector(FileListViewController.movePaste(_:))
        movePasteItem.keyEquivalent = "v"
        movePasteItem.keyEquivalentModifierMask = [.command, .option]
        movePasteItem.target = host
        menu.addItem(movePasteItem)

        menu.addItem(.separator())
        addItem(
            title: "Finder に表示",
            action: #selector(FileListViewController.revealInFinder(_:)),
            keyEquivalent: "",
            modifiers: [.command]
        )
    }

    private func addItem(
        title: String,
        action: Selector,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifiers
        item.target = host
        menu.addItem(item)
    }
}
