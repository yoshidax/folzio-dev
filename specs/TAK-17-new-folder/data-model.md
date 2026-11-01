# Data Model: TAK-17 フォルダの新規作成

新しい永続データ・設定キーはない。以下は Core に加える値と関数、App の編集の状態。

## Core

### `newFolderName(baseName:existingNames:) -> String`（NameValidation.swift）

| 入力 | 意味 |
|---|---|
| `baseName` | 表示言語の既定名（「名称未設定フォルダ」/「untitled folder」）。App が渡す |
| `existingNames` | 作成先の直下の全エントリ名（隠し項目・ファイルを含む）と、作成時に衝突した名前 |

- `existingNames` に `baseName` と大文字小文字を区別せず一致する名前がなければ `baseName`
- あれば `uniqueName(for: baseName, existingNames:)`（「<baseName> 2」から空いている番号）

### `FileOperating.createFolder(in:baseName:) async -> Result<URL, OperationFailureReason>`

| 状況 | 結果 |
|---|---|
| 作成できた | `.success(<parent>/<name>)` |
| 作成先が存在しない・フォルダでない | `.failure(.destinationNotFound)` |
| 作成時に同名が現れた | 名前を使用済みに加えて再試行（上限 100 回。超えたら `.failure(.sameNameAtDestination)`） |
| 作成先を列挙できない、書き込み権限がない、読み取り専用のボリューム、その他 | `.failure(.systemFailure(systemReason:))`（OS の理由をそのまま。EC-111） |

既存の項目を上書き・変更しない。中間のフォルダは作らない。

### `TreeContextMenuItem.newFolder` と `FavoriteCommands`

- `newFolderTarget(_ role: TreeItemRole?) -> URL?`: `.folder(url)`・`.favorite(url)` は `url`、`.favoritesHeader`・nil は nil
- `contextMenu(for:roots:)`: `.folder`・`.favorite` の先頭に `.newFolder, .separator` を加える。`.favoritesHeader` は空のまま

| 行 | メニュー（変更後） |
|---|---|
| 通常のフォルダ | 新規フォルダ / ─ / ゴミ箱に入れる / ─ / 名前を変更 / ─ / ここにペースト / ここに移動ペースト / ─ / お気に入りに追加 / ─ / パス名をコピー / Finder に表示 |
| ホーム・ボリュームの最上位 | 新規フォルダ / ─ / ここにペースト / ここに移動ペースト / ─ / お気に入りに追加 / ─ / パス名をコピー / Finder に表示 |
| お気に入りの項目 | 新規フォルダ / ─ / 名前を変更 / お気に入りから削除 / ─ / パス名をコピー |
| 「お気に入り」の見出し | メニューなし |

見つからないお気に入りの項目では、「新規フォルダ」を App が淡色にする（既存の「パス名をコピー」と同じ）。

### `ListItemCommands.allowsNewFolder`

`!isBrowsingArchive && !isShowingSearchResults`。表示中のフォルダの読み込みの失敗（`FolderListing.State` の `.denied`・`.failed`）は
App が加えて判断する。

### `ShortcutCatalog`

`ShortcutEntry(id: .newFolder, keys: "⇧⌘N", section: .files)` を `.duplicate` の後に加える。全 45 項目。

## App

### 作成の起点と編集の場所

| 起点 | 作成先 | 編集を始める場所 | キーボードフォーカス |
|---|---|---|---|
| ファイルリストの背景の右クリック、ファイルリストにフォーカスがあるときの ⇧⌘N・メニュー | 表示中のフォルダ | ファイルリストの新しい行（選択を新しい行だけにする） | ファイルリスト |
| ツリーの通常のフォルダ・ホーム・ボリュームの最上位（右クリックした行、またはツリーにフォーカスがあるときの選択中の行） | その行のフォルダ | ツリーの新しい行（作成先を展開。ツリーの選択は変えない） | ツリー |
| ツリーのお気に入りの項目 | 登録したフォルダ | ファイルリストが登録したフォルダを通常の一覧として表示中ならファイルリストの新しい行。そうでなければ編集しない | 編集するならファイルリスト、しないなら変えない |

### 編集の状態

既存の編集の状態（ツリーの `EditingTarget`、ファイルリストの `renamingURL` / `ThumbnailItemView.isRenaming`）に、「作成直後」かどうかの値を
加える。確定のときだけこの値を見て確認を省き、取り消し・空・同じ名前のときは何もせず値を破棄する。

### 作成後の反映

`FileOperationCoordinator.createFolder(in:)` は、成功時に表示中のフォルダが作成先なら `reloadCurrentFolder` を行い、`onFoldersChanged` に
作成先を渡してツリーを更新する。失敗時は `presentFailures` で作成先の名前と理由を表示し、nil を返す。履歴（FR-107）と最後に選択していた
フォルダ（FR-003）は変えない。
