# Bug Verification: サムネイル形式でリスト内のファイルをリスト内のフォルダへドラッグ&ドロップできない

- **Slug**: tak-44（明示的に指定）
- **Tested**: 2026-11-01
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

保守者が GUI で、サムネイル形式のフォルダ項目へのドロップができること、ドロップ先の塗りつぶしと復帰を確認した（コミット `d905693`）。
master（TAK-37）を取り込んだ PR の head `ea32fa2` で、macOS CI のビルドと通常のテスト・性能テストがすべて成功した。回帰は見つかっていない。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| 再現手順（修正後、GUI） | 保守者のローカル: `scripts/make-app.sh`、`open .build/Folzio.app` で assessment の Reproduction を実施 | pass | `6777965` でフォルダ項目の範囲へのドロップができることを確認。`d905693` でドロップ先の塗りつぶしと、ポインタが離れたときの復帰を確認 |
| 起動スモーク | 同上（3ペインの表示） | pass | 上の GUI 確認の中で起動している |
| 新しいテスト | CI: `swift test --no-parallel --skip FolzioPerformanceTests` | pass | `ThumbnailDropTargetTests`（2件、計4ケース）は通常のテストに含まれる |
| ビルド・回帰テスト | CI（[run 41348409617](https://github.com/yoshidax/folzio-dev/actions/runs/41348409617)、job 124973120324、macOS 15 / arm64） | pass | 通常のテスト 920 件成功 |
| 性能テスト | CI: `swift test --filter FolzioPerformanceTests` | pass | `continue-on-error` のため、ログの末尾で 27 件成功を確認 |
| Cloud の検査 | `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`test_check_git_push.py` | pass | master の取り込み後にも実行 |

## Output Excerpts

```text
✔ Test run with 920 tests passed after 114.290 seconds.
✔ Test run with 27 tests passed after 93.231 seconds.
```

## Residual Risks

- master（TAK-37。名前変更後の中央寄せ）を取り込んだ後のコミット `ea32fa2` では、GUI を再確認していない。取り込んだ変更は名前変更の表示だけで、
  ドロップと強調の処理とは重ならず、自動テストは成功している。
- 検索結果のフォルダ項目へのドロップは、同じ `validateDrop` を通るが、GUI では確かめていない。
- `ThumbnailDropTargetTests.thumbnailImageIgnoresDrops` は、AppKit が `NSImageView` に既定で登録しない環境では、修正を消しても失敗しない（fix.md の Deviations）。
- リスト形式・ツリーの 16pt のアイコンの上のドロップは対象外（fix.md の Follow-ups）。

## Recommendation

マージしてよい。必要なら、マージの前に `ea32fa2` で、サムネイル形式のドロップと、名前変更後の中央寄せを手短に確認する。
