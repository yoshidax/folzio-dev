# Contract: MediaViewerCore の公開 API（追加・変更）

既存の API は `specs/001-three-pane-media-viewer/contracts/core-api.md` と `specs/002-favorite-folder-rename/contracts/core-api.md` を参照。
ここでは追加・変更するものだけを書く。意味と不変条件は [data-model.md](../data-model.md)、判断の根拠は [research.md](../research.md) の R57〜R66。

## PackageName（新規、Sources/MediaViewerCore/Operations/PackageName.swift）

```swift
import UniformTypeIdentifiers

public enum PackageName {
    /// 名前の拡張子がパッケージの型（.app・.bundle・.rtfd など）なら true。拡張子がなければ false（EC-53、R57）
    public static func isPackage(_ name: String) -> Bool
}
```

## validateNewName（変更、Sources/MediaViewerCore/Operations/NameValidation.swift）

シグネチャは変えない。`isDirectory` が true のとき、`PackageName.isPackage(name)` なら `.invalid(reason:)` を返す（data-model.md）。

## OperationOrigin・ConfirmationPolicy（新規、Sources/MediaViewerCore/Operations/ConfirmationPolicy.swift）

```swift
public enum OperationOrigin: Sendable, Equatable {
    case fileList
    case tree
}

public enum ConfirmationPolicy {
    /// 確認モーダルの省略設定（FR-023）がオンのときに、確認を省略してよいか（FR-024・079、R58）
    public static func isSkippable(_ kind: FileOperation.Kind, origin: OperationOrigin) -> Bool
}
```

## TreeRenameTarget・FavoriteCommands・TreeContextMenuItem（変更、Sources/MediaViewerCore/Model/FavoriteCommands.swift）

```swift
public enum TreeRenameTarget: Sendable, Equatable {
    /// お気に入りの表示名の変更（FR-099）
    case favorite(URL)
    /// ツリーの通常のフォルダの名前の変更（FR-103）。ルートは含まない
    case folder(URL)
}

public enum TreeContextMenuItem: Sendable, Equatable {
    case pasteHere, movePasteHere, addToFavorites, revealInFinder, removeFromFavorites
    case moveToTrash
    case renameFavorite
    /// ツリーの通常のフォルダの「名前を変更」（FR-103）。追加
    case renameFolder
    case separator
}

public enum FavoriteCommands {
    /// 変更: 戻り値を URL? から TreeRenameTarget? にし、roots を受け取る（R59）
    public static func renameTarget(_ role: TreeItemRole?, roots: [URL]) -> TreeRenameTarget?

    /// 変更: ルート以外の .folder に .renameFolder を加える（A-37）
    public static func contextMenu(for role: TreeItemRole, roots: [URL] = []) -> [TreeContextMenuItem]

    // canAdd・removalTarget・trashTarget・folderToShow・acceptsFiles は変えない
}
```

## RenamedFolder（新規、Sources/MediaViewerCore/Model/RenamedFolder.swift）

```swift
public struct RenamedFolder: Sendable, Equatable {
    public let from: URL
    public let to: URL

    public init(from: URL, to: URL)

    /// from 自身か配下を指す URL（file・mvzip）を新しい場所の URL にする。関係がなければ nil（R61）
    public func rebase(_ url: URL) -> URL?

    /// rebase(url) ?? url
    public func rebaseOrSelf(_ url: URL) -> URL
}
```

## BrowserModel（変更、Sources/MediaViewerCore/Browser/BrowserModel.swift）

```swift
extension BrowserModel {
    /// フォルダの名前を変えた後に、表示中の一覧・選択・検索結果・保存値の場所を付け替える。ディスクは読まず、
    /// プレビューと再生中の動画は変えない。検索中なら新しい場所を追加で列挙する（FR-104・105、R62・R63）
    public func didRenameFolder(from oldURL: URL, to newURL: URL)
}
```

`didRenameItem(at:to:)`（ファイルの名前の変更、002 以前）は変えない。

## App 側の変更（参考。公開 API ではない）

| 型 | 変更 |
|---|---|
| `ConfirmationPresenter` | `confirm(_:includesFolders:origin:location:)`。`ConfirmationPolicy` で省略を判断し、`location` があれば「場所: …」を添える（R58） |
| `FileOperationCoordinator` | `rename(_:to:origin:)`・`trash(_:origin:)`（既定は `.fileList`）。`onFolderRenamed: ((URL, URL) -> Void)?` を追加し、フォルダの名前の変更に成功したら `didRenameFolder` の前に呼ぶ（R62・R64） |
| `DirectoryTreeViewController` | `editingTarget`（R60）、`.renameFolder` の項目、`onFolderRenamed` でのノードの付け替え（R64）、お気に入りの有無の確認（R65）、ゴミ箱の `origin: .tree`（R66） |
