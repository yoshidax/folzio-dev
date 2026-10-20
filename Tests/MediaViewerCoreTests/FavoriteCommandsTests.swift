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
        #expect(FavoriteCommands.contextMenu(for: .favorite(registered)) == [.removeFromFavorites])
        #expect(FavoriteCommands.contextMenu(for: .favoritesHeader).isEmpty)
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
}
