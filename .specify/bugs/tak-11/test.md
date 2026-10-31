# Bug Verification: 重複するフォルダ列挙の結果順序

- **Slug**: tak-11
- **Tested**: 2026-11-01
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial

## Summary

静的検査は通過した。再現を固定するテストは追加したが、Cloud 環境では Swift と GUI を実行できず、修正後の再現や回帰は未検証。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| 再現・新規テスト・回帰 | `swift build`, `swift test` | not-run | macOS CI が必要 |
| 起動スモーク | GUI 起動 | not-run | 保守者の macOS が必要 |
| ネットワーク API | `scripts/check-no-network.sh` | pass | Sources にネットワーク API なし |
| README | `scripts/check-readme-sync.sh origin/master` | pass | ローカルの master は存在しない |
| 英語コメント | `scripts/dev/check-english-comments.sh` | pass | |
| skill 同期 | `scripts/dev/check-skill-sync.sh` | pass | |
| git push 検査 | `python3 -m unittest discover -s scripts/dev/tests -p test_check_git_push.py` | pass | 3 tests |
| 差分 | `git diff --check` | pass | |

## Residual Risks

- 回帰テストのコンパイルと実行、実際の GUI での動作は確認できていない。

## Recommendation

macOS CI でビルド・テストを実行し、保守者が起動スモークを確認するまで検証は partial とする。
