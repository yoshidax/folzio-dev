# Data Model: 設定ウインドウのセクション間隔の統一と確認オプションの補足説明の分離

新しい保存データ・保存キー・Core の型はない。`fileOps.confirmBeforeExecuting`（`ConfirmationOptions.confirmBeforeFileOperations`）の意味・既定値（true）・
読み込みの規則は変えない（`specs/product/contracts/settings.md`）。

## 翻訳の単位

| TextKey | キー | 種別 | 日本語 | 英語 | 説明（`TextKey` の英語の説明） |
|---|---|---|---|---|---|
| `settingsConfirm` | `settings.confirm` | 値の変更 | コピー・ゴミ箱に入れる・お気に入りから削除する前に確認する | Confirm before copying, moving to the Trash, or removing from Favorites | Checkboxes in the Settings window（既存のまま） |
| `settingsConfirmNote` | `settings.confirm.note` | 追加 | 名前の変更・移動と、ツリーのフォルダをゴミ箱に入れる操作は、この設定に関わらず常に確認します | Renaming, moving, and moving folders in the directory tree to the Trash are always confirmed, regardless of this setting | Supplementary note under the confirmation checkbox in the Settings window. Also its accessibility help |

- どちらも値（`%@` など）を持たない（`arguments` は空）。`Localizable.strings` に置き、`stringsdict` には置かない
- 主文に括弧書きの補足を残さない。補足説明は主文の末尾につながず、独立した文として表示する（`contracts/localization.md` §3 の「文の単位」）
