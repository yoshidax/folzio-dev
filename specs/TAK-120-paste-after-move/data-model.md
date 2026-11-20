# Data Model: コピー元を移動した後もペーストできるようにする

## ClipboardFileEntry（FolzioCore、新規）

クリップボードの1項目（spec.md の Key Entities）。

| フィールド | 型 | 意味 |
|---|---|---|
| `url` | `String` | `public.file-url` に置く文字列。ファイルの参照（`file:///.file/id=…`）、作れなければパスの file URL |
| `name` | `String?` | `public.utf8-plain-text` に置くファイル名。読み取りのとき、なければ nil |

## ClipboardFileReferences（FolzioCore、新規）

ファイルシステムに問い合わせるため、UI スレッドの外で呼ぶ。

- `entries(for urls: [URL]) -> [ClipboardFileEntry]`
  - 各 URL の参照を作る。作れなければパスの file URL の文字列にする（EC-282）
  - `name` は URL の最後の要素（ファイル名）
  - 順序を保つ
- `resolve(_ entries: [ClipboardFileEntry]) -> [ClipboardFileResolution]`
  - 参照は今のパスへ解決する。パスの file URL はそのパス（EC-285）
  - 解決できなければ `.missing(name:)`。名前は `name`、なければ `url` の文字列（R4）
  - 順序を保つ

## ClipboardFileResolution（FolzioCore、新規）

| ケース | 意味 |
|---|---|
| `.found(URL)` | 今の場所（パスの file URL） |
| `.missing(name: String)` | 解決できない。失敗の表示に使う名前 |

## クリップボードとの対応（FolzioApp の `PasteboardFileURLs`）

| 操作 | クリップボード |
|---|---|
| Folzio のコピー | 項目ごとに `NSPasteboardItem` を作り、`url` を `.fileURL`、`name` を `.string` に置く。書く直前に版を比べる（EC-281） |
| ペースト・移動ペースト | 各項目の `.fileURL` と `.string` の文字列を読む。file URL として読めない項目は除く |
| 移動・名前の変更・ゴミ箱 | 何もしない（SC-236） |
