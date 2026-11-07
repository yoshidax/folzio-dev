# Bug Fix: SwiftPM の翻訳リソースの両配置に対応する

- **Slug**: swiftpm-resource-layout（会話の診断から引き継ぎ）
- **Fixed**: 2026-11-06
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

保守者が診断と修正方針を承認したため、make-app.sh の翻訳リソース参照先を修正した。
SwiftPM 6.0 の .bundle 直下と Contents/Resources の両配置に対応する。

## Changes

| File | Change | Notes |
|------|--------|-------|
| scripts/make-app.sh | 参照先を選択 | .bundle を基準にし、Contents/Resources があればその配下を使用する |
| scripts/dev/tests/test_package_release.py | make-app の回帰4件 | 実スクリプトを使い、Swift・アイコン生成・署名コマンドだけを stub にする |
| release-notes/v1.0.1.md | 日英の配布ノート | Swift 6.0 を含むバンドル配置への対応を記載する |
| specs/TAK-41-actions-release/tasks.md | 進捗記録 | T032 の確認は未完了のまま残す |

日英の strings / stringsdict の必須検査、欠落時の .app 削除、コピー後の署名は維持した。
新たな依存と製品仕様の変更はない。

## Tests Added or Updated

- MakeAppResourceTests.test_flat_swiftpm_bundle: バンドル直下から日英が同梱され、指定 version / build になる。
- MakeAppResourceTests.test_contents_resources_bundle: Contents/Resources 配置でも同じ成果物になる。
- MakeAppResourceTests.test_missing_language_stops_before_signing: 両配置で日英いずれかの欠落を拒否する。
- MakeAppResourceTests.test_missing_stringsdict_stops_before_signing: 両配置で日英いずれかの stringsdict 欠落を拒否する。

## Local Verification

- bash -n scripts/make-app.sh: 成功。
- git diff --check: 成功。
- scripts/dev/check-all.sh: 143件成功、macOS / rsync 必須の33件 skip。
- 新しい4件は実際の PlistBuddy が必要なため Cloud では skip し、macOS CI で実行する。

## Deviations from Assessment

診断の Risks & Considerations に従い、同じリリース PR のノートに配布時の修正を記載した。
tasks.md は承認・検証の進捗記録だけを更新した。修正方針の変更はない。

## Follow-ups

最新 PR HEAD の通常 macOS CI と Release candidate の結果を PR #65 に記録する。
候補 ZIP を取得し、ビルド環境外での GUI 確認を保守者が行う。
