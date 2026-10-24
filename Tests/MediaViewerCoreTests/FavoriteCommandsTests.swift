import Foundation
import Testing
@testable import MediaViewerCore

@Suite("FavoriteCommands")
struct FavoriteCommandsTests {
    private let folder = URL(fileURLWithPath: "/tmp/fav/folder")
    private let registered = URL(fileURLWithPath: "/tmp/fav/registered")
    private var favorites: FavoriteFolders { FavoriteFolders(urls: [registered]) }

    @Test("canAdd は未登録の .folder だけ true")
    func canAddOnlyForUnregisteredFolder() {
        #expect(FavoriteCommands.canAdd(.folder(folder), favorites: favorites))
        #expect(!FavoriteCommands.canAdd(.folder(registered), favorites: favorites))
        #expect(!FavoriteCommands.canAdd(.favorite(registered), favorites: favorites))
        #expect(!FavoriteCommands.canAdd(.favoritesHeader, favorites: favorites))
        #expect(!FavoriteCommands.canAdd(nil, favorites: favorites))
    }

    @Test("removalTarget は .favorite のときだけ URL を返す")
    func removalTargetOnlyForFavorite() {
        #expect(FavoriteCommands.removalTarget(.favorite(registered)) == registered)
        #expect(FavoriteCommands.removalTarget(.folder(folder)) == nil)
        #expect(FavoriteCommands.removalTarget(.favoritesHeader) == nil)
        #expect(FavoriteCommands.removalTarget(nil) == nil)
    }

    @Test("右クリックメニューの項目と並びは役割で決まる")
    func contextMenuItems() {
        #expect(
            FavoriteCommands.contextMenu(for: .folder(folder))
                == [.pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]
        )
        #expect(
            FavoriteCommands.contextMenu(for: .favorite(registered)) == [.renameFavorite, .removeFromFavorites]
        )
        #expect(FavoriteCommands.contextMenu(for: .favoritesHeader).isEmpty)
    }

    // MARK: お気に入りの名前の変更（FR-099）

    @Test("renameTarget は .favorite のときだけ URL を返す")
    func renameTargetOnlyForFavorite() {
        let a = URL(fileURLWithPath: "/Users/me/a")
        #expect(FavoriteCommands.renameTarget(.favorite(a)) == a)
        #expect(FavoriteCommands.renameTarget(.favoritesHeader) == nil)
        #expect(FavoriteCommands.renameTarget(.folder(a)) == nil)
        #expect(FavoriteCommands.renameTarget(.folder(URL(fileURLWithPath: "/Users/me"))) == nil)
        #expect(FavoriteCommands.renameTarget(nil) == nil)
    }

    @Test("「名前を変更」は .folder（ルートを含む）と見出しのメニューに含まれない")
    func renameFavoriteIsOnlyInFavoriteMenu() {
        let a = URL(fileURLWithPath: "/Users/me/a")
        let root = URL(fileURLWithPath: "/Users/me")
        #expect(!FavoriteCommands.contextMenu(for: .folder(a), roots: roots).contains(.renameFavorite))
        #expect(!FavoriteCommands.contextMenu(for: .folder(root), roots: roots).contains(.renameFavorite))
        #expect(!FavoriteCommands.contextMenu(for: .folder(a)).contains(.renameFavorite))
        #expect(!FavoriteCommands.contextMenu(for: .favoritesHeader, roots: roots).contains(.renameFavorite))
    }

    @Test("選択したときに表示するフォルダ。見出しは nil")
    func folderToShowForRoles() {
        #expect(FavoriteCommands.folderToShow(for: .folder(folder)) == folder)
        #expect(FavoriteCommands.folderToShow(for: .favorite(registered)) == registered)
        #expect(FavoriteCommands.folderToShow(for: .favoritesHeader) == nil)
    }

    @Test("ドロップ・ペーストを受け付けるのは .folder だけ")
    func acceptsFilesOnlyForFolder() {
        #expect(FavoriteCommands.acceptsFiles(.folder(folder)))
        #expect(!FavoriteCommands.acceptsFiles(.favorite(registered)))
        #expect(!FavoriteCommands.acceptsFiles(.favoritesHeader))
    }

    // MARK: ツリーのフォルダをゴミ箱に入れる（FR-079）

    private let roots = [URL(fileURLWithPath: "/"), URL(fileURLWithPath: "/Users/me")]

    @Test("trashTarget は通常のフォルダの URL を返す（ルートに / を含むボリュームの下も対象）")
    func trashTargetForOrdinaryFolder() {
        let home = URL(fileURLWithPath: "/Users/me/a")
        let volume = URL(fileURLWithPath: "/Volumes/Ext/a")
        #expect(FavoriteCommands.trashTarget(.folder(home), roots: roots) == home)
        #expect(FavoriteCommands.trashTarget(.folder(volume), roots: roots) == volume)
    }

    @Test("trashTarget はルート・お気に入り・見出し・選択なし・ルート一覧が空のとき nil")
    func trashTargetIsNilForOthers() {
        let a = URL(fileURLWithPath: "/Users/me/a")
        #expect(FavoriteCommands.trashTarget(.folder(URL(fileURLWithPath: "/Users/me")), roots: roots) == nil)
        #expect(FavoriteCommands.trashTarget(.folder(URL(fileURLWithPath: "/")), roots: roots) == nil)
        #expect(FavoriteCommands.trashTarget(.folder(URL(fileURLWithPath: "/Users/me/")), roots: roots) == nil)
        #expect(FavoriteCommands.trashTarget(.favorite(a), roots: roots) == nil)
        #expect(FavoriteCommands.trashTarget(.favoritesHeader, roots: roots) == nil)
        #expect(FavoriteCommands.trashTarget(nil, roots: roots) == nil)
        #expect(FavoriteCommands.trashTarget(.folder(a), roots: []) == nil)
    }

    @Test("通常のフォルダの右クリックメニューは先頭に「ゴミ箱に入れる」と区切り線を置く")
    func contextMenuForOrdinaryFolderHasTrash() {
        let a = URL(fileURLWithPath: "/Users/me/a")
        #expect(
            FavoriteCommands.contextMenu(for: .folder(a), roots: roots)
                == [.moveToTrash, .separator, .pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]
        )
    }

    @Test("ルートのフォルダと roots 省略時は従来の並び。お気に入り・見出しは roots を渡しても変わらない")
    func contextMenuWithoutTrash() {
        let plain: [TreeContextMenuItem] =
            [.pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]
        let a = URL(fileURLWithPath: "/Users/me/a")
        #expect(FavoriteCommands.contextMenu(for: .folder(URL(fileURLWithPath: "/Users/me")), roots: roots) == plain)
        #expect(FavoriteCommands.contextMenu(for: .folder(a)) == plain)
        #expect(FavoriteCommands.contextMenu(for: .favorite(a), roots: roots) == [.renameFavorite, .removeFromFavorites])
        #expect(FavoriteCommands.contextMenu(for: .favoritesHeader, roots: roots).isEmpty)
    }
}
