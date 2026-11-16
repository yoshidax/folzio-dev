# Data Model: 操作ごとの実行前の確認の設定

## ConfirmationTarget（新規、FolzioCore）

確認の設定を持つ操作の種類。

| 値 | 対象の操作 | 保存キー |
|---|---|---|
| `copy` | コピー（ペースト・Option ドロップ・アプリ外からのコピーと画像・動画の保存） | `fileOps.confirm.copy` |
| `move` | 移動（移動ペースト・ドラッグ&ドロップ・アプリ外からの移動） | `fileOps.confirm.move` |
| `rename` | 名前の変更（ファイルリスト・ツリーのフォルダ） | `fileOps.confirm.rename` |
| `removeFavorite` | お気に入りから削除 | `fileOps.confirm.removeFavorite` |
| `trash` | ゴミ箱に入れる（ファイルリストとツリーのフォルダ） | `fileOps.confirm.trash` |

並び（`CaseIterable` の順）は設定ウインドウの並び（FR-223）と同じにする。

## ConfirmationOptions（変更、FolzioCore）

- 5つの Bool（`copy`・`move`・`rename`・`removeFavorite`・`trash`）を持つ。既定はすべて true。
- `isEnabled(_ target: ConfirmationTarget) -> Bool` と `setEnabled(_:for:)` で読み書きする。
- 旧プロパティ `confirmBeforeFileOperations` は削除する（呼び出し元はすべて置き換える）。

## ConfirmationPolicy（変更、FolzioCore）

| 操作（`FileOperation.Kind`） | 始めたペイン | `target` |
|---|---|---|
| `copy` | どちらも | `copy` |
| `move` | どちらも | `move` |
| `rename` | どちらも | `rename` |
| `trash` | どちらも | `trash` |

親ウインドウがないときは、確認がオンなら操作に関わらず `runModal` で確認する（EC-263、research.md R5）。

## 読み込みの規則（SettingsStore）

1. 新しいキーが Bool で保存済みなら、その値を使う。
2. なければ、`copy`・`removeFavorite`・`trash` は旧キー `fileOps.confirmBeforeExecuting` が Bool ならその値、
   そうでなければ true。
3. `move`・`rename` は、新しいキーがなければ true。
4. 書き込みは5つの新しいキーにだけ行う。書き込んだら `confirmationOptionsDidChange` を送る。

## 見直し（GUI の確認の前）

当初はツリーのフォルダのゴミ箱を `target == nil`（常に確認）としていた。保守者の見直しで、ツリーのフォルダのゴミ箱も
`trash` に従うようにした。すべての確認モーダルが `ConfirmationTarget` を持つ（`target(for:origin:)` は nil を返さない）。
