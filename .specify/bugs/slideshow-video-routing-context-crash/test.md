# Bug Verification: 動画のスライドショーを続けると CoreMedia の routing context で落ちる

- **Slug**: slideshow-video-routing-context-crash
- **Tested**: 2026-10-26
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

修正後のアプリで、ユーザーが GUI のスライドショーを試し、クラッシュが再現しないことを確認した。
自動テスト・ネットワーク API チェックも通り、回帰は見つかっていない。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `scripts/make-app.sh` → `open .build/MediaViewer.app` で動画を含むフォルダのスライドショーを実行（ユーザー） | pass | ユーザーがクラッシュの再現しないことを確認 |
| 起動スモーク | 同上 | pass | ユーザーの GUI 確認で起動・表示を確認 |
| New / updated tests | `swift test --filter VideoPlayback` | pass | 8 tests（追加3件・書き換え3件を含む） |
| Regression suite | `swift test` | pass | 646 tests / 59 suites、性能テスト 23 件 |
| Build | `swift build` | pass | |
| No network | `scripts/check-no-network.sh` | pass | |

## Output Excerpts

```
Build complete! (2.45秒)
✔ Test run with 23 tests in 1 suite passed after 37.158 seconds.
✔ Test run with 646 tests in 59 suites passed after 24.720 seconds.
no network API references in Sources
```

## Residual Risks

- 原因は CoreMedia 内部の競合で、発生は確率的。修正前の方式でも CLI では再現できず（fix.md）、修正前後で同じ条件の比較はしていない。
  再現しないことの確認は、ユーザーの GUI での実行に基づく
- `AVPlayerItem` の生成と破棄は切り替えごとに続く。別の経路で似た競合が残る可能性はある
- 音量・消音は動画の切り替えで引き継がれるようになった

## Recommendation

Close the bug。修正後に再びクラッシュレポートが出た場合は、スタックが routing context の経路かを確認し、新しい証拠を添えて `/speckit-bug-assess` をやり直す。
