# Validation: アプリ内ドラッグによる整理

**Feature**: [spec.md](../spec.md) | **確認日**: 2026-10-28

- 実施環境: macOS 26.6.2 (25G83)（確認時の環境を `sw_vers` で取得）
- 実行ファイル SHA-256: `2fd1d6e61ab88a08a40aa9989003d95360fc2de4940b95d5ae3dd8cf61a2d6e3`（報告後に照合）
- 自動検証: `swift build`、`swift test`（820 件）、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/make-app.sh` が成功。
- GUI: ユーザーに [quickstart.md](../quickstart.md) の全シナリオと3ペインの確認を依頼し、「確認しました。問題ない」と一括報告を受領。各シナリオの個別結果の記述はなし。

## Phase 2: 同じ親へのフォルダコピー

- 確認日: 2026-10-28。macOS 26.6.2 (25G83)（`sw_vers` で確認）。
- 実行ファイル SHA-256: `f44bac6fe463d81e4d16fb7c86a1be7ff4dbc2adc988cde614207b2e298e773d`（報告後に照合）。
- 自動検証: `swift build`、`swift test`（821 件と性能 27 件）、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/make-app.sh` が成功。前の試行では性能の1秒基準超過と検索テストのタイムアウトがそれぞれ発生し、再実行で通過。
- GUI: 3ペインと、フォルダの同じ親への Option ドロップで「両方残す」、元と中身の保持、置き換え不可を確認するよう依頼し、ユーザーから「確認しました。問題ないです」と報告を受領。
