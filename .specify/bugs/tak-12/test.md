# Bug Verification: 表示中のフォルダ自体・祖先の外部改名・削除が一覧に反映されない

- **Slug**: tak-12（会話の修正から継承）
- **Tested**: 2026-11-01
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial

## Summary

Core の回帰テストを追加し、Cloud で実行できる静的チェックは通過した。Swift のビルド・テストと GUI での再現の解消は未確認。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| GUI 再現 | 祖先の Finder での削除、表示中のフォルダの改名、`rm -rf` | not-run | Cloud では GUI と FSEvents を使用できない |
| Swift build / test | `swift build`, `swift test` | not-run | macOS CI が必要 |
| Network API | `scripts/check-no-network.sh` | pass | |
| README | `scripts/check-readme-sync.sh origin/master` | pass | README の変更なし |
| Comments | `scripts/dev/check-english-comments.sh` | pass | |
| Skills | `scripts/dev/check-skill-sync.sh` | pass | |
| Git push rules | `python3 -m unittest discover -s scripts/dev/tests -p test_check_git_push.py` | pass | 3 tests |
| Diff whitespace | `git diff --check` | pass | |

## Residual Risks

- 回帰テストは watcher の通知を `handleFileSystemEvent` に直接渡す。FSEvents が実際に親・祖先を通知することは GUI で確かめる必要がある。
- 外部ボリュームの取り外し（assessment の E）は対象外。

## Recommendation

macOS CI でビルドとテストを確認し、保守者が GUI で次を確認してから判定する。

1. 親のある、中身のあるフォルダをツリーで選び、Finder で親フォルダをゴミ箱に入れる。リストとツリーが同じ祖先を表示すること。
2. 表示中のフォルダを Finder で改名する。リストが親へ移ること。
3. ターミナルで `rm -rf` により祖先ごと削除する。「フォルダが見つかりません」ではなく、存在する祖先が表示されること。
4. zip の中を表示中に、zip を含むフォルダを Finder で改名する。zip から出て親が表示されること。
5. 起動スモーク（3ペインが表示されること）。
