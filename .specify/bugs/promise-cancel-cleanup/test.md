# Bug Verification: 取消後の受け取り先の早期削除

- **Slug**: promise-cancel-cleanup
- **Tested**: 2026-11-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified（ローカルの元症状。修正後CIは未実行）

## Summary

自動再現では修正前に2件ともフォルダが消えて失敗し、修正後は遅延書き出しと完了後の掃除が成功した。全通常テストと規約チェックが成功し、確認用アプリを作成済み。2026-11-10、保守者が修正アプリで同じPhotos MOVを受信中に取り消し、約1分後もPhotosのエラーがなく、宛先が空のままという期待どおりの結果を確認した。ローカルの元症状をverifiedとする。修正後CIとT031の他の手動項目は別途残る。

## Checks Performed

| Check | Command / Action | Result | Notes |
|---|---|---|---|
| 自動再現・修正前 | cancelledProducerKeepsDestinationUntilItsCallback / cancelledReaderStillAcknowledgesCompletionWithoutCloning | fail（期待どおり） | 2件ともreceivedフォルダが消えた。0.027秒 |
| 対象テスト | swift test --filter 'ImportSessionTests\|ImportPromiseCompletionTests\|ImportBudgetTests\|ImportReceptionStateTests' | pass | 先行のCore 5件・App 20件が成功 |
| 全通常テスト | swift test --no-parallel --skip FolzioPerformanceTests | pass | 最終コードでCore 1,082件・App 63件、計1,145件 |
| ビルド | swift build | pass | 最終コード |
| 規約チェック | scripts/dev/check-all.sh | pass | Python 179件・スキップなし |
| 差分の形式 | git diff --check | pass | 問題なし |
| アプリ作成 | scripts/make-app.sh | pass | .build/Folzio.app作成 |
| 元の症状・修正後 | 同じPhotos MOVを受信中に取り消し、Photosの書き出し結果と保存先を確認 | pass | 保守者が「期待通りです」と回答。TAK88-cancel-checkは空。未使用の待機用2組以外に一時フォルダの記録なし |
| CI・修正後 | macOS Swift CI | not-run | GUI確認後のコミット・pushで実行する |
| 性能 | 今回の修正についての性能テスト再実行 | not-run | 直前の6c139d0のCIは通常1,130件成功、性能は2件超過。今回の結果とは区別 |

## Output Excerpts

- 修正前: Test run with 2 tests in 1 suite failed ... with 2 issues.
- 最終: Test run with 1082 tests in 116 suites passed after 95.231 seconds.
- 最終: Test run with 63 tests in 13 suites passed after 0.848 seconds.
- 規約: all checks passed
- アプリ: created .build/Folzio.app

ログ: `/tmp/folzio-tak88-cancel-fix/` のred-tests.log、green-tests.log、build.log、tests.log、check-all.log、make-app.log。

## Residual Risks

- 写真アプリの外部writer自体を強制停止する保証はない。取り消し後も書き出し完了まで私有一時領域が残る場合がある。保存せず、完了後に掃除する。
- 期限・容量に達したwriterは保護のため打ち切る。元の正常な取消のケースと区別する。
- 正常終了時にwriterが未完了の場合は記録を維持し、次の起動で掃除する。
- 元のPhotosのエラーは今回のGUI再確認では発生しなかった。別の入力や、複数操作の進捗・フォーカスを含むT031全体を完了したという意味ではない。
- 今回の実機操作のLoggerイベントは取得できなかった。手動の約23秒という比較と、自動テストのfake clockの時間を実測ログとは扱わない。

## Recommendation

元の取消症状はローカルの自動・GUI確認で解消した。修正をコミット・pushし、CIの通常テストと性能ログを確認する。T031の残る手動確認を継続し、Phase 4へ進まない。
