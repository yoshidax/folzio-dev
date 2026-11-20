# Data Model: コピー元を移動した後もペーストできるようにする

## ClipboardFileRecord（FolzioCore、新規）

Folzio が把握しているクリップボードのファイルの並び（spec.md の Key Entities）。

| フィールド | 型 | 意味 |
|---|---|---|
| `changeCount` | `Int` | 書いた・読んだときのクリップボードの版 |
| `urls` | `[URL]` | 書いた・読んだときのファイルの並び（順序を保つ） |

- `relocated(by moves: [RenamedFolder], currentChangeCount: Int) -> [URL]?`
  - `currentChangeCount` が `changeCount` と違えば `nil`（FR-414）
  - 各 URL に `moves` を順に適用する（`RenamedFolder.rebaseOrSelf`）。項目そのものと子孫を付け替える（EC-286）
  - 変わった URL が1つもなければ `nil`（FR-413 の「書き換える項目がなければ変えない」）
  - それ以外は、付け替えた並び（関係のない URL はそのまま、順序も同じ）

## 記録の状態の移り変わり

| 契機 | 記録 |
|---|---|
| Folzio のコピー（ファイルリスト・ツリー） | 書いた並びと、書いた後の版を記録する |
| ペースト・移動ペーストの実行 | 読んだ並びと、そのときの版を記録する |
| Folzio の移動・名前の変更（版が同じ） | 付け替えた並びを書き、書いた後の版で記録を更新する |
| Folzio の移動・名前の変更（版が違う） | 書き換えない。記録は使われなくなる |
| 別のアプリのコピー | 何もしない（次の移動で版の違いが分かる） |
| Folzio の終了 | 失われる（A-249） |

## 移動の対応（`RenamedFolder`、既存）

`from`（移動前の場所）と `to`（実際の移動後の場所）。`FileOperationCoordinator.transferItems` が、移動に成功した項目ごとに返す。
名前の変更は1件の対応を作る。
