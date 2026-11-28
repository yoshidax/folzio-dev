# Data Model: TAK-129 の検索の性能

保存するデータは増やさない。`BrowserModel` の検索中の状態だけを足す。

## BrowserModel に足す状態

> **実装中の変更（2026-11-27）**: 下の表の `pendingSearchResults`（届いた結果をためて、反映の時刻にまとめて処理する）は、CI の性能テストで
> UI スレッドの止まりが 462ms に悪化したため（research.md R3）、`unlistedSearchResults`（`Int`。`allFiles` の末尾にあって、まだ画面の一覧に
> 出していない結果の件数）に置き換えた。結果は届くたびに索引と `allFiles` へ足し、画面の一覧への反映だけを間隔ごとにまとめる。
> 一覧を作り直すと 0 に戻す。そのほかの状態は表のとおり

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
      ├─ 検索を止める（FR-086・FR-140・新しい検索） → 並べ替えずに終わる（EC-312）
      └─ すべての列挙の終了 → ためた結果を反映 → UI スレッドの外で並べ替え
            ├─ kindFilesRevision が同じ → 適用。phase = finished、isSearchOrderPending = false、searchOrderGeneration を進める
            └─ 変わった → 並べ替えをやり直す
```

## 縮小画像の保持と要求（計測の後に追加。research.md R12）

| 名前 | 場所 | 意味 |
|---|---|---|
| `ThumbnailMemoryCache` | Core（`ThumbnailProvider` が持つ） | 上限 128MB。超えたら最後に使ったのが古いものから捨てる。メモリの不足の通知で空にする（FR-447） |
| `PlainFileURL.make(_:)` | Core（`FileNameSearcher`・`DirectoryLister`） | 列挙が返す URL を、同じバイト列から作り直す。`==` とハッシュは元と一致する |
| `thumbnailRequestDelay` | App（`ThumbnailModeView`） | 項目の表示・先読み・検索中のスクロールによる要求を待たせる時間（150ms。FR-446・A-275） |
| `pendingRequests` | App（`ThumbnailModeView`） | 待っている要求。範囲から外れたら取り消し、待ち終えたときに範囲に残っているものだけ要求する |

## 表示側の判定

| 条件 | ThumbnailModeView | ListModeView |
|---|---|---|
| 新しい URL の列が前の列で始まり、長くなった | `insertItems(at:)` で末尾だけ足す | `noteNumberOfRowsChanged()` |
| それ以外の変化 | `reloadData`（従来どおり） | `reloadData`（従来どおり） |
| `searchOrderGeneration` が進んだ | フォーカス項目か先頭を表示し、見えている項目を要求する | フォーカス行か先頭を表示する |
| 検索中（`phase == .searching`） | 先読みで要求しない。見えている項目以外の要求を取り消す | 変えない（今も見えている行だけ要求する） |
