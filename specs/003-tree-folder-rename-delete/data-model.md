# Data Model: ツリーのフォルダの名前の変更と削除

既存のモデルは `specs/001-three-pane-media-viewer/data-model.md` と `specs/002-favorite-folder-rename/data-model.md` を参照。
ここでは追加・変更する部分だけを書く。判断の根拠は [research.md](./research.md) の R57〜R67。

## PackageName（新規）

名前がパッケージの型の拡張子を持つかを判定する純粋関数の名前空間（`enum`）。AppKit に依存しない（R57）。

| 操作 | 振る舞い |
|---|---|
| `isPackage(_ name: String) -> Bool` | `(name as NSString).pathExtension` が空なら false。空でなければ `UTType(filenameExtension:conformingTo: .directory)` を引き、`.package` に適合すれば true |

## validateNewName（変更）

| 条件 | 結果 |
|---|---|
| 既存の検査（空・`/` `:`・先頭の `.`・同名）のどれかに当たる | 既存どおり `.invalid(reason:)` |
| `isDirectory == true` かつ `PackageName.isPackage(name)` | 追加。`.invalid(reason: "この名前にするとフォルダがパッケージとして扱われ、表示されなくなります")`（EC-53・EC-14） |
| `isDirectory == true` | 既存どおり `.ok`（拡張子の変更の確認はしない。EC-49） |
| `isDirectory == false` | 既存どおり（パッケージの検査はしない） |

## OperationOrigin（新規）・ConfirmationPolicy（新規）

確認モーダルを省略できるかの判断（FR-024・FR-079 の変更、R58）。

```text
OperationOrigin = .fileList | .tree
```

| 操作の種類 | `.fileList` | `.tree` |
|---|---|---|
| `.copy` | 省略できる | 省略できる（ツリーのフォルダへのペースト・ドロップのコピー。従来どおり） |
| `.trash` | 省略できる | **省略できない**（追加） |
| `.move` | 省略できない | 省略できない |
| `.rename` | 省略できない | 省略できない |

`ConfirmationPolicy.isSkippable(_:origin:) -> Bool` が上の表を返す。省略できない確認モーダルには「今後この確認を表示しない」を出さない。
お気に入りの削除（FR-064）は従来どおり `ConfirmationPresenter.confirmRemovingFavorite` で、省略できる。

## TreeRenameTarget（新規）・FavoriteCommands（変更）・TreeContextMenuItem（変更）

```text
TreeRenameTarget = .favorite(URL) | .folder(URL)
```

| 操作 | 振る舞い |
|---|---|
| `FavoriteCommands.renameTarget(_ role: TreeItemRole?, roots: [URL]) -> TreeRenameTarget?` | 変更。`.favorite(url)` → `.favorite(url)`。`.folder(url)` でルートでない（`FolderNavigation.enclosingFolder` が nil でない）→ `.folder(url)`。`.folder` のルート・`.favoritesHeader`・nil → nil（US1-AS35・45、FR-103） |
| `FavoriteCommands.contextMenu(for:roots:)` | 変更。ルート以外の `.folder` は `[.moveToTrash, .separator, .renameFolder, .separator, .pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]`（A-37）。ルートの `.folder`・`.favorite`・`.favoritesHeader` は既存どおり |
| `TreeContextMenuItem.renameFolder` | 追加。ツリーの通常のフォルダの「名前を変更」 |

## RenamedFolder（新規）

名前を変えたフォルダの元の場所と新しい場所。`Sendable`・`Equatable`（R61）。

| フィールド | 型 | 説明 |
|---|---|---|
| `from` | `URL` | 名前を変える前のフォルダの場所（`file` スキーム） |
| `to` | `URL` | 名前を変えた後のフォルダの場所（`from` と同じ親） |

| 操作 | 振る舞い |
|---|---|
| `rebase(_ url: URL) -> URL?` | `url` が `from` 自身か配下なら、新しい場所の URL を返す。関係がなければ nil |
| `rebaseOrSelf(_ url: URL) -> URL` | `rebase(url) ?? url` |

### 規則

- `file` スキーム: `url.standardizedFileURL.pathComponents` が `from.standardizedFileURL.pathComponents` で始まるときだけ。
  残りの要素を `to` に足す。`url` がディレクトリを表す（`hasDirectoryPath`）なら結果も同じにする
- `mvzip` スキーム: `ArchiveURL.parse` の zip の絶対パスを `file` スキームの規則で付け替え、`ArchiveURL.entry(archive:path:)` で作り直す。
  `..` の行（`isParentLink`）は `ArchiveURL.parentLink(of:)` で作り直す
- `mvparent` スキームとそれ以外のスキーム: nil（`..` は表示中のフォルダから作り直すため）
- `from` と `to` が同じ場所なら、関係する URL もそのまま返す

## BrowserModel（変更）

| 操作 | 振る舞い |
|---|---|
| `didRenameFolder(from: URL, to: URL)` | 追加（R62）。ディスクは読まない。`RenamedFolder` で次を付け替える: `listing.folder`、`listing.archive?.archive`、`allFiles` の各行の `url`（行が `from` 自身なら `name` も新しい名前に）、`selection.selected`・`selection.focused`、`listing.search?.root`、検索結果の索引、設定の `lastFolder`。その後 `allFiles` を `sortOrder` で並べ直して `rebuildListing()`。`preview`・`stopPlaybackSignal`・`navigationGeneration`・`treeSyncRequest` は変えない。検索中なら名前の変更を記録し、必要なら追加の列挙を始める（下の「検索中」） |

### 検索中（`listing.search?.phase == .searching`）の追加の状態（R63）

| フィールド | 型 | 説明 |
|---|---|---|
| `searchRenames` | `[RenamedFolder]`（`private`） | 今の検索の間に行われた名前の変更。`resetForNavigation` で空にする |
| `activeSearchStreams` | `Int`（`private`） | 今の検索で終わっていない列挙の数。0 になったら `phase = .finished` |
| `searchPattern` | `SearchPattern?`（`private`） | 今の検索の条件。追加の列挙に使う |

- `appendSearchResults` は、届いた各行の `url` を `searchRenames` の順に `rebaseOrSelf` で付け替え、すでに結果にある URL を捨ててから
  マージする
- `didRenameFolder` は、`from` が検索起点の配下（起点そのもの・祖先を含む）なら、新しい場所（`from` が起点か祖先なら付け替えた起点、
  そうでなければ `to`）を `searchPattern` で追加で列挙する

## DirectoryTreeViewController の状態（App、変更）

| フィールド | 型 | 説明 |
|---|---|---|
| `editingTarget` | `EditingTarget?` | 変更。002 の `editingFavorite` を置き換える。`.favorite(FavoriteEntry)` / `.folder(Node)`。nil 以外の間は「名前の変更中」（FR-102） |
| `editingOriginalName` | `String?` | 既存。編集前の名前 |

### 1件のフォルダの名前の変更の流れ（FR-103・104、R60・R62・R64）

```text
（編集なし）──Return・名前を変更──▶ 編集中 ──Esc──▶（編集なし。何もしない）
                                     │
                                     ├──確定（空・同じ名前）──▶（編集なし。何もしない）
                                     │
                                     └──確定（別の名前）──▶ 検証 ──エラー──▶ 検証エラーを表示（名前は変わらない）
                                                              │
                                                              └──ok──▶ 確認モーダル ──キャンセル──▶（何もしない）
                                                                          │
                                                                          └──実行──▶ 失敗 ──▶ 失敗の表示（FR-026）
                                                                                      │
                                                                                      └──成功──▶ ツリーの付け替え → BrowserModel.didRenameFolder
                                                                                                 → reloadCurrentFolder → 親の読み直し
                                                                                                 → お気に入りの有無の確認
```

## テスト

| 対象 | 確かめること | 対応 |
|---|---|---|
| `PackageName` | `Photos.app`・`Docs.rtfd`・`X.bundle` は true、`2025.01`・`Photos`・`a.txt`・`.app`（拡張子だけ）は false | R57 |
| `validateNewName` | フォルダで `Photos.app` は `.invalid`。ファイルで `Photos.app` は既存どおり（拡張子の変更の確認）。既存の検査の順序は変わらない | EC-53・EC-14 |
| `ConfirmationPolicy` | 上の表のすべての組み合わせ | FR-024・FR-079、SC-027 |
| `FavoriteCommands` | `renameTarget`: お気に入り・ルート以外のフォルダ・ルート・見出し・nil。`contextMenu`: ルート以外のフォルダの並び、ルートに `.renameFolder` が出ないこと | FR-103、US1-AS35・45、A-37 |
| `RenamedFolder` | 自身・配下・兄弟の前方一致（`/a/Photo` と `/a/Photos`）・関係のない URL・末尾の `/`・zip の中の項目と `..`・`mvparent` は nil | R61 |
| `BrowserModel.didRenameFolder` | 表示中のフォルダ自身・祖先・親（行の名前と並び位置）・zip の中・`lastFolder`・選択とフォーカスの付け替え。`preview` と `stopPlaybackSignal` が変わらない。名前の変更の後の `handleFileSystemEvent`（古い場所）で親へ移らない。関係のないフォルダでは何も変わらない | FR-104、US1-AS40・41、EC-50、SC-024 |
| `BrowserModel.didRenameFolder`（検索） | 結果の場所・起点の付け替え、「場所」で並べ替え中の並べ直し、検索中に後から届く古い場所の結果の付け替え、追加の列挙との重複の除去、両方の列挙が終わってから `.finished` | FR-105、EC-52、US1-AS42、SC-025 |
| 性能 | 10,000 件の検索結果で `didRenameFolder` が 100ms 未満 | 憲章 II、R67 |
