# Validation: アプリ内ドラッグによる整理

**Feature**: [spec.md](../spec.md) | **確認日**: 2026-10-28

- 実施環境: macOS 26.6.2 (25G83)（確認時の環境を `sw_vers` で取得）
- 実行ファイル SHA-256: `2fd1d6e61ab88a08a40aa9989003d95360fc2de4940b95d5ae3dd8cf61a2d6e3`（報告後に照合）
- 自動検証: `swift build`、`swift test`（820 件）、`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/make-app.sh` が成功。
- GUI: ユーザーに [quickstart.md](../quickstart.md) の全シナリオと3ペインの確認を依頼し、「確認しました。問題ない」と一括報告を受領。各シナリオの個別結果の記述はなし。
