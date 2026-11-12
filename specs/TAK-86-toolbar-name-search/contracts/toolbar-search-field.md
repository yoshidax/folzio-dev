# Contract: ツールバーの検索欄（TAK-86）

実装と検証の後に、`specs/product/contracts/` の3つのファイルへ反映する内容。

## 設定（contracts/settings.md）

- `view.toolbarItems` の識別子に `search` を加える。
  - 取り得る値: `history`・`paneLayout`・`slideshow`・`previewZoom`・`mediaTypeFilter`・`zipVisibility`・`viewMode`・`thumbnailSize`・`search`・
    `NSToolbarSpaceItem`・`NSToolbarFlexibleSpaceItem`
- 既定の並び: `history` → `paneLayout` → `slideshow` → `previewZoom` → `mediaTypeFilter` → `zipVisibility` → `viewMode` → `thumbnailSize` →
  `NSToolbarFlexibleSpaceItem` → `search`
- 保存と読み込みの規則は変えない（既定の並びと同じなら保存しない。未知の識別子を含む値は既定の並び。重複したセットは最初の1つ。空の配列はそのまま）
- 検索欄の文字と検索条件は保存しない。新しいキーは追加しない

## キーボードとメニュー（contracts/keyboard-and-menus.md の「ツールバー」）

| セット | 操作 | 動作 | 有効の条件 |
|---|---|---|---|
| 検索 | 検索欄で Return | 検索欄の文字で、一覧のフォルダを起点に検索する（FR-382・FR-383） | FR-388 |
| 検索 | 虫眼鏡を押す | 検索のモーダルを開く。検索欄の文字を引き継ぐ（FR-386） | FR-388 |
| 検索 | 検索欄にフォーカスがある間の ⌘F | 虫眼鏡と同じ（FR-386） | FR-388 |
| 検索 | ×ボタン・Esc | 検索欄の文字を消す。検索結果は解除しない（FR-381・EC-257） | 文字があるとき |
| 検索 | あふれたメニュー・文字だけの形式の「検索」 | 検索のモーダルを開く（FR-389） | FR-388 |

- 検索欄へフォーカスを移すショートカットとメニュー項目は追加しない（A-228）
- 検索欄にフォーカスがある間、ファイル操作のショートカットはファイルリストとツリーの選択を対象にしない（EC-258）
- 割り当てを変更できるコマンドの数（32）とショートカット一覧の内容は変えない

## 文言（contracts/localization.md）

| キー | 用途 | 日本語 | 英語 |
|---|---|---|---|
| `toolbar.searchLabel` | セットのラベル（カスタマイズ画面・文字だけの形式・あふれたメニュー） | 検索 | Search |
| `toolbar.searchPlaceholder` | プレースホルダとアクセシビリティのラベル | 名前で検索 | Search by Name |
| `toolbar.searchFindHelp` | 虫眼鏡のツールチップとアクセシビリティのラベル。値はショートカットの表記 | 検索…（⌘F） | Find… (⌘F) |

- ショートカットの表記は、現在の割り当て（コマンド `find`）に従う。未設定のときの表記は、ほかのツールバーのツールチップと同じ（FR-237・FR-268）
- 起点の検証の理由は、検索のモーダルの既存の文言を使う。新しい文言は追加しない
