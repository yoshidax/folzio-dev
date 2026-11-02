# Data Model: ツールバーのカスタマイズ

## ToolbarItemKind（App 内の識別）

識別子は現行どおり（`history`、`paneLayout`、`slideshow`、`previewZoom`、`mediaTypeFilter`、`zipVisibility`、`viewMode`、`thumbnailSize`）。標準の項目として
`NSToolbarItem.Identifier.space`・`.flexibleSpace` を許可する。識別子の文字列は保存値に現れるため、変更しない。

## ToolbarLayout（Core、新規。R-3 の段3、段2 の検証に使う純粋な値）

| 項目 | 内容 |
|---|---|
| `allowed` | 許可する識別子の集合（8種＋スペース2種） |
| `defaultOrder` | 既定の並び（FR-006）。末尾に `flexibleSpace` |
| `normalized(saved:)` | 保存した識別子の配列を受け取り、未知の識別子を除き、セットの重複（R-4 で不可と分かった場合）を除いた配列を返す。結果が空・不正のときは `defaultOrder` |

検証規則: 空配列・型が配列でない値は、既定の並びを返す（FR-005）。未知の識別子を1つでも含む配列は不正な値として、既定の並びを返す（FR-005）。同じセットの重複は最初の1つだけ残す（標準では `NSToolbarItem.allowsDuplicatesInToolbar` が既定で `false` の見込みで、実機の確認は T011）。スペース類は複数回出現してよい。ユーザーが外したセットは、保存した並びに無くてもそのまま外れたままにする。実装は `Sources/FolzioCore/Settings/ToolbarLayout.swift`。

## 保存キー（R-3 の結果で1つだけ追加）

| キー | 型 | 備考 |
|---|---|---|
| `view.toolbarConfiguration` | plist 化した辞書 | R-3 の段2。`isVisible` は含めても復元時に使わない |
| `view.toolbarItems` | 文字列の配列 | R-3 の段3 |
| （追加なし） | | 段1で標準の自動保存が直った場合。`NSToolbar Configuration MainToolbar` は AppKit が管理 |

既存の `view.showsToolbar`（表示状態）は変えない。
