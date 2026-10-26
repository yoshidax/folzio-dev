# Bug Assessment: 動画のスライドショーを続けると CoreMedia の routing context で落ちる

- **Slug**: slideshow-video-routing-context-crash
- **Created**: 2026-10-26
- **Source**: pasted text（クラッシュレポート）
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> MP4ファイルのスライドショーを数分続けた際に下記のDumpを吐いてAppが落ちました。

クラッシュレポートの要点（起動 02:59:01、クラッシュ 03:16:30。約17分）:

```
Exception Type:    EXC_BREAKPOINT (SIGTRAP)
Application Specific Information:
BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread

Thread 13 Crashed::  Dispatch queue: com.apple.coremedia.remoteRoutingContext.contextWeakRef
0   libdispatch.dylib    __DISPATCH_WAIT_FOR_QUEUE__ + 612
1   libdispatch.dylib    _dispatch_sync_f_slow + 140
2   MediaExperience      MXDispatchSync + 120
3   MediaExperience      routingContextRemoteXPC_Finalize + 312
4   CoreMedia            FigBaseObjectFinalize + 276
5   CoreFoundation       _CFRelease + 308
6   CoreMedia            FigCFWeakReferenceTableApplyFunction + 192
7   CoreMedia            FigXPCConnectionRetainCopiedObject + 88
8   MediaExperience      routingContext_create + 264
...
14  MediaExperience      MXDispatchSync + 120
15  MediaExperience      FigRoutingContextRemoteCopyContextForUUID + 260
16-18 MediaToolbox       (no symbol)
```

- メインスレッドは `__avplayeritem_fpItemNotificationCallback_block_invoke` → `-[AVPlayerItem willChangeValueForKey:]` の KVO 通知を処理中
- 別スレッドでは `FigVideoRenderPipelineCreateWithFigImageQueueArray`（新しい映像描画パイプラインの作成）が進行中
- どのスレッドにもアプリのフレームはない（`main.swift:8` の `NSApplication.run` だけ）

## Symptom

動画（MP4）を含むフォルダでスライドショーを十数分続けると、アプリが SIGTRAP で終了する。
期待する動作は、ユーザーが Esc で終了するまでスライドショーが続くこと。

## 仕様との照合

- **FR-118**（`specs/006-add-slideshow/spec.md`）: 自動送りは「ユーザーが終了するまで続ける」。途中でプロセスが落ちるのはこれに反する
- **FR-119**（同）: 動画も3秒の送り対象とし、切り替え時は FR-034 に従って以前の動画と音声を止める
- **FR-034**（`specs/product/preview.md`）: 別のファイルを選んだら再生中の動画を止める。止める手段（プレーヤーを捨てるか、アイテムだけを外すか）は定めていない

いずれも仕様は明確で、アプリが落ちることを許す記述はない。プレーヤーを使い回してもこれらの要件は守れる。

**判定**: 実装が仕様（FR-118）に反している → fix へ進む

## Reproduction

1. 動画（MP4）を複数含むフォルダを開く（設定は既定: 自動再生オン・ループ再生オン）
2. スライドショーを開始し、3秒ごとの自動送りで動画が切り替わり続ける状態にする
3. 十数分（報告では約17分）続けると落ちる

- 発生は確率的で、送りの回数に比例して起きやすくなると考えられる。正確な発生率は不明
- [NEEDS CLARIFICATION: 静止画だけのスライドショーでは起きないこと。コード上は動画の切り替えでだけ `AVPlayer` を作るため、起きない見込み]

## Suspected Code Paths

- `Sources/MediaViewerApp/Preview/VideoPreviewView.swift:42-66` — `configure(asset:...)` が毎回 `stop()` で前の
  `VideoPlayback` を捨て、新しい `VideoPlayback`（新しい `AVPlayer`）を作って `playerView.player` に設定する
- `Sources/MediaViewerCore/Playback/VideoPlayback.swift:12-14` — `VideoPlayback` は1つのアセットにつき
  `AVPlayerItem` と `AVPlayer` を1組作る。`invalidate()` 後は使わない設計で、プレーヤーの使い回しができない
- `Sources/MediaViewerApp/Preview/VideoPreviewView.swift:68-80` — `stop()` が `playerView.player = nil` にし、
  `playback = nil` で `AVPlayer` を解放する
- `Sources/MediaViewerApp/Preview/PreviewViewController.swift:176-212` — 動画へ切り替えるたびに `showVideo` →
  `configure`、動画以外へ移るたびに `stopVideo` → `stop()` を呼ぶ
- `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` — 3秒ごとに選択を進める。動画が続くと約17分で
  最大約340回、`AVPlayer` の生成と破棄を繰り返す

## Root Cause Hypothesis

各 `AVPlayer` は出力先（AirPlay など）を管理する routing context を内部に持つ。新しいプレーヤーの routing context を
`contextWeakRef` キューの上で作る途中で、弱参照テーブルの走査中に古いプレーヤーの routing context の最後の参照が外れる。
その Finalize が同じキューへ `dispatch_sync` し、libdispatch が再入を検出してプロセスを止める。

これは CoreMedia / MediaExperience 内部の生成と破棄の競合で、アプリの API の使い方の誤りではない。
アプリ側は、スライドショーで3秒ごとに `AVPlayer` を作っては捨てるため、競合に当たる機会が通常の閲覧より桁違いに多い。

確信度: クラッシュの仕組み（同じキューへの再入）は **high**（スタックから読み取れる）。引き金が `AVPlayer` の
生成と破棄の繰り返しであることは **medium**（OS 内部は非公開。似た `*_Finalize` からの再入は Apple Developer Forums
にも報告があり、オブジェクトを使い回すと減ったとされる）。

## Proposed Remediation

**Preferred**: `AVPlayer` を `VideoPreviewView` の寿命の間1つだけにし、動画の切り替えは `replaceCurrentItem(with:)` で行う。

- `VideoPlayback` を「1つの `AVPlayer` を持ち続け、アイテムを載せ替える」型に変える
  - `init()` で `AVPlayer` を1つ作る
  - `load(asset:loop:)` で新しい `AVPlayerItem` を載せ、`actionAtItemEnd` とループ用の終端通知をそのアイテムに合わせて付け直す
  - `unload()`（今の `invalidate()` に相当）で終端通知を外し、一時停止して `replaceCurrentItem(with: nil)` する。プレーヤーは捨てない
- `VideoPreviewView` は `VideoPlayback` を1つだけ持ち、`playerView.player` は最初に設定したまま外さない
- `stop()` は `unload()` を呼ぶだけにし、`AVPlayer` を解放しない。再生中かどうか・シーク・再生切り替えは
  「アイテムが載っているときだけ」扱う
- routing context の生成と破棄は起動時の1回だけになり、競合の機会がなくなる

**Alternatives**:

- 古いプレーヤーの解放を遅らせる（次の run loop や数百ミリ秒後に解放）。変更は小さいが、競合の時間をずらすだけで確実ではない
- `allowsExternalPlayback = false` にする。routing context が作られなくなるかは確認できておらず、単独では頼れない

**Files likely to change**:

- `Sources/MediaViewerCore/Playback/VideoPlayback.swift`
- `Sources/MediaViewerApp/Preview/VideoPreviewView.swift`
- `Tests/MediaViewerCoreTests/VideoPlaybackTests.swift`

**Tests to add or update**:

- 2本の動画を続けて `load` しても `player` が同じインスタンスであること（回帰テスト。プレーヤーを作り直す実装に戻ると失敗する）
- 載せ替えたあとのループ設定が新しいアイテムに従うこと（ループあり → なし、なし → あり）。古いアイテムの終端通知で
  新しいアイテムが巻き戻らないこと
- `unload()` 後はアイテムがなく、再生が止まっていること
- 既存の `loopSeekPastEndKeepsItem` などは新しい API に合わせて書き換える（bug: preview-skip-forward-frame-freeze の回帰を保つ）
- OS 内部の競合そのものは単体テストで再現できない。GUI でスライドショーを長時間（30分以上）動かす確認を `/speckit-bug-test` で行う

## Risks & Considerations

- 前の動画の状態が次の動画へ残らないこと: rate、`actionAtItemEnd`、終端通知、`timeControlStatus` の監視。
  `stop()` で一時停止してからアイテムを差し替えるので、自動再生オフの設定で次の動画が勝手に再生されることはない見込み
- `AVPlayerView` にアイテムのないプレーヤーを付けたままにする。プレビューは動画以外のとき `videoView` を隠すので見た目には出ない
- 音量・消音はプレーヤーに残る。今はユーザーが変えた音量が動画ごとに既定へ戻るが、使い回すと次の動画へ引き継がれる。
  FR-033 は音量の扱いを定めておらず、引き継ぐ方が自然と判断する（気になる場合は切り替え時に既定へ戻す）
- 完全には OS 側の不具合なので、プレーヤーを1つにしても別の経路（`AVPlayerItem` の生成と破棄）で似た競合が残る可能性はある。
  routing context はプレーヤーに付くため、少なくとも今回のスタックの経路はなくなる

## Open Questions

- [NEEDS CLARIFICATION: 音量・消音を動画の切り替えで引き継いでよいか。既定では引き継ぐ方針で進める]
