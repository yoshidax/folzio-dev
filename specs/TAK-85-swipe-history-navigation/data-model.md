# Data Model: TAK-85 スワイプのジェスチャで履歴を戻る・進む

保存するデータはない。以下は、FolzioCore に置く一時的な値と状態（`Sources/FolzioCore/History/SwipeNavigation.swift`）。
名前は設計の案で、実装で変えてよい。

## 向きの扱い

向きは、目的ごとに 1 つの情報源から決める（2 つの情報源を突き合わせない）。

| 目的 | 情報源 | 規則 |
|---|---|---|
| 横スクロールの余地の判定（FR-351） | スクロールの `scrollingDeltaX` の符号 | `> 0` は内容が右へ動き左側が見える向き（`revealsLeft`）、`< 0` は右側が見える向き（`revealsRight`）。OS のスクロールの方向の設定を反映した値で、ビューのスクロールと同じ向きになる |
| 戻る・進むと矢印（FR-350・FR-352） | `trackSwipeEvent` の `gestureAmount` の符号 | `> 0` を `back`、`< 0` を `forward`（research.md の R4。実機で確かめる） |
| 3 本指のスワイプ（EC-242） | `.swipe` のイベントの `deltaX` の符号 | `> 0` を `back`、`< 0` を `forward`、0 は対象外（R2。実機で確かめる） |

- 戻る・進むの向きは、既存の `HistoryDirection`（`Sources/FolzioCore/History/HistoryEntry.swift:97`、`back` / `forward`）を使い、新しい型を作らない。
- `gestureAmount` と `deltaX` から `HistoryDirection` への対応は、それぞれ 1 つの関数にする（実機の確認で逆と分かったとき、直すのは 1 か所）。

## ScrollReveal

横スクロールの向き。`revealsLeft` / `revealsRight`。

## HorizontalScrollRoom

ポインタの下のペインが、左右にあとどれだけスクロールできるか。

| 項目 | 意味 |
|---|---|
| `canRevealLeft` | 左側にまだ隠れた内容があり、`revealsLeft` の向きにスクロールできる |
| `canRevealRight` | 右側にまだ隠れた内容があり、`revealsRight` の向きにスクロールできる |

- `init(visibleMinX:visibleMaxX:contentMinX:contentMaxX:)`: 見えている範囲と内容の範囲から求める。差が 0.5pt 以下なら端に着いているとする。
- `none`: 左右どちらにも余地がない（EC-243）。
- `allows(_ reveal: ScrollReveal) -> Bool`: その向きにスクロールできるか。
- `PreviewScrollLayout` に、表示中の画像の余地を返す `horizontalRoom(viewportWidth:)` を加える（`frame.minX < 0` で左、`frame.maxX > viewportWidth` で右）。

## ScrollSample

App が `NSEvent` から作る、1 つのスクロールのイベントの値。Core は `NSEvent` を知らない。

| 項目 | 意味 |
|---|---|
| `phase` | `began` / `changed` / `ended` / `cancelled` / `ignored` / `none` |
| `isMomentum` | 慣性のイベント（`momentumPhase` が空でない）|
| `deltaX`・`deltaY` | `scrollingDeltaX`・`scrollingDeltaY` |
| `timestamp` | `NSEvent.timestamp`（秒）。慣性の途中かどうかの判定に使う |

`NSEvent.Phase` からの対応:

| `NSEvent.Phase` | `phase` |
|---|---|
| `.began` | `began` |
| `.changed`・`.stationary` | `changed`（`.stationary` は動きが 0 なので向きを決めない）|
| `.ended` | `ended` |
| `.cancelled` | `cancelled` |
| `.mayBegin` | `ignored`（指を置いただけ。状態を変えず、そのまま渡す）|
| 空（`phase` のないマウスホイール、慣性のイベント）| `none` |

## SwipeAvailability

追跡を始めるかどうかの判定に使う。追跡を終えるときの判定は、既存の `goBack(_:)` / `goForward(_:)` の guard（`MainSplitViewController.swift:1054-1063`）に任せる。

| 項目 | 意味 |
|---|---|
| `isSwipeTrackingEnabled` | システム設定でスクロールの動きのスワイプが有効（`NSEvent.isSwipeTrackingFromScrollEventsEnabled`）|
| `canGoBack`・`canGoForward` | `paneCommands.canNavigateHistory` と `historyNavigator.canGoBack` / `canGoForward` の AND |

- `trackSwipeEvent` の `dampenAmountThresholdMin` は `canGoForward ? -1 : 0`、`max` は `canGoBack ? 1 : 0` とする。使えない向きには量が伸びず、矢印も出ない（FR-352・US7-AS21）。

## SwipeGestureTracker（状態）

1 回のスクロール（`began` から `ended` / `cancelled`、続く慣性まで）ごとの状態。

| 状態 | 意味 | 次の状態 |
|---|---|---|
| `idle` | スクロールの外 | `began` で `pending(room)` |
| `pending(room)` | 始まりの余地を記録し、決める前 | `began` / `changed` の左右が主の動きで `swiping` または `scrolling`。上下が主の動きで `scrolling`。`began` のイベント自体に動きがあれば、そのイベントで決める。動きのないまま `ended` / `cancelled` で `idle` |
| `scrolling` | この 1 回は普通のスクロール | 次の `began` で `pending`（慣性の途中なら `scrolling` のまま。下の規則）|
| `swiping` | AppKit の追跡に渡した | App が `finishSwipe()` を呼ぶと `afterSwipe`。次の `began` が来たら、`finishSwipe()` の前でも `pending` |
| `afterSwipe` | 追跡は終わったが、同じジェスチャの慣性が残る | 次の `began` で `pending`。慣性でないイベント（`phase` が `none` で `isMomentum` が false のマウスホイールなど）で `idle` |

`handle(_ sample: ScrollSample, availability: SwipeAvailability, target: SwipeTarget?) -> SwipeDecision` の結果。
`SwipeTarget` は、`began` のときのポインタの下のペイン（既存の `Pane`。`Sources/FolzioCore/Model/PaneLayout.swift:3`）と、そのペインの `HorizontalScrollRoom` の組。
`target` は、`began` のときだけ App が渡す。`began` が対象の外（3 ペインの外・シート・モーダル・ドラッグの途中。EC-244・EC-245）なら `nil` を渡し、
その 1 回は `scrolling`（終わりまで `passThrough`）にする。`began` 以外のイベントでは、App は対象の判定をせずに渡す（値は使わない）。

| 結果 | App の動作 |
|---|---|
| `passThrough` | イベントをそのままビューに渡す |
| `startSwipe` | `trackSwipeEvent` を始め、イベントを渡さない |
| `consume` | イベントを渡さない |

規則:

- どの状態でも、`began` を受け取ったら `pending(room)` から判定し直す。
  - 前のスワイプの追跡が終わっていない（`finishSwipe()` の前）、または終わらなかった場合でも、状態が残らないようにするため（EC-241）。
  - App は、前の追跡の handler の後からの呼び出しを、通し番号で無視する。
  - App は、判定し直すときに矢印を隠す（前の追跡の終わりが届かなくても、矢印を残さない）。
- 向きと `startSwipe` の判定に使うのは、`phase` が `began` / `changed` で `isMomentum` が false のイベントだけ。`pending` で `phase` が `none` のイベント
  （マウスホイール・横ホイール）は、状態を変えずに `passThrough`（ジェスチャでないイベントで `trackSwipeEvent` を呼ばない）。
- 慣性の途中に始めたスクロール: `scrolling` の状態で `passThrough` にした（ビューへ渡した）慣性のイベントについて、そのスクロールのペインと最後の `timestamp`
  を覚える。同じペインで、その `timestamp` から 0.1 秒以内に `began` を受け取ったら、そのスクロールは `pending` にせず `scrolling` にする
  （spec の FR-351。慣性のイベントは画面の更新ごとに届くため、0.1 秒以内なら慣性で表示が動いている途中と見なす）。
  - `swiping`・`afterSwipe` で `consume` した慣性（表示を動かしていない）は覚えない。スワイプの直後に続けて始めたスワイプを妨げないため（EC-241）。
  - 別のペインで始めたスクロールには使わない（そのペインの表示は動いていない）。
  - この 0.1 秒は、スワイプの成立の判定（OS に任せる）ではなく、慣性が続いているかの判定に使う。
- 1 回のスクロールの途中でポインタがペインの外（境界線・ツールバー）へ動いても、そのスクロールのイベントは終わりまで判定を続ける（対象かどうかは `began` のときだけ決める）。
- `pending` から `swiping` にするのは、次をすべて満たすときだけ。
  - `isSwipeTrackingEnabled` が true。
  - `isMomentum` が false で、|deltaX| > |deltaY|（EC-239）。
  - `canGoBack` または `canGoForward` が true（US7-AS21）。
    - 戻る・進むの向きは追跡が始まるまで分からないため（「向きの扱い」）、片方だけが使えるときも追跡する。使えない向きは量が 0 のままで、何も起きない。
    - このとき、その 1 回の上下の動きもビューに渡さない（EC-239 の「左右が主の動きはスワイプとして扱う」の結果。spec の EC-239 に明記）。
  - `room.allows(reveal)` が false（FR-351。`reveal` は `deltaX` の符号、`room` は `began` のときに記録したもの）。
- それ以外の左右・上下の動きは `scrolling` にし、その 1 回の終わりまで `passThrough`（US7-AS18・US7-AS19）。
- `swiping` の間のイベントは `consume`。ただし、同じジェスチャの `ended` / `cancelled`（慣性でないもの）は `passThrough` にして、`began` を受け取ったビュー
  （`NSScrollView`）にスクロールの終わりを渡す（始まりだけを受け取ったビューの状態を残さない。research.md の R4）。`afterSwipe` の間は、慣性のイベント（`isMomentum` が true）だけを `consume` する（移った先の一覧を残りの慣性で動かさない）。
  慣性でないイベントを受け取ったら `idle` に戻し、そのイベントは `passThrough`（マウスホイールのスクロールを止めない）。
- `phase` が `ignored` のイベントは、状態を変えずに `passThrough`。
- `idle` で `phase` が `none` のイベント・`began` を受け取っていないイベントは、`passThrough`。

## 追跡の終わり

- `trackSwipeEvent` の handler の `phase` が `.ended` のとき、最後の `gestureAmount` の符号の向き（「向きの扱い」の表）で `goBack(_:)` / `goForward(_:)` を 1 回呼ぶ。
  使えるかどうかの再判定（EC-240）は、その guard が行う。
- `.cancelled` のときは、何もしない（US7-AS16）。
- `isComplete` が true になったら `finishSwipe()` を呼ぶ。

## SwipeArrowState

`init(gestureAmount:)` で求める。

| 項目 | 意味 |
|---|---|
| `direction` | `gestureAmount` の符号の向き。`back` は左端に左向き、`forward` は右端に右向き（指の向き・スクロールの方向の設定によらない。FR-352）|
| `progress` | `abs(gestureAmount)` を 0〜1 に収めたもの。大きさと不透明度に使う |
| `isVisible` | `progress` が 0 より大きいとき true。使えない向きでは量が 0 のままなので出ない |

- 3 本指のスワイプでは、`progress` を 1 にして短い時間だけ表示する（EC-242）。
