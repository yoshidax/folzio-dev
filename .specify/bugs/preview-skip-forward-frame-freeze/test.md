# Bug Verification: 短い動画で 15 秒スキップすると映像フレームが止まる

- **Slug**: preview-skip-forward-frame-freeze
- **Tested**: 2026-10-24
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

ループ再生中の 5 秒程度の動画で「15 秒進む・戻る」を押しても映像が止まらないことを、ユーザーが GUI で確認した。
ビルド・全テスト・ネットワーク API チェックも通り、回帰は見つかっていない。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `scripts/make-app.sh` → `open .build/MediaViewer.app`、ループ再生オンの 5 秒程度の動画で 15 秒進む・戻る | pass | ユーザーが実施。映像が動き続ける |
| ループの継続 | 同上で終端まで再生 | pass | ユーザーが実施。先頭へ戻ってループが続く |
| 一時停止中のスキップ | 一時停止中に 15 秒進む | pass | ユーザーが実施。勝手に再生が始まらない |
| フルスクリーン切替（FR-037） | 再生中にフルスクリーンの切替・解除 | pass | ユーザーが実施。再生位置と状態が保たれる |
| 別ファイル選択で停止（FR-034） | 再生中に別のファイルを選ぶ | pass | ユーザーが実施 |
| zip の中の動画 | zip 内の動画で 15 秒進む・戻る | pass | ユーザーが実施 |
| New / updated tests | `swift test --filter VideoPlayback` | pass | 5 件（fix 時に実行） |
| Regression suite | `swift test` | pass | MediaViewerCoreTests 474 件、MediaViewerPerformanceTests 17 件 |
| Build | `swift build` | pass | 警告なし |
| ネットワーク API | `scripts/check-no-network.sh` | pass | 参照なし |

## Output Excerpts

```
Build complete! (1.90秒)
✔ Test run with 17 tests in 1 suite passed after 29.311 seconds.
✔ Test run with 474 tests in 46 suites passed after 25.994 seconds.
no network API references in Sources
```

## Residual Risks

- AVPlayerView 内部で映像が止まっていた仕組みは特定していない。`AVPlayerLooper` を使わない構成で症状が消えたことを
  GUI で確認したことが根拠
- 描画が止まらないことは単体テストでは確かめられない。回帰テストは「終端・先頭を越えるシークで再生中のアイテムが
  切り替わらない」ことを固定している
- ループの境目は gapless ではなくなった。ユーザー確認では気にならなかった

## Recommendation

Close the bug — verified end-to-end（GUI での再現確認をユーザーが実施）。3ペイン表示での `<` / `>` によるシークは
FR-033 の範囲外のため、必要なら sdd-increment で扱う。
