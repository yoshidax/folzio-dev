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
    /// ツリーのフォルダをゴミ箱に入れる（FR-079）
    case moveToTrash
    /// お気に入りの項目の「名前を変更」（FR-099）
    case renameFavorite
    /// ツリーの通常のフォルダの「名前を変更」（FR-103）
    case renameFolder
    case separator
}

/// ツリーの「名前を変更」の対象（research.md R59）
public enum TreeRenameTarget: Sendable, Equatable {
    /// お気に入りの表示名の変更。実際のフォルダは変えない（FR-099）
    case favorite(URL)
    /// ツリーの通常のフォルダの名前の変更。ルートは含まない（FR-103）
    case folder(URL)
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

    /// Return・「編集 > 名前を変更」・右クリックの「名前を変更」の対象。.favorite は表示名の変更、ルート以外の .folder は
    /// 実際のフォルダの名前の変更（`trashTarget` と同じ範囲）。ルート・.favoritesHeader・nil は nil（FR-099・FR-103、R59）
    public static func renameTarget(_ role: TreeItemRole?, roots: [URL]) -> TreeRenameTarget? {
        switch role {
        case .favorite(let url):
            return .favorite(url)
        case .folder:
            return trashTarget(role, roots: roots).map(TreeRenameTarget.folder)
        case .favoritesHeader, nil:
            return nil
        }
    }

    /// ⌘⌫ と右クリックメニューの「ゴミ箱に入れる」の対象（FR-079）。.folder で、かつルート
    /// （`FolderNavigation.enclosingFolder` が nil）でないときだけ URL を返す。.favorite・.favoritesHeader・nil は nil（FR-064）
    public static func trashTarget(_ role: TreeItemRole?, roots: [URL]) -> URL? {
        guard case .folder(let url) = role,
              FolderNavigation.enclosingFolder(of: url, roots: roots) != nil else { return nil }
        return url
    }

    /// 右クリックメニューの項目と並び。.favoritesHeader は空（メニューを出さない）。
    /// `trashTarget` が URL を返す行では先頭に .moveToTrash・.renameFolder とそれぞれの区切り線を置く（A-37）。
    /// `roots` の既定値は空（このとき .moveToTrash・.renameFolder を出さない）
    public static func contextMenu(for role: TreeItemRole, roots: [URL] = []) -> [TreeContextMenuItem] {
        switch role {
        case .folder:
            let items: [TreeContextMenuItem] =
                [.pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]
            return trashTarget(role, roots: roots) != nil
                ? [.moveToTrash, .separator, .renameFolder, .separator] + items
                : items
        case .favorite:
            return [.renameFavorite, .removeFromFavorites]
        case .favoritesHeader:
            return []
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
