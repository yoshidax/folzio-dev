# Bug Verification: 名前編集中の⌘.による編集取消

- **Slug**: rename-cancel-shortcut
- **Tested**: 2026-11-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified（元症状のローカルGUI・自動確認。今回のCIは未実施）

## Summary

修正前に受信の有無の2ケースで編集が取り消されないことを実フィールドエディタで再現し、修正後は成功した。全通常テスト1,151件と規約チェックが成功し、確認用アプリを作成した。保守者が2026-11-10に最新アプリで3ペイン表示、受信なし・ありの編集取消、通常の受信取消をすべて確認した。元のGUI症状は再現せず、ローカルでverifiedとする。今回のCIは別途確認する。

## Checks Performed

| Check | Command / Action | Result | Notes |
|---|---|---|---|
| 修正前の再現 | swift test --filter MainMenuCancellationTests | fail（期待どおり） | 受信の有無の2ケースとも編集が続き、元の名前に戻らない。0.474秒、4 issues |
| 修正後の関連テスト | swift test --filter 'MainMenuCancellationTests\|ThumbnailRenameTests\|ImportSessionTests' | pass | 33件、1.019秒 |
| build | swift build | pass | 最終コード |
| 全通常テスト | swift test --no-parallel --skip FolzioPerformanceTests | pass | Core 1,082件・App 69件、計1,151件 |
| 規約 | scripts/dev/check-all.sh | pass | Python 179件、スキップなし |
| 差分の形式 | git diff --check | pass | 問題なし |
| アプリ作成 | scripts/make-app.sh | pass | .build/Folzio.app作成済み |
| 起動・元のGUI症状 | 3ペイン、受信なし・ありの編集取消、通常の受信取消 | pass | 3項目すべて期待どおりと保守者が回答。Aのcat 3.jpgはimage/jpeg・719 bytes・quarantineあり、Bは空 |
| CI・今回の修正 | macOS Swift CI | not-run | GUI後にコミット・pushして確認 |

## Output Excerpts

- 修正前: Test run with 1 test in 1 suite failed after 0.474 seconds with 4 issues.（パラメータ2ケース）
- 対象: Test run with 33 tests in 3 suites passed after 1.019 seconds.
- 通常: Test run with 1082 tests in 116 suites passed after 97.007 seconds.
- 通常: Test run with 69 tests in 14 suites passed after 0.809 seconds.
- 規約: all checks passed
- アプリ: created .build/Folzio.app

ログ: /tmp/folzio-tak88-rename-fix/ のred-tests.log、green-tests.log、build.log、tests.log、check-all.log、make-app.log。

## Residual Risks

- GUIを表示しないテストはウインドウとモーダル状態だけを差し替えている。実際に設置されるメニューと実フィールドエディタを通すが、実機キー配信も保守者が上記3項目で再確認済み。他のテキスト欄やシートの全操作を手動確認したという意味ではない。
- 今回のコードについて性能テストはまだ実行していない。直前のa3e9065のCIの通常1,145件成功・性能5件超過は今回の結果とは区別する。しきい値は変更しない。
- T031の宛先・同時の確認ダイアログ・強制終了後の掃除・性能などは未完了。

## Recommendation

元の症状はローカルの自動テスト・GUIで解消を確認した。ソースとバグ記録を同じコミットへ入れ、指定ブランチへpushしてCIを確認する。T030はこの追加修正のCIまで未チェックに戻し、T031も未チェックのまま。Phase 4へ進まない。before/after_bug_testの登録hookはなし。
