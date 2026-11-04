# Bug Verification: 表示中のフォルダ自体・祖先の外部改名・削除が一覧に反映されない

- **Slug**: tak-12（会話の修正から継承）
- **Tested**: 2026-11-01
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: pass

## Summary

macOS CI でビルドとテストが成功し、保守者が GUI で再現手順の解消と起動スモークを確認した（2026-11-01）。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| GUI: 祖先の削除 | 中身のあるフォルダを表示中に、Finder で親をゴミ箱に入れる | pass | 保守者が確認。リストとツリーが同じ祖先を表示する |
| GUI: 表示中のフォルダの改名 | Finder で改名 | pass | 保守者が確認 |
| GUI: `rm -rf` | ターミナルで祖先ごと削除 | pass | 保守者が確認 |
| GUI: ボリュームの取り出し | ディスクイメージの中のフォルダを表示中に取り出す | pass | 保守者が確認。「フォルダが見つかりません」になり、プレビューが空になる |
| GUI: お気に入りがあるときの取り出し | ボリュームの最上位をお気に入りに登録して取り出す | pass | 保守者が確認。`/Volumes` に移らない（`e6e6d4c` の退行が解消） |
| GUI: zip の中での取り出し | zip の中を表示中に取り出す | not-run | OS が使用中として取り出しを拒否するため、通常の取り出しでは起きない。回帰テストで確認 |
| 起動スモーク | `scripts/make-app.sh`、`open .build/Folzio.app` | pass | 保守者が確認 |
| Swift build / test | macOS CI（`swift build`, `swift test`） | pass | `e6e6d4c`: run 41327142026、`eaee3a7`: run 41331325157（`workflow_dispatch`） |
| Network API | `scripts/check-no-network.sh` | pass | |
| README | `scripts/check-readme-sync.sh origin/master` | pass | README の変更なし |
| Comments | `scripts/dev/check-english-comments.sh` | pass | |
| Skills | `scripts/dev/check-skill-sync.sh` | pass | |
| Git push rules | `python3 -m unittest discover -s scripts/dev/tests -p test_check_git_push.py` | pass | 3 tests |
| Diff whitespace | `git diff --check` | pass | |

## Residual Risks

- 再マウント後は「フォルダが見つかりません」の表示のまま、自動で元の表示へ戻さない（保守者の決定。assessment を参照）。
- 強制的な取り出し・ケーブルの抜去で zip の中を表示しているときは、GUI で確かめていない（回帰テストのみ）。

## Recommendation

マージしてよい。
