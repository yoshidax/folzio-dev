# Contract: MediaViewerCore の公開 API（追加・変更）

既存の API は `specs/001-three-pane-media-viewer/contracts/core-api.md` を参照。ここでは追加・変更するものだけを書く。
意味と不変条件は [data-model.md](../data-model.md)、判断の根拠は [research.md](../research.md) の R48〜R52。

## FavoriteName（新規、Sources/MediaViewerCore/Model/FavoriteName.swift）

```swift
public enum FavoriteName {
    /// 表示名の上限。String.count（書記素クラスタ）で数える（FR-100）
    public static let maximumLength: Int  // 255

    /// 編集中の入力。改行を取り除き、maximumLength で打ち切る。前後の空白は残す
    public static func sanitizedForEditing(_ text: String) -> String

    /// 確定時の入力。sanitizedForEditing の後に前後の空白・改行を取り除く。空なら nil（表示名の解除）
    public static func normalized(_ text: String) -> String?
}
```

## FavoriteFolders（変更、Sources/MediaViewerCore/Model/FavoriteFolders.swift）

```swift
public struct FavoriteFolders: Sendable, Equatable {
    public private(set) var urls: [URL]                          // 既存

    /// customNames のキーは絶対パス。未登録のパスと、normalized で nil になる値は捨てる
    public init(urls: [URL] = [], customNames: [String: String] = [:])

    public func contains(_ url: URL) -> Bool                     // 既存
    @discardableResult public mutating func add(_ url: URL) -> Bool     // 既存。表示名は付けない
    @discardableResult public mutating func remove(_ url: URL) -> Bool  // 既存。表示名も破棄する

    /// 付けた表示名。未登録・表示名なしは nil
    public func customName(for url: URL) -> String?

    /// customName(for:) ?? defaultName
    public func displayName(for url: URL, defaultName: String) -> String

    /// 編集で確定した入力を反映する。normalized の結果が現在の表示名と同じなら何もしない。
    /// nil なら表示名を解除し、それ以外は表示名にする。変更したら true。未登録の場所は false
    @discardableResult
    public mutating func commitDisplayName(_ input: String, for url: URL, defaultName: String) -> Bool

    /// 保存用。標準化した絶対パス → 表示名
    public var customNamesByPath: [String: String] { get }
}
```

## TreeContextMenuItem・FavoriteCommands（変更、Sources/MediaViewerCore/Model/FavoriteCommands.swift）

```swift
public enum TreeContextMenuItem: Sendable, Equatable {
    case pasteHere, movePasteHere, addToFavorites, revealInFinder, removeFromFavorites
    case moveToTrash
    /// 追加。お気に入りの項目の「名前を変更」（FR-099）
    case renameFavorite
    case separator
}

public enum FavoriteCommands {
    /// 追加。Return・「編集 > 名前を変更」・右クリックの「名前を変更」の対象。.favorite のときだけ URL
    public static func renameTarget(_ role: TreeItemRole?) -> URL?

    /// 変更。.favorite は [.renameFavorite, .removeFromFavorites]。.folder・.favoritesHeader は従来どおり
    public static func contextMenu(for role: TreeItemRole, roots: [URL] = []) -> [TreeContextMenuItem]
}
```

## SettingsStore.favorites（変更、Sources/MediaViewerCore/Settings/SettingsStore.swift）

シグネチャは変えない（`public var favorites: FavoriteFolders { get nonmutating set }`）。
読み書きするキーに `favorites.displayNames` を加える。規則は [contracts/settings.md](./settings.md)。

## App 側のインターフェース（参考）

Core の契約ではないが、tasks の分割のために記す。

| 型 | 変更 |
|---|---|
| `DirectoryTreeViewController` | `@objc func rename(_:)`（「編集 > 名前を変更」・Return）、`@objc private func renameFavoriteFromMenu(_:)`（右クリック）、`NSTextFieldDelegate` への準拠、`validateMenuItem` の編集中の無効化と `rename(_:)` の判定 |
| `FavoriteNameFormatter`（新規、App/Tree） | `Formatter` のサブクラス。`isPartialStringValid(_:proposedSelectedRange:originalString:originalSelectedRange:errorDescription:)` で `FavoriteName.sanitizedForEditing` を使う。分離の注釈（`@MainActor` など）は付けない（`Formatter` の override するメソッドは nonisolated のため）。`init()` と `required init?(coder:)` を置く |
| `ConfirmationPresenter` | `confirmRemovingFavorite(named:path:)`（`confirmRemovingFavorite(named:)` を置き換える） |
