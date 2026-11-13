# Contract: ツールバーの検索欄と名前の絞り込み（TAK-86）

実装と検証の後に、`specs/product/contracts/` の3つのファイルへ反映する内容。

## 設定（contracts/settings.md）

- `view.toolbarItems` の識別子に `nameFilter` を加える。
  - 取り得る値: `history`・`paneLayout`・`slideshow`・`previewZoom`・`mediaTypeFilter`・`zipVisibility`・`viewMode`・`thumbnailSize`・`nameFilter`・
    `NSToolbarSpaceItem`・`NSToolbarFlexibleSpaceItem`
- 既定の並び: `history` → `paneLayout` → `slideshow` → `previewZoom` → `mediaTypeFilter` → `zipVisibility` → `viewMode` → `thumbnailSize` →
  `NSToolbarFlexibleSpaceItem` → `nameFilter`
- 保存と読み込みの規則は変えない
- 検索欄の文字と名前の絞り込みは保存しない。新しいキーは追加しない
- ショートカットの割り当ての保存値に、コマンド `filterByName` が加わる。保存の形式は変えない

## キーボードとメニュー（contracts/keyboard-and-menus.md）

### メニューと割り当てを変更できるコマンド

| ID | メニュー | 既定のキー | 動作 | 有効の条件 |
|---|---|---|---|---|
| `filterByName` | ファイル > 名前で絞り込む | ⌥⌘F | ツールバーの検索欄へフォーカスを移す。隠れていればツールバーを表示する（FR-391） | 下記 |

- 有効の条件: 検索のモーダルを開ける条件（FR-388）を満たし、検索欄がツールバーにあり、ツールバーが文字だけの形式でない
- 割り当てを変更できるコマンドは 33 個になる。設定ウインドウとショートカット一覧では「検索…」の直後に置く

### ツールバーの検索欄

| 操作 | 動作 | 有効の条件 |
|---|---|---|
| 文字の入力・削除 | 入力のたびに、表示中の一覧を名前で絞り込む（FR-381） | FR-388 |
| ×ボタン・Esc | 検索欄の文字を消し、絞り込みを解除する（FR-383） | 文字があるとき |
| Return | 絞り込みを保ったまま、ファイルリストへフォーカスを移す（FR-389） | FR-388 |
| 虫眼鏡を押す | 検索のモーダルを開く。検索欄の文字を引き継ぐ（FR-390） | FR-388 |
| 検索欄にフォーカスがある間の ⌘F | 虫眼鏡と同じ（FR-390） | FR-388 |
| あふれたメニュー・文字だけの形式の「絞り込み」 | 検索のモーダルを開く（FR-392） | FR-388 |

- 検索欄にフォーカスがある間、ファイル操作のショートカットはファイルリストとツリーの選択を対象にしない（EC-257）
- ファイルリストでの Esc は、従来どおり検索結果の解除だけを行う（A-230）

## 文言（contracts/localization.md）

| キー | 用途 | 日本語 | 英語 |
|---|---|---|---|
| `menu.file.filterByName` | 「ファイル」メニューの項目。設定ウインドウのコマンドの名前を兼ねる | 名前で絞り込む | Filter by Name |
| `toolbar.nameFilterLabel` | セットのラベル（カスタマイズ画面・文字だけの形式・あふれたメニュー） | 絞り込み | Filter |
| `toolbar.nameFilterPlaceholder` | プレースホルダとアクセシビリティのラベル | 名前で絞り込み | Filter by Name |
| `toolbar.nameFilterHelp` | 検索欄のツールチップ。値はショートカットの表記 | 名前で絞り込む（⌥⌘F） | Filter by Name (⌥⌘F) |
| `toolbar.nameFilterFindHelp` | 虫眼鏡のツールチップとアクセシビリティのラベル。値はショートカットの表記 | 検索…（⌘F） | Find… (⌘F) |
| `empty.nameFilterNoMatches` | 絞り込みで1行も表示されないときのメッセージ。値は入力した文字 | “{文字}”に一致する項目はありません | No items match “{文字}” |
| `shortcuts.entry.filterByName` | ショートカット一覧の説明 | 表示中の一覧を名前で絞り込む | Filter the displayed list by name |
| `shortcuts.condition.filterByName` | ショートカット一覧の条件 | 名前の編集中・全画面中・プレビューのみ表示中は使えません。 | Unavailable while renaming, in full screen, or in preview-only view. |

| `search.heading` | 検索シートの冒頭の見出し（FR-394） | サブフォルダを含めて検索 | Search Including Subfolders |
| `search.description` | 見出しの下の補足説明。キーワード欄のアクセシビリティの説明を兼ねる（FR-394） | 検索起点ディレクトリとその下のすべてのサブフォルダから、名前が一致するファイルとフォルダを探します。 | Finds files and folders whose names match, in the folder you search in and all of its subfolders. |

- ショートカットの表記は、現在の割り当て（コマンド `filterByName`・`find`）に従う。未設定のときの表記は、ほかのツールバーのツールチップと同じ（FR-237・FR-268）
- 入力した文字は翻訳・変形しない（FR-147（overview.md）の検索キーワードと同じ扱い）
