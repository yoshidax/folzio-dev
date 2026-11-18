# Contract delta: 英日表示

反映先: `specs/product/contracts/localization.md` の設定の対訳表。

| 用途 | TextKey | 日本語 | English |
|---|---|---|---|
| 区分 | `settingsFavorites` | お気に入り | Favorites |
| チェックボックス | `settingsRestoreFavoritesExpansion` | 起動時に前回の開閉状態を復元する | Restore previous expansion state on launch |

- リソースキーは `settings.favorites` と `settings.favorites.restoreExpansion` とする。
- チェックボックスのアクセシビリティラベルにも同じ翻訳を使う。
- 既存の `TextKey` の用途説明と英日カタログに追加する。
- 表示言語を切り替えてもチェック状態は変えず、文字と読み上げラベルだけを更新する。
