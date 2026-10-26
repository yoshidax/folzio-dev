# Data Model: スライドショーのオプション設定

**Date**: 2026-10-26 | **Spec**: [spec.md](spec.md)

以下は設計上の型と責務。実装時の名前は対応関係を保てば調整してよい。Core の型は AppKit に依存しない。006 の型（[006 の data-model.md](../006-add-slideshow/data-model.md)）からの変更だけを記す。記していない型・規則は 006 のまま変えない。

## 1. 動作オプションのスライドショー設定 — SlideshowOptions（Core、新規）

spec の Key Entities「動作オプション」に加える3項目。`Model/Settings.swift` の `PlaybackOptions`・`ConfirmationOptions` と並べる。

| フィールド | 型 | 既定値 | 制約 |
|---|---|---|---|
| intervalSeconds | `Int` | 3 | `SlideshowOptions.intervalRange = 1...3600`。範囲外の値を持たない |
| repeats | `Bool` | `true` | 動画のループ再生（`PlaybackOptions.loop`）とは独立（FR-119） |
| transition | `SlideshowTransitionEffect` | `.none` | 4種類のいずれか |

`interval: Duration` は `.seconds(intervalSeconds)` として導出する。

### SlideshowTransitionEffect（Core、新規）

`String` の raw value を持つ enum。`none` / `crossfade` / `slide` / `zoom`。表示名（「なし」「クロスフェード」「スライド」「ズーム」）は App が持つ。

**Operations**:

- `effective(reduceMotion: Bool) -> SlideshowTransitionEffect`: `reduceMotion` が true なら `slide`・`zoom` を `crossfade` に置き換える。`none`・`crossfade` はそのまま返す（FR-131、US13-AS7）。

### 永続化 — SettingsStore.slideshow（Core、変更）

| キー | 型 | 既定値 | 読み込み時の検証（EC-75） |
|---|---|---|---|
| `slideshow.intervalSeconds` | Int | 3 | `NSNumber` で、`CFBoolean` ではなく、`Int` へ正確に変換でき、1〜3600。それ以外は 3 |
| `slideshow.repeats` | Bool | true | `as? Bool` で読めなければ true |
| `slideshow.transition` | String | `none` | 4つの raw value のいずれかでなければ `none` |

項目ごとに独立して検証する。1つが不正でもほかの項目は保存値を使う。書き込みは `nonmutating set` で3キーを書く。既存のキーと移行処理には触れない。

## 2. 間隔の入力 — SlideshowIntervalInput（Core、新規）

| 操作 | 入力 | 出力 |
|---|---|---|
| `parse(_ text: String) -> Int?` | テキストフィールドの文字列 | 1〜3600 の整数、または nil |

規則（[research.md の R2](research.md#r2--切り替え間隔の解析と確定)）: 前後の空白・改行（全角スペースを含む）を除く → 全角数字だけを半角にする → 空・ASCII 数字以外を含む・桁あふれ・範囲外は nil。先頭の `0` は許す。

| 入力の例 | 結果 |
|---|---|
| `10`・`１５`・` 15 `・`007`・`1`・`3600` | 10・15・15・7・1・3600 |
| 空・`0`・`-1`・`+5`・`2.5`・`abc`・`1,000`・`3601`・`99999999999999999999` | nil |

## 3. 実行状態 — SlideshowSession（Core、変更）

| フィールド | 006 | 本 feature |
|---|---|---|
| interval | `let interval: Duration`（3秒固定） | **削除**。期限を計算する操作の引数で受け取る |
| phase・deadline・generation・pendingDue | — | 変更なし |

| 操作 | 変更後のシグネチャ | 期限 |
|---|---|---|
| start | `start(now:interval:)` | `now + interval` |
| arrow | `arrow(now:interval:)` | `now + interval` |
| commit | `commit(now:interval:)` | `now + interval` |
| timeout・stop・remaining | 変更なし | 既存の期限と比べるだけ |

**不変条件**: 一度決めた `deadline` は、設定の変更では書き換えない。新しい間隔は、次に `start`／`arrow`／`commit` が呼ばれたときに初めて使う（FR-132、US12-AS9）。効果の長さは Session に入れない（FR-118、EC-80）。

### 状態遷移（006 の表への追加・変更）

| 状態 | 入力 | 出力／次の状態 |
|---|---|---|
| active | 設定ウインドウで間隔・繰り返し・効果を変更 | phase・deadline・pending を変えない |
| active | pending の commit、`advance` が `.target(url)` | 006 と同じく最大1回送る。running、deadline = commit 時刻 + その時点の間隔。url が現在のフォーカスと同じ（EC-66 の1件・繰り返しオン）なら切り替え効果を arm しない（§5） |
| active | pending の commit、`advance` が `.finish` | 送らずに stop。受理した Esc と同じ復帰（FR-129、A-52） |
| active | pending の commit、`advance` が `.empty` | stop と表示復帰（006 の対象0件と同じ） |

## 4. 次の対象の判断 — SlideshowSequence（Core、変更）

| 操作 | 入力 | 出力 |
|---|---|---|
| `advance(in:focused:repeats:) -> SlideshowAdvance` | 最新の `listing.files`・フォーカス・繰り返し | `.target(URL)` / `.finish` / `.empty` |
| `nextTarget(in:focused:)`（既存） | — | `advance(..., repeats: true)` の `.target` を返すラッパー。性能テストの互換のため残す |

判断の表は [research.md の R5](research.md#r5--繰り返しオフの終了判断)。要点:

- 繰り返しオフで、最新のフォーカスが対象の末尾なら `.finish`。対象が1件だけの場合も同じ（EC-66）。
- フォーカスが対象にない・選択がない場合は、繰り返しに関係なく先頭（FR-125、EC-76）。
- 判定は呼ばれた時点の最新の一覧で行う。繰り返しオフでは、自動送りで末尾から先頭へ戻らない（A-57）。上の選択の消失による先頭（FR-125、EC-76）と、矢印キーによる選び直し（FR-121）は除く。

## 5. プレビューの切り替え — SlideshowTransitionState（Core、新規）

表示だけの切り替えの状態遷移を、Core の純粋な値型 `SlideshowTransitionState`（`Slideshow/SlideshowTransitionState.swift`）に置く。`PreviewViewController` が1つ所有し、イベントを `reduce(_:) -> Action` に渡して、返された action（snapshot の取得と overlay の表示、animation の追加、overlay を外す）だけを実行する。Core の Session とは独立し、期限・タイマーを持たない。AppKit・Core Animation に依存しないので、遷移・世代の照合・準備完了の判定・打ち切りの条件を単体テストできる（憲章 IV、analyze D1）。

| フィールド | 型の方針 | 規則 |
|---|---|---|
| phase | `idle / holding / animating` | holding は snapshot を表示して次の準備完了を待つ間 |
| targetURL | `URL?` | arm したときの対象。ほかの URL の表示が来たら打ち切る |
| effect | `SlideshowTransitionEffect` | `effective(reduceMotion:)` の結果。`none` では arm しない |
| generation | `Int` | 打ち切り・新しい arm で進める。遅れて届く completion・準備完了を捨てる |

前の表示の写し（`CGImage?` と配置の frame・`contentsGravity`、[research.md の R7](research.md#r7--前の表示の-snapshot)。空なら背景だけ）は、AppKit の描画に属するので `PreviewViewController` が持つ。

**イベント**: `arm(target:current:effect:)`（coordinator からの `beginTransition`。current は現在のフォーカス）、`displayed(content:focused:)`（`updateFromModel`）、`ready(url:)`（アニメーション画像の `showAnimated`、動画の `onReadyForTransition`。動画の URL は `PreviewViewController.showVideo` が `configure` に渡した URL（`model.preview` の `.video(URL)`。zip 内の動画もアセットへ変換する前の URL）とする）、`completed(generation:)`（`CATransaction` の completion）、`cancel`（`cancelTransition()`）、`containerResized`。

**準備完了の判定**: `static func readiness(of: PreviewContent)` に [research.md の R8](research.md#r8--次のメディアの準備完了と待機) の表を置く。URL を持たない表示（`.image`・`.unavailable`・`.empty`）は、`displayed` の `focused` をその表示の URL とみなす。

### 状態遷移

| 状態 | 入力 | 出力／次の状態 |
|---|---|---|
| idle | `arm`、target ≠ current かつ effect ≠ none | 前の動画を一時停止して snapshot を取り、overlay を不透明で表示する action。holding |
| idle | `arm`、target = current（EC-66 の1件・繰り返しオン）または effect = none | action なし。idle のまま（前の動画を一時停止しない、FR-119） |
| holding / animating | `arm`（次の commit）、target ≠ current かつ effect ≠ none | 現在の切り替えを打ち切ってから、その時点の表示で新たに arm。holding |
| holding / animating | `arm`、target = current または effect = none | 打ち切り。idle |
| holding | targetURL の表示が準備完了（`displayed` が準備完了、または targetURL の `ready`） | animation を追加する action。animating |
| holding | targetURL の表示が準備中 | 何もしない。holding のまま |
| holding | targetURL 以外の表示 | 打ち切り。idle |
| holding | targetURL の再表示（同じ対象の `displayed` が再び届く） | 準備完了を判定し直す（上の「準備完了」「準備中」の行と同じ） |
| animating | targetURL 以外の表示（例: 効果中に効果「なし」の次の commit が来た） | 打ち切り。idle |
| animating | targetURL の再表示・targetURL の `ready` | 何もしない。animating のまま |
| animating | 現世代の completion | overlay を隠し snapshot を手放す action。idle |
| any | 古い世代の completion、targetURL 以外・holding 以外での `ready` | 何もしない |
| holding / animating | `cancel`（矢印・Esc・stop・閲覧先の置き換え・同じ対象の commit） | animation を外し overlay を隠す action。現在の実物の表示がそのまま見える。idle |
| holding / animating | `containerResized`（全画面の切り替え・リサイズ） | 同上 |
| idle | `cancel`・`containerResized` | 何もしない |

**選択との関係**: holding・animating の間も、選択（フォーカス）はすでに targetURL に移っている。`SlideshowTransitionState` は表示だけの状態で、選択を持たず変えない。この間に受理した矢印・Esc は、coordinator が `cancel` を送った後、選択中のメディア（targetURL）を基準に 006 と同じく処理する。表示中の写しの URL を矢印・終了の基準にしない（EC-80、analyze U5）。

**不変条件**: animation は layer のモデル値を変えずに追加するだけとし、完了・打ち切りのどちらでも、ビューの frame・opacity・transform は効果の前と同じになる。overlay はクリックを通し（`hitTest` が nil）、アクセシビリティ要素にしない。効果の長さは 0.5 秒で固定。

## 6. 動画の再生 — VideoPlayback／VideoPreviewView（変更）

| 対象 | 追加 | 規則 |
|---|---|---|
| `VideoPlayback`（Core） | アイテムごとの `AVPlayerItemVideoOutput`（32BGRA）。`currentFrame() -> CGImage?` | `load` で付け、`unload` で外す。フレームがなければ nil |
| `VideoPreviewView`（App） | `freezeForTransition() -> CGImage?`、準備完了の通知（最初のフレームを表示できる時点、または `AVPlayerItem.status` が `.failed`。[research.md の R8](research.md#r8--次のメディアの準備完了と待機)） | freeze は `pause()` の後にフレームを返す。通知の URL の対応は、`configure` のたびに `PreviewViewController` が設定し直すクロージャで取る（§5 のイベント）。プレーヤーは1つのまま使い回す（bug: slideshow-video-routing-context-crash） |

## 7. 設定ウインドウ — SettingsWindowController（App、変更）

| 区分 | 項目 | コントロール | 保存先 | アクセシビリティのラベル |
|---|---|---|---|---|
| 動画 | 動画を自動再生する | チェックボックス（既存） | `playback.autoplay` | タイトル |
| 動画 | 動画をループ再生する | チェックボックス（既存） | `playback.loop` | タイトル |
| ファイル操作 | 確認する | チェックボックス（既存） | `fileOps.confirmBeforeExecuting` | タイトル |
| スライドショー | 切り替え間隔 ＋「秒」 | テキストフィールド（新規） | `slideshow.intervalSeconds` | 切り替え間隔（秒） |
| スライドショー | 最後まで表示したら先頭から繰り返す | チェックボックス（新規） | `slideshow.repeats` | 最後まで表示したら先頭から繰り返す |
| スライドショー | 切り替え効果 | ポップアップメニュー（新規） | `slideshow.transition` | 切り替え効果 |

キーボードの順序・確定・Esc は [contracts/slideshow-options.md](contracts/slideshow-options.md) を参照。テキストフィールドは「直前の有効値」を保存値から読み、確定に失敗するたびにその表示へ戻す。`showWindow` のたびに保存値から全項目を表示し直す（既存の `syncFromStore`）。

## Persistence

本 feature で永続化するのは `SlideshowOptions` の3キーだけ。実行状態・期限・切り替えの状態（`SlideshowTransitionState`）は、006 と同じくメモリだけに置き、保存しない（FR-126）。
