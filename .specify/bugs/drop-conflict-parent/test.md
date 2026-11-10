# Bug Verification: 同名ドロップの確認の親

- **Slug**: drop-conflict-parent
- **Tested**: 2026-11-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial（元症状・CI通常は成功。性能4件超過が残る）

## Summary

キー・メインウインドウが取得できない場合の衝突確認の省略を自動再現し、指定の親で表示する修正後は関連テストが成功した。全通常1,155件と規約チェックも成功。保守者によるSafari・Chrome各3選択の確認と保存データの検査も成功した。bcdd40aのSwift 6.0 CIも通常1,155件成功。性能は27件中4件超過が残るためpartial。

## Checks Performed

| Check | Command / Action | Result | Notes |
|---|---|---|---|
| 修正前の再現 | swift test --filter ImportPromptParentTests | fail（期待どおり） | 4テスト、17 issues、0.525秒 |
| 修正後の関連 | swift test --filter 'ImportPromptParentTests\|ReceivedFileTransferTests\|ImportSessionTests' | pass | 31件、0.577秒 |
| 全通常 | swift test --no-parallel --skip FolzioPerformanceTests | pass | Core 1,082件・App 73件、計1,155件 |
| 最終コードbuild | swift build | pass | 未使用の文面引数の整理後も成功 |
| 最終App | swift test --no-parallel --filter FolzioAppTests | pass | 全73件、1.674秒。Coreソースは全通常実行後も変更なし |
| 規約 | scripts/dev/check-all.sh | pass | 最終コードでもPython 179件、スキップなし |
| アプリ作成 | scripts/make-app.sh | pass | 最終コードで.build/Folzio.app作成 |
| 差分の形式 | git diff --check | pass | 問題なし |
| 元のGUI症状 | Safari・Chromeの同名ドロップで置換・両方残す・中止 | pass | 手順整理後、TAK88-recheck-01〜06で1件ずつ確認。全6件で確認が出て選択でき、下表の実体も一致 |
| CI・今回の修正 | macOS Swift CI 42771331921 / job 129679579601 | pass | bcdd40aをcheckout。Swift 6.0のbuild・probe自己検査・通常1,155件成功（174.263秒） |
| 同CIの性能 | swift test --filter FolzioPerformanceTests | fail | 27件中23件成功・4件基準超過（155.737秒）。ログ末尾を確認しvalidation.mdへ数値を記録 |

## Output Excerpts

- 修正前: Test run with 4 tests in 1 suite failed after 0.525 seconds with 17 issues.
- 関連: Test run with 31 tests in 3 suites passed after 0.577 seconds.
- 全通常: Test run with 1082 tests in 116 suites passed after 97.511 seconds.
- 全通常: Test run with 73 tests in 15 suites passed after 1.198 seconds.
- 最終App: Test run with 73 tests in 15 suites passed after 1.674 seconds.
- 規約: all checks passed
- アプリ: created .build/Folzio.app

ログは /tmp/folzio-tak88-conflict-fix/。実機の宛先は /Users/igachan/Desktop/pics/TAK88-collision-parent/ 内のsafari-replace、safari-keep、safari-abort、chrome-replace、chrome-keep、chrome-abort。

- 各宛先の既存sample.pngは161 bytes、SHA-256 5a5a47c83114f65dc9fd38cdf422e2eeded555162d7a1993bd336dd0dc8eb271。
- 確認ページの新しいsample.pngは188 bytes、SHA-256 732710219cabbdf1ed6b847716f1f177da2fd08854cec8a3515c654ad68c23ed。
- 両方ともimage/pngを確認。既存の個人ファイルを変更せず、今回だけの専用フォルダを作成した。

## Residual Risks

- テストはNSAlertの構築・親・選択と実ファイルの結果までを確認し、シートの表示部分だけを差し替える。実際のブラウザからのドロップも保守者が全6件で確認済み。他の全状況の確認を完了したという意味ではない。
- 別ボリュームは方針の引数を変えたテストであり、exFAT等の実外部ボリュームへの保存ではない。
- 親を閉じる時機やT031の全確認を完了したという意味ではない。
- 31064b7の互換修正CI（通常1,151件成功・性能3件超過）は今回の修正のCIとは別。性能のしきい値は変更しない。

## Recommendation

元の症状と3つの選択の保存結果は、同じ修正コードでの手順を整理した実機確認で解消を確認した。ソースとバグ記録はbcdd40aでコミット・push済み。CIの通常テストと性能ログの末尾まで確認済み。今回の修正で解消したため⌘.の廃止への切り替えは行わず、Phase 4へ進まない。before/after_bug_testの登録hookはなし。

## 実機確認の整理（2026-11-10）

最初の6フォルダでの回答は、保守者が「手順を間違いました」「整理できないため1からやり直した方が良い」と回答したため判定保留。読み取りではchrome-replaceの新画像にSafariのquarantine、chrome-keepの新画像にChromeのquarantineがあり、safari側は元画像のままだった。ブラウザ・宛先・選択の対応を推定して合格にはしなかった。

ソースは変えず、新しいTAK88-recheck-01〜06を用意し、1件ずつ保守者に確認した。各フォルダは /Users/igachan/Desktop/pics/ の下。

| フォルダ | 操作 | 保守者の確認 | 読み取り確認 |
|---|---|---|---|
| TAK88-recheck-01 | Safari・置き換える | 確認が出て選択できた | sample.pngは新188 bytesとSHA-256一致、quarantineはSafari |
| TAK88-recheck-02 | Safari・両方残す | 確認が出て2件 | 元sample.pngは161 bytesと一致、sample 2.pngは新188 bytesと一致、quarantineはSafari |
| TAK88-recheck-03 | Safari・中止 | 確認が出て中止、1件 | 元sample.pngの161 bytesとSHA-256一致、追加なし |
| TAK88-recheck-04 | Chrome・置き換える | 確認が出て選択できた | sample.pngは新188 bytesとSHA-256一致、quarantineはChrome |
| TAK88-recheck-05 | Chrome・両方残す | 確認が出て2件 | 元sample.pngは161 bytesと一致、sample 2.pngは新188 bytesと一致、quarantineはChrome |
| TAK88-recheck-06 | Chrome・中止 | 確認が出て中止、1件 | 元sample.pngの161 bytesとSHA-256一致、追加なし |

全6フォルダの名前・内容の組を自動照合して一致。終了後の一時記録は未使用の待機用2組のみで、空のreceived・checkedだけだった。現在の修正を追加で変える必要があるというGUI失敗は確認されなかった。
