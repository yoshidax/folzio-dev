# Data Model: パス名のコピー

永続化するデータはない。

## PathnameCopyTarget（概念）

| 項目 | 内容 |
|---|---|
| 入力（ファイルリスト） | 選択件数、フォーカス行の種類（`ListItemKind?`）、zip 内を表示中か、検索結果を表示中か |
| 入力（ツリー） | 対象の行の役割（`TreeItemRole?`）、お気に入りが利用可能か |
| 出力 | コピー可否（Bool）。ツリーはコピーする URL（なければ nil） |
| 文字列 | `URL.path`（FR-181） |

## 規則

- ファイルリスト: `allowsFileOperations`（zip 内でなく `..` でない）かつ選択件数が1のとき有効。検索結果はこの規則を満たす（FR-087）。
- ツリー: `.folder(url)`・`.favorite(url)` で URL を返す。`.favoritesHeader`・nil は nil。見つからないお気に入りの扱いは R4。
- 名前の変更中は呼び出し側（App）で無効にする（FR-102）。
