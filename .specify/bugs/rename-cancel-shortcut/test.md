# Bug Verification: 名前編集中の⌘.による編集取消

- **Slug**: rename-cancel-shortcut
- **Tested**: 2026-11-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial（互換修正版のGUI・通常テストは成功。Swift 6.0 CI待ち）

## Summary

修正前に受信の有無の2ケースで編集が取り消されないことを実フィールドエディタで再現し、修正後は成功した。全通常テスト1,151件と規約チェックが成功し、確認用アプリを作成した。保守者が2026-11-10に最新アプリで3ペイン表示、受信なし・ありの編集取消、通常の受信取消をすべて確認した。元のGUI症状は再現せず、ローカルでverifiedとする。799e09eのCIはSwift 6.0でビルド失敗した。互換修正版はローカルで全通常テストまで成功し、互換修正版でも保守者が3ペイン表示・元の名前のままの編集取消を確認した。残るSwift 6.0 CIを確認する。

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
| 起動・元のGUI症状（799e09e） | 3ペイン、受信なし・ありの編集取消、通常の受信取消 | pass | 3項目すべて期待どおりと保守者が回答。Aのcat 3.jpgはimage/jpeg・719 bytes・quarantineあり、Bは空 |
| CI・799e09e | macOS Swift CI 42701811275 / job 129448170376 | fail | Swift 6.0で非隔離のNSMenu overrideからMainActorのUIへアクセスできず、build失敗。通常・性能テストは未実行 |
| 互換修正・通常初回 | swift test --no-parallel --skip FolzioPerformanceTests | fail | Coreのzip内PNG/MP4のキャッシュ同一性2件が失敗。App 69件成功。未変更の箇所で原因未確定 |
| 互換修正・対象単独 | swift test --no-parallel --filter 'generatesThumbnailForImageInsideZip\|generatesThumbnailForVideoInsideZip' | pass | 同じコードで2件成功、1.557秒 |
| 互換修正・正式ゲート | build → 全通常テスト → check-all → make-app | pass | 通常1,151件、Python 179件、git diff --check成功 |
| 互換修正版のGUI | 3ペインと編集取消 | pass | 保守者が最新アプリへ起動し直し、両方成功と回答（2026-11-10） |
| 互換修正版のCI | macOS Swift CI | not-run | 追加コミット・pushして確認 |

## Output Excerpts

- 修正前: Test run with 1 test in 1 suite failed after 0.474 seconds with 4 issues.（パラメータ2ケース）
- 対象: Test run with 33 tests in 3 suites passed after 1.019 seconds.
- 通常: Test run with 1082 tests in 116 suites passed after 97.007 seconds.
- 通常: Test run with 69 tests in 14 suites passed after 0.809 seconds.
- 規約: all checks passed
- アプリ: created .build/Folzio.app

ログ: /tmp/folzio-tak88-rename-fix/ のred-tests.log、green-tests.log、build.log、tests.log、check-all.log、make-app.log。

- 互換修正・通常再実行: Core 1,082件成功（101.617秒）、App 69件成功（1.710秒）。
- 互換修正ログは同じ場所のcompat-build.log、compat-tests-initial.log（初回失敗）、compat-cache-tests.log、compat-tests.log、compat-check-all.log、compat-make-app.log。

## Residual Risks

- GUIを表示しないテストはウインドウとモーダル状態だけを差し替えている。実際に設置されるメニューと実フィールドエディタを通すが、実機キー配信も保守者が上記3項目で再確認済み。他のテキスト欄やシートの全操作を手動確認したという意味ではない。
- 今回のCIはbuildで止まったため、通常・性能テストをまだ実行できていない。直前のa3e9065のCIの通常1,145件成功・性能5件超過は今回の結果とは区別する。しきい値は変更しない。
- T031の宛先・同時の確認ダイアログ・強制終了後の掃除・性能などは未完了。

## Recommendation

元の症状は799e09eでローカルの自動テスト・GUIで解消を確認した。Swift 6.0向けの互換修正版でも起動・編集取消を確認済み。追加ソースとバグ記録を同じコミットへ入れ、指定ブランチへpushしてCIを確認する。T030はこの追加修正のCIまで未チェックに戻し、T031も未チェックのまま。Phase 4へ進まない。before/after_bug_testの登録hookはなし。
