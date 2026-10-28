# Validation: 拡大プレビューのスクロール

**Feature**: [spec.md](../spec.md) | **Date**: 2026-10-28 | **OS**: macOS 26.6.2 (25G83)

| 確認項目 | 結果 | 根拠 |
|---|---|---|
| `swift build`・`swift test`（性能テストを含む） | PASS | 2026-10-28 実行、Core 817 テスト成功、性能テスト成功 |
| ネットワーク API・README 同期・アプリバンドル作成 | PASS | `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/make-app.sh` |
| 3ペインの表示 | PASS | ユーザー提供のスクリーンショット |
| スクロールバーの表示・配置とマウス操作 | PASS | ユーザーが修正後の問題解消を報告 |
| ナチュラルスクロール無効時のホイール方向 | PASS | ユーザーが修正後の問題解消を報告 |
| 軸ごとの表示・端への移動、キーボード、サイズ変更・位置保持、画像切替等 | PASS | ユーザーが [quickstart.md](../quickstart.md) の手動シナリオ 1〜4 を確認 |
| 外観・VoiceOver と大きな画像での応答 | PASS | ユーザーが [quickstart.md](../quickstart.md) の手動シナリオ 5 を確認 |

GUI 検証はユーザー確認済み。
