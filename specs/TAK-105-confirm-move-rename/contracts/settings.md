# Contract 変更: 永続化する設定（specs/product/contracts/settings.md）

## キーの表

`fileOps.confirmBeforeExecuting` の行を次の6行に置き換える。

| キー | 型 | 既定値 | 対応 |
|------|----|--------|------|
| `fileOps.confirm.copy` | Bool | true（未設定なら旧キーの値） | FR-022・023・024・396 |
| `fileOps.confirm.move` | Bool | true | FR-022・023・024・396 |
| `fileOps.confirm.rename` | Bool | true | FR-022・023・024・396 |
| `fileOps.confirm.removeFavorite` | Bool | true（未設定なら旧キーの値） | FR-023・064・396 |
| `fileOps.confirm.trash` | Bool | true（未設定なら旧キーの値） | FR-022・023・024・079・396 |
| `fileOps.confirmBeforeExecuting` | Bool | true | 以前の版の設定。読み込みの引き継ぎ元だけに使い、書き込まない（FR-396） |

表の後の注記に、次の2項目を加える。

- 確認の5つのキーは、未設定のときだけ FR-396 に従って旧キーから引き継ぎ（移動・名前の変更は引き継がず true）、
  旧キーは削除も上書きもしない（A-234）
- `fileOps.confirm.trash` は、ファイルリストとツリーのフォルダの両方のゴミ箱に入れる操作に適用する（FR-024・079）

## 設定ウインドウ（⌘,）の表

「ファイル操作」の2行（チェックボックスと補足説明）を次の5行に置き換え、「表の詳細」の
「ファイル操作 / 補足説明」の項目を削除する。

| 区分 | 項目 | 対応キー |
|------|------|----------|
| ファイル操作 | 「コピーする前に確認する」チェックボックス | `fileOps.confirm.copy` |
| ファイル操作 | 「移動する前に確認する」チェックボックス | `fileOps.confirm.move` |
| ファイル操作 | 「名前を変更する前に確認する」チェックボックス | `fileOps.confirm.rename` |
| ファイル操作 | 「お気に入りから削除する前に確認する」チェックボックス | `fileOps.confirm.removeFavorite` |
| ファイル操作 | 「ゴミ箱に入れる前に確認する」チェックボックス | `fileOps.confirm.trash` |
