# Data Model: TAK-85 スワイプのジェスチャで履歴を戻る・進む

保存するデータはない。以下は、FolzioCore に置く一時的な値と状態（`Sources/FolzioCore/History/SwipeNavigation.swift`）。
名前は設計の案で、実装で変えてよい。

## HistoryDirection

- `back` / `forward`。
- スクロールの `scrollingDeltaX > 0`（内容が右へ動き、左側が見える向き）を `back`、`< 0` を `forward` とする（research.md の R4）。
- 3 本指のスワイプの `deltaX > 0` を `back`、`< 0` を `forward` とする（R2。実機で確かめる）。

## HorizontalScrollRoom

ポインタの下のペインが、左右にあとどれだけスクロールできるか。

| 項目 | 意味 |
|---|---|
| `canRevealLeft` | 左側にまだ隠れた内容があり、`back` の向きにスクロールできる |
| `canRevealRight` | 右側にまだ隠れた内容があり、`forward` の向きにスクロールできる |

- `init(visibleMinX:visibleMaxX:contentMinX:contentMaxX:)`: 見えている範囲と内容の範囲から求める。差が 0.5pt 以下なら端に着いているとする。
- `none`: 左右どちらにも余地がない（EC-243）。
- `allows(_ direction: HistoryDirection) -> Bool`: その向きにスクロールできるか。
- `PreviewScrollLayout` に、表示中の画像の余地を返す `horizontalRoom(viewportWidth:)` を加える（`frame.minX < 0` で左、`frame.maxX > viewportWidth` で右）。

## ScrollSample

App が `NSEvent` から作る、1 つのスクロールのイベントの値。Core は `NSEvent` を知らない。

| 項目 | 意味 |
|---|---|
| `phase` | `began` / `changed` / `ended` / `cancelled` / `none`（`phase` のないマウスホイール）|
| `isMomentum` | 慣性のイベント（`momentumPhase` が空でない）|
| `deltaX`・`deltaY` | `scrollingDeltaX`・`scrollingDeltaY` |

## SwipeAvailability

| 項目 | 意味 |
|---|---|
| `isSwipeTrackingEnabled` | システム設定でスクロールの動きのスワイプが有効（`NSEvent.isSwipeTrackingFromScrollEventsEnabled`）|
| `canGoBack`・`canGoForward` | `paneCommands.canNavigateHistory` と `historyNavigator.canGoBack` / `canGoForward` の AND。シート・モーダルがあるときは両方 false（EC-244）|

## SwipeGestureTracker（状態）

1 回のスクロール（`began` から `ended` / `cancelled`、続く慣性まで）ごとの状態。

| 状態 | 意味 | 次の状態 |
|---|---|---|
| `idle` | スクロールの外 | `began` で `pending(room)` |
| `pending(room)` | 始まりの余地を記録し、向きを決める前 | 左右が主の動きで `swiping(direction)` または `scrolling`。上下が主の動きで `scrolling` |
| `scrolling` | この 1 回は普通のスクロール | `ended` / `cancelled` の後、次の `began` で `pending` |
| `swiping(direction)` | AppKit の追跡に渡した | 追跡の終わり（App が `finishSwipe()` を呼ぶ）で `idle` |

`handle(_ sample: ScrollSample, availability: SwipeAvailability, room: HorizontalScrollRoom) -> SwipeDecision` の結果:

| 結果 | App の動作 |
|---|---|
| `passThrough` | イベントをそのままビューに渡す |
| `startSwipe(direction)` | `trackSwipeEvent` を始め、イベントを渡さない |
| `consume` | 追跡中のイベントを渡さない |

規則:

- `pending` から `swiping` にするのは、次をすべて満たすときだけ。
  - `isSwipeTrackingEnabled` が true。
  - `isMomentum` が false で、|deltaX| > |deltaY|（EC-239）。
  - その向きが使える（`canGoBack` / `canGoForward`。US7-AS21）。
  - `room.allows(direction)` が false（FR-351。`room` は `began` のときに記録したもの）。
- それ以外の左右・上下の動きは `scrolling` にし、その 1 回の終わりまで `passThrough`（US7-AS18・US7-AS19）。
- `phase` が `none` のイベント・`began` を受け取っていないイベントは、`passThrough`。

## SwipeOutcome

追跡の終わりに App が Core に渡す、`trackSwipeEvent` の結果。

- `completed`（`phase` が `.ended`）: その時点の `SwipeAvailability` でもう一度判定し（EC-240）、使えれば `goBack` / `goForward` を 1 回呼ぶ。
- `cancelled`: 何もしない（US7-AS16）。

## SwipeArrowState

| 項目 | 意味 |
|---|---|
| `direction` | 矢印を出す側（`back` は左端、`forward` は右端。FR-352）|
| `progress` | `abs(gestureAmount)` を 0〜1 に収めたもの。大きさと不透明度に使う |
| `isVisible` | 追跡中は true。終わったら false |

- 3 本指のスワイプでは、`progress` を 1 にして短い時間だけ表示する（EC-242）。
