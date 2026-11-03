# Data Model: 同一パスのファイルの内容更新をサムネイルとプレビューに反映する

## FileContentVersion（新規、FolzioCore）

同じパスのファイルの内容が置き換わったかを判断する値（research.md R1）。`Hashable`、`Sendable`。永続化しない。

| フィールド | 型 | 説明 |
|---|---|---|
| `fileSize` | `Int64` | ファイルの大きさ（zip の中の項目では zip ファイルの大きさ） |
| `modificationDate` | `Date?` | 内容の更新日時 |
| `fileIdentifier` | `UInt64?` | ファイルシステム上の実体の番号（inode）。得られない場合は `nil` |

- 2つの値が等しくないとき、内容が置き換わったと判断する（A-141）。
- 生成: 通常のファイルは `URLResourceValues` から、zip の中の項目は `ArchiveIdentity` から作る。

## MediaFile（変更）

| フィールド | 型 | 変更 |
|---|---|---|
| `contentVersion` | `FileContentVersion?` | 追加。メディアファイルの行と zip の中のメディアの行で設定する。フォルダ・zip ファイル・`..` の行は `nil` |

- `==` と `hash` は URL だけのまま（選択と差分の既存の扱いを変えない）。版の比較は `contentVersion` を直接比べる。

## DecodedImageCache（変更）

- 項目に `version: FileContentVersion` を持つ。
- `get(_ url:, version:)`: 項目の版が一致すれば返す。違えば項目を捨てて `nil`。`version` が `nil` なら常に `nil`。
- `put(_ image:, for url:, version:)`: `version` が `nil` なら保持しない。同じ URL の項目は置き換える（URL ごとに1つ）。
- メモリの上限と LRU の追い出しは変えない。

## ThumbnailProviding（変更）

- `thumbnail(for:pointSize:scale:version:)`、`cancel(for:pointSize:scale:version:)`。
- キャッシュのキー: `URL#pixelSize#version`。`version` が `nil` のときは `URL#pixelSize`（従来どおり）。

## BrowserModel（変更）

| 状態 | 型 | 説明 |
|---|---|---|
| `contentChangeGeneration` | `Int`（公開・観察対象） | 内容の置き換えを検出するたびに 1 進める |
| `changedContentURLs` | `Set<URL>`（公開） | 直近の検出で版が変わった URL |

状態の遷移（フォルダの一覧）:

1. 変更の通知 → `reloadCurrentFolder()` が一覧を取り直す
2. 旧 `allFiles` と新 `allFiles` を URL で突き合わせ、`contentVersion` の違う URL を求める
3. 空でなければ `changedContentURLs` を設定し、`contentChangeGeneration` を進める
4. フォーカス中の URL が含まれ、プレビューが静止画・アニメーション画像・読み込み中なら、プレビューを読み込み直す（R5）
5. 該当する先読みのタスクを取り消す

検索結果では、2 の突き合わせを `pruneMissingResults(under:)` の確認の結果で行う（R6）。
