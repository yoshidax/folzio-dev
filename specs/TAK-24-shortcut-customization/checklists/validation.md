# Validation: 設定画面でのショートカットキー割り当ての変更

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Date**: 2026-11-02

## GUI（保守者のローカル、T024）

確認したコミット: 06da9e7 以降（未設定の許可 FR-268 を含む版）。`scripts/make-app.sh` の後に `open .build/Folzio.app` で起動した。

| # | 確認項目 | 結果 | 根拠 |
|---|---|---|---|
| 1回目 | 設定「ショートカット」タブの日本語表示（Q2 相当） | FAIL | 2026-11-02 に保守者が画面を共有し、「ペインと表示」配下の上の 2 行でボタンの位置がずれる指摘。ef60615 で列を固定幅にして修正した |
| Q1〜Q17 | quickstart.md の GUI の確認（Q17 = キーの入れ替え） | PASS | 2026-11-02 に保守者が「問題ないことを確認しました」と報告。項目ごとの結果、言語（日本語・英語）ごとの結果、OS の版の報告はない |

## 自動の検証

| 実行する者 | 検査 | 結果 | 根拠 |
|---|---|---|---|
| Cloud | `check-no-network.sh`・`check-readme-sync.sh master`・`check-english-comments.sh`・`check-skill-sync.sh`・`test_check_git_push.py`・`git diff --check` | PASS | 各コミットの前に実行 |
| CI | `swift build`・`swift test`（1da8559、run 41435238931） | PASS | `pull_request` の実行。通常のテスト 985 件・性能テスト 27 件 |
| CI | 同上（ef60615、run 41436079477） | PASS | `workflow_dispatch`。通常のテスト 985 件・性能テスト 27 件 |
| CI | 同上（06da9e7、run 41438290132） | PASS | `workflow_dispatch`。通常のテスト 996 件・性能テスト 27 件（ログの末尾の件数で確認） |

## converge（T025）

2026-11-02 に実行。FR-255〜268、US48〜50、EC-178〜187、SC-125〜132 は実装・検証済みで、追加のタスクはない（tasks.md は変更なし）。確認の方法:

- メニュー項目の登録箇所（18 か所）とキーの直書きの残りを grep で確認した。直書きが残っているのは名前の変更（Return。固定キー）とダイアログの既定ボタンだけで、対象外である（FR-256）
- 設定・翻訳・テストの追加を、spec.md の各項目と突き合わせた
- 残る確認は、GUI の英語表示と非 US 配列（spec.md の Assumptions A-157。保守者の報告に言語ごとの結果はない）

## 保守者の報告に含まれていないこと

- 日本語・英語それぞれの結果、OS の版、VoiceOver での確認（Q14 の読み上げ）の個別の報告はない。「問題ない」との報告をそのまま記録した
