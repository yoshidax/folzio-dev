# Tasks: Codex での Spec Kit 開発環境

- [X] T001 現在の構成・CLI・公式ドキュメントを確認し、作業ブランチと spec／plan を作成する
- [X] T002 公式 Codex integration と標準・git／bug 拡張スキルを登録し、既存設定を維持する
- [X] T003 Codex のプロジェクト設定と禁止コマンドのルールを追加する
- [X] T004 Codex increment、run／resume／status、進捗ログ・終了通知を実装する
- [X] T005 隔離した一時リポジトリで最終回答・失敗・ゲート・再開を検証し、実 CLI でスモークする
- [X] T006 README・AGENTS.md・docs/codex-speckit.md に使用方法と運用上の境界を記載する
- [X] T007 swift build → swift test → scripts/check-no-network.sh → scripts/make-app.sh を実行する
- [X] T008 ユーザーが GUI を起動し、3 ペインを確認する。報告を受けて本ファイルに結果を記録する
- [X] T009 GUI 確認後、変更と検証記録を Phase 単位でコミットする

## 検証記録

2026-10-25（JST）、macOS 26.6.2、Codex CLI 0.164.0、Spec Kit 1.2.2。

- `python3 -m unittest discover -s scripts/tests -v`: 10 件成功。
  最終回答抽出・引数維持・非 0 終了・失敗イベント・途中切断・ログ書き込み失敗、
  実 Spec Kit と偽 Codex の隔離 workflow による gate の停止／TTY 回答後の再開、
  status、他 workflow の run の拒否、終了状態の誤認防止を確認。
- 実 Codex が `$speckit-git-validate` を読み、005 ブランチと spec ディレクトリを検証。
  `CODEX_SKILL_SMOKE_OK` を取得。
- 一時リポジトリで、実 Codex の `--approve-for-me` を使ったファイル作成と
  ローカルコミットを確認。`CODEX_WRITE_SMOKE_OK` とクリーンな作業ツリーを確認。
  本リポジトリのファイル・コミットには影響させていない。
- 18 スキルの name／description／本文を skill-creator の簡易検証器で確認。
  検証器が未対応の公式 `compatibility` メタデータのみ一時コピーから外して検証し、
  生成元は変更していない。標準 10 スキルの manifest hash も一致。
- `specify workflow info sdd-increment-codex` と engine の validate: 成功。
  ソース YAML と登録済み workflow.yml の内容も一致。
- `codex execpolicy check`: push／reset --hard／clean が forbidden。
- `specify integration status`: claude／kilocode／codex が登録済み、既定は claude。
  既存の `.specify/.gitignore` カスタマイズに対する警告 1 件は維持。
  `.claude/`、`.kilo/`、共有 `.specify/scripts/` に差分なし。
- `swift build`: 成功。sandbox による既存キャッシュの書き込み拒否後、権限を得て再実行。
- `swift test`: 612 件成功。
- `scripts/check-no-network.sh`: 成功。
- `scripts/make-app.sh`: 成功。起動確認用 `.build/MediaViewer.app` を生成。
  既存の MainToolbarController.swift:64 に Sendable closure と MainActor の警告あり。
- GUI の起動確認: ユーザーから「3 ペインを確認し、問題なし」と報告あり。起動・表示・通常操作の確認を合格として記録。
- GUI 確認後、Codex 対応の設定・スキル・ワークフロー・テスト・文書と本記録を同一の Phase コミットにまとめる。
