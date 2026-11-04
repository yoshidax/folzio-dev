# Bug Verification: 重複するフォルダ列挙の結果順序

- **Slug**: tak-11
- **Tested**: 2026-11-03
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: pass

## Summary

`origin/master`（`28d72be`）をマージした後、macOS のローカルでビルド、全テスト、静的検査が通過した。修正前の master では回帰テスト2件が失敗し、修正後は20回の繰り返し実行ですべて通過した。完了順の逆転は GUI で意図的に起こせないため、再現の確認は回帰テストで行う。保守者が起動スモークと外部変更・ファイル操作後の一覧の反映を GUI で確認した（2026-11-03）。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| 再現（修正前） | master に回帰テストだけを入れて `swift test --filter BrowserModelTests` | fail（期待どおり） | 2件が失敗、他の30件は通過 |
| 回帰テスト（修正後） | `overlappingReloads`、`reloadSupersedesInitialLoad` を20回実行 | pass | |
| Swift build / test | `swift build`、`swift test` | pass | FolzioCoreTests 1032件、性能テスト27件、ほか19件 |
| 起動スモーク | `scripts/make-app.sh`、`open .build/Folzio.app` | pass | 保守者が確認。3ペインの表示 |
| GUI: 一覧の反映 | Finder での追加・削除、アプリでの改名・削除 | pass | 保守者が確認。一覧・選択・プレビューが正しい |
| Network API | `scripts/check-no-network.sh` | pass | |
| README | `scripts/check-readme-sync.sh master` | pass | README の変更なし |
| Comments | `scripts/dev/check-english-comments.sh` | pass | |
| Skills | `scripts/dev/check-skill-sync.sh` | pass | |
| Spec IDs | `scripts/dev/check-spec-ids.sh` | pass | |
| Diff whitespace | `git diff --check` | pass | |

## Residual Risks

- 完了順の逆転そのものは GUI で確かめていない（回帰テストのみ）。

## Recommendation

マージしてよい。
