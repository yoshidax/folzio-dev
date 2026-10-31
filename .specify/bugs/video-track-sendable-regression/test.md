# Bug Verification: 最新の Swift（macOS SDK 27.2）で VideoPreviewView がビルドできない

- **Slug**: video-track-sendable-regression
- **Tested**: 2026-10-31
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified（Swift 6.0 は CI で確認。最新の版は保守者の報告に基づく。出力の行は受け取っていない）
- **Issue**: [TAK-31](https://linear.app/takyoshida/issue/TAK-31)

## Summary

修正（PR #5）で、Swift 6.0（Xcode 16.0）の CI が成功した。保守者は、ローカル（最新の Xcode、macOS SDK 27.2）で `swift build` と `swift build --build-tests` を実行し、「問題なし」と報告した。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | 保守者のローカルで `swift build && swift build --build-tests` | pass（保守者の報告） | 報告は「問題なし」。`Build complete!` などの出力の行は受け取っていない |
| Swift 6.0 のビルドとテスト | PR #5 の CI（macOS 15 / Xcode 16.0。run 41178594315、コミット `c424eeb`） | pass | `swift build` 15 秒、通常のテスト（直列）2 分 24 秒、性能テスト 1 分 42 秒。すべて成功 |
| 元のコードとの差分 | `72753a3`（TAK-28 より前）との差分を確認 | pass | インポートの行とそのコメント（`@preconcurrency import AVFoundation`）だけ |
| ネットワーク API の検査 | `scripts/check-no-network.sh` | pass | クラウドで実行 |
| コメントの英語 | `scripts/dev/check-english-comments.sh` | pass | クラウドで実行 |
| README の同期 | `scripts/check-readme-sync.sh master` | pass | クラウドで実行 |
| 最新の版での `swift test` | — | not-run（未報告） | 保守者から結果の報告を受けていない |
| 起動スモーク（動画のプレビュー） | — | not-run（未報告） | 補助関数を取り除いて元のコードに戻したため、動作は TAK-28 より前と同じはず。GUI での確認の報告は受けていない |

## Output Excerpts

```text
# CI（run 41178594315、Xcode 16.0 / Swift 6.0）
Build        success  15 s
Test         success  2 min 24 s (--no-parallel --skip FolzioPerformanceTests)
Performance  success  1 min 42 s
```

## Residual Risks

- 最新の版でのビルドは、保守者の「問題なし」という報告に基づく。実行したコマンドの出力の行は受け取っていない（TAK-28 の訂正と同じ点。結果の詳細が残らない）
- 最新の版での `swift test` と、動画プレビューの GUI での確認は、報告を受けていない
- CI（macos-15、Xcode 16.0）には最新の SDK がなく、この種の回帰は CI では見つからない
- `@preconcurrency` は、そのファイルの `AVFoundation` 由来の `Sendable` の診断を警告に下げる

## Recommendation

バグを閉じてよい。最新の版の `swift test` と動画プレビューの確認が済んでいなければ、次の機会に行い、結果をここに追記する。

## 追記（2026-10-31）

- 保守者が、最新の版での `swift test`、動画プレビューを含む GUI での確認を含めて、「全て問題ないことを確認済み」と報告した。コマンドの出力と件数は受け取っていない
- PR #5 の CI の性能テストを、ステップの表示ではなく**ログで**確認した: 27 件すべて成功（100.1 秒）。上の記録の「すべて成功」は、ログで裏づけられた
- 「Checks Performed」の「最新の版での `swift test`」と「起動スモーク（動画のプレビュー）」は、この報告に基づいて `pass（保守者の報告）` とする
