# Data Model: TAK-129 の検索の性能

保存するデータは増やさない。`BrowserModel` の検索中の状態だけを足す。

## BrowserModel に足す状態

| 名前 | 型 | 意味 |
|---|---|---|
| `pendingSearchResults` | `[MediaFile]` | 届いて、まだ一覧へ反映していない結果。反映の時刻に `allFiles` の末尾へ足す |
| `lastSearchReflection` | `ContinuousClock.Instant?` | 最後に反映した時刻。nil なら次に届いた結果をすぐに反映する |
| `searchReflectionTask` | `Task<Void, Never>?` | 次の反映の時刻に、ためた結果を反映するタスク。検索を止めたら取り消す |
| `searchOrderGeneration` | `Int`（観測される） | 検索の終了時の並べ替えを適用するたびに進む。表示側はこれでスクロールの位置を決める |
| `isSearchOrderPending` | `Bool` | 検索中で、`allFiles` が見つかった順（並べ替えていない）であること。名前の変更で行を動かさない判定に使う |

## 反映の間隔

```text
interval(count) =
  count <  1,000 → 0.1 秒
  count < 10,000 → 0.25 秒
  count < 30,000 → 0.5 秒
  それ以外       → 1.0 秒   （FR-085 の上限）
```

`count` は反映済みの件数（`allFiles.count`）。最初の結果（`count == 0`）はすぐに反映する。

## 検索の状態の移り変わり

```text
startSearch
  → searching（isSearchOrderPending = true。結果を見つかった順に末尾へ足す）
      ├─ 並べ替えの列・向きの変更 → その時点の結果を UI スレッドの外で並べ替えて適用（以後の結果は末尾へ）
      ├─ 検索を止める（FR-086・FR-140・新しい検索） → 並べ替えずに終わる（EC-302）
      └─ すべての列挙の終了 → ためた結果を反映 → UI スレッドの外で並べ替え
            ├─ kindFilesRevision が同じ → 適用。phase = finished、isSearchOrderPending = false、searchOrderGeneration を進める
            └─ 変わった → 並べ替えをやり直す
```

## 表示側の判定

| 条件 | ThumbnailModeView | ListModeView |
|---|---|---|
| 新しい URL の列が前の列で始まり、長くなった | `insertItems(at:)` で末尾だけ足す | `noteNumberOfRowsChanged()` |
| それ以外の変化 | `reloadData`（従来どおり） | `reloadData`（従来どおり） |
| `searchOrderGeneration` が進んだ | フォーカス項目か先頭を表示し、見えている項目を要求する | フォーカス行か先頭を表示する |
| 検索中（`phase == .searching`） | 先読みで要求しない。見えている項目以外の要求を取り消す | 変えない（今も見えている行だけ要求する） |
