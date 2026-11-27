# Data Model: 複数の検索起点

すべて `FolzioCore`（AppKit を import しない）に置く値型・関数。保存しない。

## 1 SearchRootInput（既存・変更なし）

1行の起点欄の値と由来。`.typed(String)`（直接入力）か `.picked(URL)`（GUI 選択）。解釈は `resolvedInput(home:)`。

## 2 SearchPanelInputState（変更）

検索シートの入力と非同期の操作の調停。単一の `rootInput` を行の並びに広げる。

| フィールド | 型 | 説明 |
|---|---|---|
| `rootInputs` | `[SearchRootInput]` | 起点の行の値。1〜10 個。初期値は既定値の `.typed` 1個 |
| `keyword` | `String` | 既存 |
| `revision` | `Int` | 既存。行の追加・削除・各行の編集・GUI 選択の反映・キーワードの編集で増やす |
| `isActive`・`pendingOperation`・`requestGeneration` | 既存 | 既存 |
| `maximumRows` | `static let = 10` | FR-435 |

操作（MainActor から直列に呼ぶ。I/O なし）:

- `updateRootText(_:at:)`: その行だけを `.typed` にする。
- `applyPickedRoot(_:at:)`: その行だけを `.picked` にする。
- `addRow(panelPresented:) -> Int?`: 10 行未満で、標準パネルを表示しておらず、`pendingOperation == .idle` のときに、末尾に空の
  `.typed("")` を加えて添字を返す。それ以外は `nil`（FR-435）。
- `removeRow(at:panelPresented:) -> Int?`: 2 行以上のときに取り除き、フォーカスを移す行の添字（同じ位置、末尾なら1つ前）を返す。条件は `addRow` と同じ。
- `canAddRow`・`canRemoveRow`: ボタンの有効・無効の判定。
- `beginInitialLocationResolution(row:panelPresented:)`・`beginSelectionValidation(_:row:panelPresented:)`: チケットに行の添字を持たせる。
- `beginSearchValidation(panelPresented:)`: チケットに `rootInputs` 全体を持たせる。
- `complete(_:succeeded:)`: 既存の判定（revision・requestGeneration・操作の種類）。行の追加・削除で revision が変わるので古い完了は捨てる。

`SearchPanelOperationTicket` は `input`（1行）を `inputs: [SearchRootInput]` と `row: Int?` に替える。

## 3 SearchRootList（新規）

行の検証と起点の整理（FR-436・FR-437）。

```text
enum SearchRootList {
    struct Failure: Error, Equatable { row: Int; rowCount: Int; error: SearchRootError }
    /// 空白だけの行を除き、上から解釈・検証する。最初の無効な行で失敗。すべて空なら row 0 の .empty。
    static func validate(_ inputs: [SearchRootInput], home: URL,
                         validate: (URL) async -> Result<URL, SearchRootError>) async -> Result<[URL], Failure>
    /// 同じフォルダをまとめ、別の起点の列挙で辿られる配下の起点を除く。入力の順を保つ。
    static func organize(_ roots: [URL], isSkipped: (URL) -> Bool) -> [URL]
    /// isSkipped の既定: 名前が "." で始まる・isHidden・isPackage（UI のスレッドの外で呼ぶ）
    static func isSkippedByEnumeration(_ url: URL) -> Bool
}
```

- 空白だけの行: `.typed` で前後の空白を除いて空のもの。`.picked` は空にならない。
- `Failure.row` は元の行の添字（空の行を数えた位置）。`rowCount` は表示する行の数（1 なら行の番号を付けない。FR-436）。
- `organize` の配下の判定は research.md R2。

## 4 SearchListing（変更）

| フィールド | 変更 | 説明 |
|---|---|---|
| `roots` | `root: URL` を置き換え | 整理した起点。1 個以上。名前の変更で置き換わる |
| `keyword`・`phase`・`totalCount` | なし | 既存 |

- `root(containing:) -> URL?`: 項目を含む起点のうちパスが最も長いもの（research.md R5）。
- `location(of:) -> String`: 含む起点で計算する。含む起点のフォルダ名が他の起点と（大文字小文字を区別せずに）同じなら、起点の絶対パスから。
- `rootSummary -> RootSummary`: 検索バーの材料。`.single(name)`（ルートは `/`）か `.multiple(firstName, others: Int)`。
- `rootPaths -> [String]`: ツールチップの全起点の絶対パス。

## 5 SearchRootPlan（新規）

順に辿る起点の待ち行列（FR-438・R3・R4）。`BrowserModel` が持つ。

| フィールド | 型 | 説明 |
|---|---|---|
| `pending` | `[URL]` | まだ列挙を始めていない起点（先頭が次） |

- `next() -> URL?`: 先頭を取り出す。
- `rebase(_ renamed: RenamedFolder) -> Bool`: 待ち行列の起点のうち、名前を変えたフォルダそのもの・その配下にあるものを新しいパスへ置き換える。
  置き換えたら `true`。
- `contains(_ url:) -> Bool`: 名前を変えたフォルダが待ち行列の起点の配下にあるか（追加の列挙を起こさない判定に使う）。
- `removeAll()`: 検索を止めるとき。

## 6 BrowserModel の状態の追加

- `searchRootPlan: SearchRootPlan`: 上記。
- `startSearch(_ pattern:, roots: [URL])`: `roots` は整理済み（空でない）。`listing.search = SearchListing(roots: roots, …)`、
  先頭の起点の列挙を始め、残りを待ち行列に入れる。
- 列挙の完了（`activeSearchStreams == 0`）で、待ち行列に起点があれば次の列挙を始め、なければ `.finished` にする。
