# Bug Fix: 動画のスライドショーを続けると CoreMedia の routing context で落ちる

- **Slug**: slideshow-video-routing-context-crash
- **Fixed**: 2026-10-26
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

動画を切り替えるたびに `AVPlayer` を作り直していたのをやめた。`VideoPreviewView` の寿命の間は `AVPlayer` を1つだけ持ち、
`replaceCurrentItem(with:)` でアイテムを載せ替える。routing context の生成と破棄は起動時の1回だけになり、
スライドショーの3秒ごとの切り替えで CoreMedia 内部の競合に当たる機会をなくした。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/MediaViewerCore/Playback/VideoPlayback.swift` | modified | `init(asset:loop:)` / `invalidate()` を `init()` / `load(asset:loop:)` / `unload()` に変更。`player` は1つを使い回す |
| `Sources/MediaViewerApp/Preview/VideoPreviewView.swift` | modified | `VideoPlayback` を1つだけ持つ。`playerView.player` は `setup()` で一度設定して外さない。`player` はアイテムを載せている間だけ返す |
| `Tests/MediaViewerCoreTests/VideoPlaybackTests.swift` | modified / added tests | 既存3件を新しい API に合わせ、回帰テスト3件を追加 |

## Diff Highlights (optional)

```swift
// VideoPlayback
public let player = AVPlayer()

public func load(asset: AVAsset, loop: Bool) {
    unload()
    let item = AVPlayerItem(asset: asset)
    player.replaceCurrentItem(with: item)
    // ループ設定と終端通知は載せたアイテムに合わせて付け直す
    ...
}

public func unload() {
    // 終端通知を外し、一時停止してアイテムを外す。プレーヤーは捨てない
}
```

```swift
// VideoPreviewView
private let playback = VideoPlayback()
private var player: AVPlayer? { playback.player.currentItem == nil ? nil : playback.player }
```

## Tests Added or Updated

- `VideoPlaybackTests.reusesPlayerAcrossLoads` — `load` → `unload` → `load` しても `player` が同じインスタンスで、アイテムだけ入れ替わる（プレーヤーを作り直す実装に戻すと失敗する）
- `VideoPlaybackTests.reloadFollowsNewLoopSetting` — 載せ替えたアイテムが新しいループ設定（`actionAtItemEnd`）に従い、前のアイテムの終端通知で新しいアイテムが先頭へ戻らない。`unload()` で終端通知を外さないように変えると失敗することを確認した
- `VideoPlaybackTests.unloadStopsAndClearsItem` — `unload()` で再生が止まり、アイテムが外れる
- `loopSeekPastEndKeepsItem` / `loopSeekBeforeStartKeepsItem` / `noLoopStopsAtEnd` — 新しい API に合わせて書き換え（bug: preview-skip-forward-frame-freeze の回帰を保つ）

## Local Verification

- Commands run:
  - `swift build` → 成功
  - `swift test --filter VideoPlayback` → 8 tests passed
  - `swift test` → 646 tests / 59 suites passed（性能テスト 23 件も passed）
  - `scripts/check-no-network.sh` → no network API references
  - `scripts/make-app.sh` → `.build/MediaViewer.app` を作成
- 再現の試み: 修正前の方式（切り替えごとに `AVPlayer` を作り直す）を CLI で 30ms 間隔・4分間（7,222 回）繰り返したが落ちなかった。
  CLI には `AVPlayerView` もウインドウもないため、アプリと同じ条件ではない。CLI ではクラッシュを再現できていない
- Manual checks: GUI での確認（起動スモーク、スライドショーの長時間実行）は `/speckit-bug-test` で行う

## Deviations from Assessment

なし。

## Follow-ups

- 音量・消音は動画を切り替えても引き継がれるようになった（assessment の Open Questions）。既定へ戻したい場合は `load` で `volume` / `isMuted` を戻す
- 修正後に再びクラッシュレポートが出た場合は、スタックが routing context の経路か、`AVPlayerItem` の生成と破棄の経路かを確認する
