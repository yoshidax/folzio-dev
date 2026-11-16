# Contract 変更: 表示言語・翻訳（specs/product/contracts/localization.md）

設定ウインドウの対訳表の確認の2行を、次の6行に置き換える。

| 日本語 | 英語 |
|---|---|
| コピーする前に確認する | Confirm before copying |
| 移動する前に確認する | Confirm before moving |
| 名前を変更する前に確認する | Confirm before renaming |
| お気に入りから削除する前に確認する | Confirm before removing from Favorites |
| ゴミ箱に入れる前に確認する | Confirm before moving to the Trash |
| ツリーのフォルダをゴミ箱に入れる操作は、この設定に関わらず常に確認します（確認の補足説明。アクセシビリティのヘルプにも使う） | Moving folders in the directory tree to the Trash is always confirmed, regardless of this setting |

翻訳キー（`Localizable.strings`）は `settings.confirm.copy`・`settings.confirm.move`・`settings.confirm.rename`・
`settings.confirm.removeFavorite`・`settings.confirm.trash`・`settings.confirm.note` とし、`settings.confirm` は削除する。
確認モーダルの「今後この確認を表示しない」（`dialog.confirm.dontAsk`）の文言は変えない。
