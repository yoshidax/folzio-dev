# Bug Verification: SwiftPM の翻訳リソース配置

- **Slug**: swiftpm-resource-layout
- **Tested**: 2026-11-06
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial

## Summary

Cloud の静的検査・既存回帰は成功した。SwiftPM の出力からの .app 作成と新しい4件の回帰は
macOS 固有のため、push 後の CI で再現の解消を確認する。GUI は保守者の確認待ち。
この記録は push 前の Cloud 検証時点の結果とし、最新 CI と候補の取得先は PR #65 の検証欄に記録する。

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Shell syntax | bash -n scripts/make-app.sh | pass | Bash 構文に問題なし |
| Diff whitespace | git diff --check | pass | エラーなし |
| Regression suite | scripts/dev/check-all.sh | pass | 143件成功・33件skip |
| Make-app regression | unittest discover -p test_package_release.py | skipped | 新規4件を含む9件は macOS 必須 |
| Actual reproduction after fix | Release candidate | not-run | 最新 HEAD を push した後に macOS CI で実行する |
| GUI outside build environment | ダウンロード候補の起動 | not-run | 保守者が候補生成後に実施する |

## Output Excerpts

> all checks passed

## Residual Risks

- Cloud に Swift / PlistBuddy / codesign がないため、実パッケージ作成は macOS CI で確認する。
- GUI と Gatekeeper の最終確認は保守者のローカル PC が必要。

## Recommendation

最新 HEAD の候補生成成功を確認し、CI artifact をダウンロードしてローカル確認する。
T032 は候補の3ペイン・日英・About の確認報告を受けるまで未完了とする。
