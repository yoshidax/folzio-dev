# Data Model: TAK-86 ツールバーの名前検索欄

永続化するデータは増えない。既存の保存値 `view.toolbarItems` が取り得る識別子に `search` が加わるだけ（contracts/toolbar-search-field.md）。

## ToolbarLayout（変更。`Sources/FolzioCore/Settings/ToolbarLayout.swift`）

| 項目 | 変更前 | 変更後 |
|---|---|---|
| `setIdentifiers` | 8つのセット | 8つのセット + `search`（末尾） |
| `defaultOrder` | 8つのセット → `NSToolbarFlexibleSpaceItem` | 8つのセット → `NSToolbarFlexibleSpaceItem` → `search` |
| `allowed` | 8つのセット + スペース2種 | 9つのセット + スペース2種 |
| `normalized(saved:)` | — | 規則は変えない |

- `defaultOrder` は `setIdentifiers + [flexibleSpaceIdentifier]` では作れなくなるので、並びを明示して書く
- `normalized(saved:)` の結果（FR-390・EC-165）:
  - `search` を含まない有効な保存値は、そのまま返す（検索欄を足さない）
  - `search` を含む有効な保存値は、そのまま返す。`search` の重複は最初の1つだけ残す（ほかのセットと同じ）
  - 保存値がない・壊れているときは、新しい `defaultOrder` を返す

## ToolbarSearchInput（追加。`Sources/FolzioCore/Search/ToolbarSearchInput.swift`）

検索欄の文字から、検索のモーダルへ引き継ぐキーワードを決める値の計算。状態を持たない。AppKit を import しない。

| 関数 | 入力 | 結果 |
|---|---|---|
| `modalKeyword(fieldText:previousKeyword:)` | 検索欄の文字、前回検索したキーワード（なければ `nil`） | モーダルのキーワード欄に入れる文字（なければ `nil`） |

- 検索欄の文字が、前後の空白と改行を除いて1文字以上なら、検索欄の文字を返す（FR-386）
  - 返すのは前後の空白を除いた文字とする（`SearchPattern(keyword:)` が照合に使う文字と同じにする）
- それ以外（空・空白だけ）は、`previousKeyword` をそのまま返す（⌘F と同じ。FR-081（search.md））

Return での検索のキーワードは、既存の `SearchPattern(keyword:)` で作る（空・空白だけなら `nil` で、何もしない。FR-382）。新しい型は作らない。

## 検索欄の状態（保存しない）

| 状態 | 決まり方 | 根拠 |
|---|---|---|
| 文字 | ユーザーの入力・×ボタン・Esc だけで変わる。検索・モーダル・検索結果の解除では変えない | FR-381・FR-387 |
| 有効・無効 | `PaneCommands.canSearch`（⌘F と同じ） | FR-388 |
| 起点 | Return の時点の `BrowserModel.listing.folder`（モーダルの既定の起点と同じ） | FR-383 |

- 項目を外して再び追加した場合と、再起動の後は、文字は空で始まる（EC-254）。項目ごとに新しいフィールドを作る既存の構成のままにする

## 検索の開始までの流れ（Return）

1. `SearchPattern(keyword: 検索欄の文字)` が `nil`、または `canSearch` が偽なら、何もしない
2. `listing.folder` を起点の候補として控え、`SearchRoot.validate(_:)` を呼ぶ（UI スレッドの外）
3. 検証が終わった時点で、`listing.folder` が控えた値と同じ・`canSearch` が真・メインウインドウにシートがない、を確かめる。満たさなければ何もしない
4. 成功: 前回のキーワードを更新し（FR-385）、`BrowserModel.startSearch(_:root:)` を呼び、ファイルリストへフォーカスを移す
5. 失敗: 検索のモーダルを、キーワード・起点のパス・理由を入れて開く（FR-384）。前回のキーワードは更新しない
