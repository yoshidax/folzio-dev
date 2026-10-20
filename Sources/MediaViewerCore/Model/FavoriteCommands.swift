import Foundation

/// ツリーの行の役割。UI は行からこれを作り、お気に入りの操作の判断を FavoriteCommands に任せる
public enum TreeItemRole: Sendable, Equatable {
    case favoritesHeader
    case favorite(URL)
    /// ホーム・ボリュームのルートを含む通常のフォルダ
    case folder(URL)
}

public enum TreeContextMenuItem: Sendable, Equatable {
    case pasteHere, movePasteHere, addToFavorites, revealInFinder, removeFromFavorites
    case separator
}

public enum FavoriteCommands {
    /// ⌃⌘T と「お気に入りに追加」。.folder かつ未登録のときだけ true
    public static func canAdd(_ role: TreeItemRole?, favorites: FavoriteFolders) -> Bool {
        guard case .folder(let url) = role else { return false }
        return !favorites.contains(url)
    }

    /// ⌘⌫ と「お気に入りから削除」の対象。.favorite のときだけ URL を返す
    public static func removalTarget(_ role: TreeItemRole?) -> URL? {
        guard case .favorite(let url) = role else { return nil }
        return url
    }

    /// 右クリックメニューの項目と並び。.favoritesHeader は空（メニューを出さない）
    public static func contextMenu(for role: TreeItemRole) -> [TreeContextMenuItem] {
        switch role {
        case .folder:
            [.pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]
        case .favorite:
            [.removeFromFavorites]
        case .favoritesHeader:
            []
        }
    }

    /// 選択したときに一覧を切り替えるフォルダ。.favoritesHeader は nil（FR-065）
    public static func folderToShow(for role: TreeItemRole) -> URL? {
        switch role {
        case .folder(let url), .favorite(let url):
            url
        case .favoritesHeader:
            nil
        }
    }

    /// ドロップ・ペーストを受け付けるか。.folder だけ true（アクセス可否は従来どおり UI 側で見る）
    public static func acceptsFiles(_ role: TreeItemRole) -> Bool {
        if case .folder = role { return true }
        return false
    }
}
