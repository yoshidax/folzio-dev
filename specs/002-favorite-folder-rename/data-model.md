# Data Model: お気に入りの名前の変更

既存のモデルは `specs/001-three-pane-media-viewer/data-model.md` を参照。ここでは追加・変更する部分だけを書く。

## FavoriteFolders（変更）

ツリーの「お気に入り」に並べる登録の一覧（FR-061〜067・099〜101）。`Sendable`・`Equatable`。

| フィールド | 型 | 説明 |
|---|---|---|
| `urls` | `[URL]`（`private(set)`） | 登録したフォルダ。登録順。同じ場所（`standardizedFileURL.path`）を重複して持たない（既存） |
| `customNames` | `[String: String]`（`private`） | 追加。同一性のキー（`standardizedFileURL.path`）→ ユーザーが付けた表示名。表示名を付けていない登録は載せない |

### 不変条件

- `customNames` のキーは、すべて `urls` に登録されている場所のキーである（未登録の場所の表示名を持たない）
- `customNames` の値は `FavoriteName.normalized(_:)` を通した値で、1〜255 文字・改行なし・前後に空白なし
- 等価比較は `urls`（順序込み）と `customNames` の両方で行う

### 操作

| 操作 | 振る舞い |
|---|---|
| `init(urls:customNames:)` | 重複は先勝ちで除き順序を保つ（既存）。`customNames` は未登録のキーと、正規化して空になる値を捨てる |
| `customName(for:)` | 登録していて表示名があればその名前、なければ nil |
| `displayName(for:defaultName:)` | `customName(for:) ?? defaultName`（FR-101） |
| `commitDisplayName(_:for:defaultName:) -> Bool` | 編集で確定した入力を反映する（R50）。未登録の場所なら false。正規化した結果が現在の表示名と同じなら何もせず false。空なら表示名を解除、それ以外は表示名にして true |
| `add(_:)` | 既存どおり末尾に追加。表示名は付けない（EC-44） |
| `remove(_:)` | 既存どおり登録を取り除き、その表示名も破棄する（EC-44） |
| `customNamesByPath` | 保存用。`customNames` をそのまま返す |

### 状態遷移（1件の登録）

```text
（未登録）──add──▶ 表示名なし ──commit(名前)──▶ 表示名あり ──commit(別の名前)──▶ 表示名あり
                     ▲                              │
                     └──── commit(空・空白だけ) ─────┘
どの状態からも ──remove──▶（未登録。表示名も破棄）
```

`commit` で現在の表示名と同じ名前を確定した場合は状態を変えない。

## FavoriteName（新規）

お気に入りの表示名の入力規則（FR-100、R50）。AppKit に依存しない純粋関数の名前空間（`enum`）。

| メンバー | 説明 |
|---|---|
| `maximumLength: Int = 255` | 表示名の上限。`String.count`（書記素クラスタ）で数える |
| `sanitizedForEditing(_:) -> String` | 改行（`CharacterSet.newlines` に含まれる文字）を取り除き、先頭から 255 文字で打ち切る。前後の空白は残す（入力中のため） |
| `normalized(_:) -> String?` | `sanitizedForEditing` の後に前後の空白と改行を取り除く。空なら nil |

`/`・`:` などファイル名に使えない文字は拒否しない。重複の検査もしない（EC-41）。

## FavoriteCommands・TreeContextMenuItem（変更）

| 変更 | 説明 |
|---|---|
| `TreeContextMenuItem.renameFavorite` | 追加。お気に入りの項目の右クリックメニューの「名前を変更」 |
| `FavoriteCommands.renameTarget(_:) -> URL?` | 追加。`.favorite(url)` のときだけ url。`.favoritesHeader`・`.folder`・nil は nil（FR-099、US1-AS35） |
| `FavoriteCommands.contextMenu(for: .favorite)` | `[.removeFromFavorites]` から `[.renameFavorite, .removeFromFavorites]` に変更 |

## 保存（SettingsStore.favorites の変更）

詳細は [contracts/settings.md](./contracts/settings.md)。

| キー | 型 | 読み込み | 書き込み |
|---|---|---|---|
| `favorites.paths` | `[String]` | 既存どおり | 既存どおり（`urls.map(\.path)`） |
| `favorites.displayNames` | `[String: String]` | 辞書でなければ空。文字列でない値・未登録のパス・正規化して空になる値は捨てる | `customNamesByPath` が空ならキーを消し、空でなければ書く |

旧形式（`favorites.paths` だけ）は、登録順のまま全件が表示名なしとして読める（EC-45）。

## App 側の状態（参考。テスト対象外）

`DirectoryTreeViewController` が持つ。保存しない。

| 状態 | 説明 |
|---|---|
| `FavoriteEntry.name` | 表示名（`displayName(for:defaultName:)` の結果）。既存のフィールドの意味を「表示名」に変える |
| `FavoriteEntry.defaultName` | 追加。登録したフォルダの名前（ルートならボリューム名）。`commitDisplayName` に渡す |
| `editingFavorite: FavoriteEntry?` | 編集中の項目。nil 以外の間は「名前の変更中」 |
| `isFinishingEdit: Bool` | 終了処理の再入を防ぐ |
| `needsReloadAfterEdit` 相当 | 編集中に届いた存在の確認の結果を、終了時の `reloadItem` で反映する（R51） |

## テスト（Tests/MediaViewerCoreTests）

| ファイル | 確かめること |
|---|---|
| `FavoriteNameTests.swift`（新規） | 前後の空白・改行の除去、空白だけ → nil、中の改行（`\n`・`\r\n`・U+2028）の除去、255 文字ちょうどは残り 256 文字目以降は切れる、絵文字・結合文字を1文字と数える、`/`・`:` を含む名前を受け付ける |
| `FavoriteFoldersTests.swift`（追加） | 表示名の設定・別の名前への変更・空での解除、現在と同じ名前の確定は false、`defaultName` と同じ名前も表示名として受け付ける、同じ表示名を複数の項目に付けられる、未登録の場所への commit は false、remove で表示名が消え再登録で既定に戻る、init が未登録のキーを捨てる、等価比較が表示名を含む |
| `FavoriteCommandsTests.swift`（追加） | `renameTarget` が `.favorite` だけで URL を返す、`.favorite` の右クリックメニューが `[.renameFavorite, .removeFromFavorites]`、`.folder`・`.favoritesHeader` のメニューに `.renameFavorite` がない |
| `SettingsStoreTests.swift`（追加） | 表示名の往復、旧形式（`favorites.paths` だけ）が登録順・表示名なしで読める、`favorites.displayNames` が辞書でない・値が文字列でない・未登録のパス・空白だけの値を捨てる、256 文字以上の保存値を 255 文字に丸める、表示名がなければキーを消す、削除した登録の表示名が書き込まれない |
