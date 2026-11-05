# Feature Specification: Codex での Spec Kit 開発環境

> **凍結（2026-11-05、製品仕様の反映対象外）**: この feature は開発環境の変更であり、`specs/product/` への反映対象外。
> 現在の Codex 運用は [docs_private/codex-speckit.md](../../docs_private/codex-speckit.md) を参照する。
> このファイルは 005 時点の記録として凍結しており、更新しない。

**Feature Branch**: `005-codex-speckit-support`
**Created**: 2026-10-25
**Status**: Approved — ユーザーが提案した環境整備を承認

## User Scenarios & Testing

### User Story 1 — Codex から既存の仕様駆動開発を行う (P1)

Codex で Spec Kit の標準工程、git 拡張、bug 拡張を呼び出し、既存の
AGENTS.md・憲章・specs/product/ に従って開発できる。

**Acceptance Scenarios**:

1. Codex スキルがリポジトリ内で検出でき、標準 10 コマンドと拡張 8 コマンドを持つ。
2. Claude／Kilo のファイル、既定の Claude integration、共有スクリプトを維持する。

### User Story 2 — Codex バックエンドで increment を実行する (P1)

追加要件を run し、設計レビュー・GUI 確認・仕様反映確認で止まり、status／resume できる。

**Acceptance Scenarios**:

1. Codex の最終回答をレビューに渡し、実行中のイベントを進捗ログに残す。
2. 失敗・中断・成果物不足は後続工程を進めない。
3. GUI 確認はユーザーに依頼し、報告前に検証タスクを完了扱いにしない。

## Requirements

- **DEV-001**: 公式 Codex integration と `.agents/skills/` を使う。
- **DEV-002**: 自動実行では Codex の sandbox と承認レビューを有効にし、全権限の迂回フラグを追加しない。
- **DEV-003**: git push、git reset --hard、git clean を禁止する既存運用を Codex に引き継ぐ。
- **DEV-004**: モデルは Codex の設定を継承し、Claude 専用モデル名を渡さない。
- **DEV-005**: 初期実装は順次実行とする。並列化する場合は AGENTS.md の独立 worktree セッション規約を守る。
- **DEV-006**: run／resume の終了通知で他のワークフローの状態を誤って報告しない。
- **DEV-007**: セットアップ、呼び出し、更新、承認待ちと失敗時の手順を記載する。

## Success Criteria

- **DEV-SC-001**: 隔離した一時リポジトリで実行・失敗・承認ゲート・再開を自動検証できる。
- **DEV-SC-002**: 実際の Codex でスキル読み込みとファイル／Git 操作をスモーク確認できる。
- **DEV-SC-003**: swift build → swift test → check-no-network → make-app を通し、GUI 確認をユーザーに依頼する。

## Assumptions

- macOS 上のローカル Codex CLI、認証済みアカウント、Spec Kit 1.2.2 を使用する。
- これは開発環境の変更で、MediaViewer の機能要件・契約・外部依存を変更しない。
- 開発環境の ID は DEV 接頭辞とし、アプリ仕様の FR／SC を消費しない。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| DEV-001〜007 | 追加 | AGENTS.md・README.md・docs/codex-speckit.md（開発環境のため specs/product/ への反映対象なし） |
