# Bug Fix: 短い動画で 15 秒スキップすると映像フレームが止まる

- **Slug**: preview-skip-forward-frame-freeze
- **Fixed**: 2026-10-24
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

ループ再生を `AVQueuePlayer` ＋ `AVPlayerLooper` から、1つのアイテムを持つ `AVPlayer` を終端で先頭へ戻す方式に置き換えた。
終端・先頭を越えるシークで再生中のアイテムが複製へ切り替わらなくなり、AVPlayerView の描画が古いフレームに残る経路をなくした。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/MediaViewerCore/Playback/VideoPlayback.swift` | added | `AVPlayer` とループの扱い。ループ時は `actionAtItemEnd = .none` と終端通知で `seek(to: .zero)`、ループしないときは `.pause`。シーク先の計算 `seekTarget(from:by:duration:)` |
| `Sources/MediaViewerApp/Preview/VideoPreviewView.swift` | modified | `AVQueuePlayer` / `AVPlayerLooper` / 終端通知の管理を `VideoPlayback` に置き換え。`seek(by:)` は `VideoPlayback.seekTarget` を使う |
| `Tests/MediaViewerCoreTests/VideoPlaybackTests.swift` | added test | シーク先の境界値と、ループ有無でのシーク後の再生状態 |

## Diff Highlights

```swift
// VideoPlayback.init（ループ時）
player.actionAtItemEnd = .none
endObserver = NotificationCenter.default.addObserver(
    forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
) { [weak player] _ in
    MainActor.assumeIsolated {
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
```

先頭へ戻すときに rate は変えない。再生中ならそのまま続き、一時停止中なら先頭で止まったままになる
（assessment の「一時停止中の動画を勝手に再生しない」に対応）。

## Tests Added or Updated

- `VideoPlaybackSeekTargetTests.clampsToDuration` — 5 秒の動画で +15 / −15 / +5 秒が `[0, duration]` に丸まる
- `VideoPlaybackSeekTargetTests.undefined` — 位置や長さが NaN・0 のときはシークしない
- `VideoPlaybackTests.loopSeekPastEndKeepsItem` — ループ再生で長さを越えた位置（丸めない 17 秒。AVPlayerView の
  15 秒スキップ相当）へシークしても、アイテムが同じまま先頭側から再生を続ける（回帰テスト。`AVPlayerLooper` では
  アイテムが複製へ切り替わる）
- `VideoPlaybackTests.loopSeekBeforeStartKeepsItem` — 先頭より前へシークしても同じアイテムで再生を続ける
- `VideoPlaybackTests.noLoopStopsAtEnd` — ループしないときは終端を越えるシークで終端に止まる（US2-AS3）

## Local Verification

- `swift build` → 成功（警告なし）
- `swift test --filter VideoPlayback` → 5 件成功
- `swift test` → MediaViewerCoreTests 474 件・MediaViewerPerformanceTests 17 件、すべて成功
- `scripts/check-no-network.sh` → ネットワーク API の参照なし
- Manual checks: 未実施。描画が止まらないことは単体テストで確かめられないため、`/speckit-bug-test` で GUI 確認が必要

## Deviations from Assessment

- 「シーク先の計算を Core に切り出す」と「AVFoundation を使う回帰テスト」を、1つの型 `VideoPlayback`（Core、AppKit なし）に
  まとめた。プレイヤーの生成とループの扱いも Core に置いたため、回帰テストは実際にアプリが使う型を対象にしている

## Follow-ups

- GUI 確認（ループ再生オン、5 秒の動画）:
  - 15 秒進む・戻るを押しても映像が動き続ける
  - 終端で先頭に戻り、ループが続く（境目の間が気にならないか）
  - 一時停止中に 15 秒進むを押しても、勝手に再生が始まらない
  - フルスクリーン切替で再生位置と状態が保たれる（FR-037）、別ファイル選択で停止する（FR-034）
  - zip の中の動画でも同じ
- 3ペイン表示での `<` / `>` によるシークは仕様外（FR-033）。必要なら sdd-increment で扱う
