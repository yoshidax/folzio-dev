# Data Model: TAK-86 ツールバーの検索欄による名前の絞り込み

永続化するデータは増えない。既存の保存値が取り得る値に、ツールバーの識別子 `nameFilter` とコマンド `filterByName` が加わるだけ（contracts/toolbar-name-filter.md）。

## NameFilter（追加。`Sources/FolzioCore/Model/NameFilter.swift`）

値型（`Sendable`・`Equatable`）。AppKit を import しない。

| 項目 | 内容 |
|---|---|
| `text` | 検索欄に入力された文字（そのまま。前後の空白を含む） |
| `pattern` | `SearchPattern(keyword: text)`。前後の空白を除いて空なら `nil` |
| `isFiltering` | `pattern != nil` |
| `apply(to:)` | `isFiltering` でなければ入力をそのまま返す。そうでなければ、`pattern.matches(fileName: file.name)` が真の項目だけを返す |

- 対象は、渡された項目のすべての種類（メディア・フォルダ・zip ファイル・zip の中のディレクトリ）。`..` の行は `allFiles` に含まれないので、渡されない（FR-381）
- `Equatable` は `text` で比べる

## BrowserModel（変更。`Sources/FolzioCore/Browser/BrowserModel.swift`）

| 項目 | 内容 | 根拠 |
|---|---|---|
| `nameFilter`（読み取り専用の公開の状態） | 現在の名前の絞り込み。既定は空 | FR-381 |
| `nameFilterHidesAllRows`（読み取り専用の公開の状態） | 名前の絞り込みの前には行があり、後には1行もないとき真 | FR-386 |
| `setNameFilter(_ text: String)` | 文字が同じなら何もしない。変えたら、種類フィルタと同じく一覧を作り直し、選択を表示中の行に限る | FR-381・FR-385 |
| `resetForNavigation()` | 名前の絞り込みを空にする | FR-384 |
| `rebuildListing()` | 種類フィルタ → zip の表示 → 名前の絞り込みの順に適用する | FR-381・FR-382 |

### rebuildListing() の状態の決め方

1. `visible` = 種類フィルタと zip の表示を適用した行（従来の `filtered`）
2. `named` = `nameFilter.apply(to: visible)`。表示する行は `..` + `named`
3. 検索中で `allFiles` が空なら `.loading`（従来どおり）
4. `nameFilter.isFiltering` で、`visible` が空でなく `named` が空なら、`state = .noMatches`、`nameFilterHidesAllRows = true`
5. それ以外は `nameFilterHidesAllRows = false` とし、従来の判定（`allFiles` の `hasMedia` と `visible` から `.empty`・`.noMatches`・`.loaded`）を行う

- 5 の判定に `named` ではなく `visible` を使うのは、名前の絞り込みで行が残る場合に、種類フィルタのメッセージの出方を変えないため（FR-386）

### setNameFilter の選択の扱い

`setMediaTypeFilter(_:)` と同じ処理（`selection.restricted(toVisible:)`。フォーカスが変わるときは `select(_:focused:)`）を使う。2つの関数で共用する関数にまとめる（FR-385）。

## ToolbarSearchInput（追加。`Sources/FolzioCore/Search/ToolbarSearchInput.swift`）

| 関数 | 入力 | 結果 |
|---|---|---|
| `modalKeyword(fieldText:previousKeyword:)` | 検索欄の文字、前回検索したキーワード（なければ `nil`） | モーダルのキーワード欄に入れる文字（なければ `nil`） |

- 検索欄の文字が、前後の空白と改行を除いて1文字以上なら、前後の空白を除いた文字を返す（FR-390）
- それ以外は `previousKeyword` をそのまま返す（⌘F と同じ）

## ToolbarLayout（変更。`Sources/FolzioCore/Settings/ToolbarLayout.swift`）

| 項目 | 変更前 | 変更後 |
|---|---|---|
| `setIdentifiers` | 8つのセット | 8つのセット + `nameFilter`（末尾） |
| `defaultOrder` | 8つのセット → `NSToolbarFlexibleSpaceItem` | 8つのセット → `NSToolbarFlexibleSpaceItem` → `nameFilter` |
| `normalized(saved:)` | — | 規則は変えない |

- `nameFilter` を含まない有効な保存値は、そのまま返す（検索欄を足さない。FR-393）

## ShortcutCommands（変更。`Sources/FolzioCore/Shortcuts/`）

| ID | 既定のキー | 区分 | メニュー |
|---|---|---|---|
| `filterByName` | ⌥⌘F | 検索 | ファイル > 名前で絞り込む（「検索…」の直後） |

- コマンドの数は 32 から 33 になる。設定ウインドウとショートカット一覧では、`find` の直後に置く

## 検索欄の状態（保存しない）

| 状態 | 決まり方 | 根拠 |
|---|---|---|
| 文字 | モデルの `nameFilter.text` と同じ。ユーザーの入力・×ボタン・Esc と、モデルの解除で変わる | FR-383・FR-384 |
| 有効・無効 | `PaneCommands.canSearch`（⌘F と同じ） | FR-388 |
