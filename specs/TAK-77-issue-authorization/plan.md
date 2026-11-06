# Implementation Plan: Issue 対応の操作とレビュー

**Branch**: `work` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

## Summary

Issue の依頼に必要な操作と自動 CI を含める。設計レビューと製品仕様反映の承認、手動 CI の個別許可、マージの保守者専任を維持する。push の機械的保護を安全に維持できるか確認し、限定できない場合は現行の確認を残す。

## Technical Context

- 対象は Markdown、Codex のルールとフック、Spec Kit workflow、既存の Python・shell 検査。
- `AGENTS.md`、`docs_private/cloud-agent-workflow.md`、`docs_private/agents/linear.md`、`docs_private/agents/skills-and-codex.md`、`docs_private/codex-speckit.md`、`shared-skills/folzio-sdd-increment.md` の適用範囲と記述を照合する。
- `.specify/workflow-src/sdd-increment-codex.yml` と登録済み workflow のレビュー・反映ゲートを維持する。変更が必要な場合は登録手順で生成物と registry を同期する。
- `.codex/rules/sdd.rules`、`.codex/hooks.json`、`scripts/dev/check-git-push.py` とテストを調査する。prefix 規則だけでは任意の引数や実 URL を安全に検査できない可能性があり、フックの信頼・適用範囲も別に検証する。フックがない場合に危険な push を黙って許可しない。既存の brew 禁止と手動 CI の確認を維持する。
- 現在のブランチ `work` は既存フックの許可接頭辞に含まれない。Cloud の指定と安全な push 先の不一致は回避せず報告し、適切な作業ブランチを選ぶ際は現行手順に従う。
- ローカルの製品仕様反映承認と自動 workflow の `merge_back_gate` は維持する。Cloud は反映直前に最新 master を取り込み、ID を前後で確認する。
- 対象ファイル・実行環境・フック有効性によって、Codex アプリの承認や自動承認レビューを保証できないことを記述する。

## Constitution Check

- I〜III: アプリのデータ、ネットワーク、性能、UI は変更しない。
- IV: 操作保護の異常系と文書整合を検証する。CI と GUI の未実施を明記し、未通過のままマージしない。
- V: 新しい外部依存を導入しない。安全に限定できない場合は既存の確認を維持する。
- 仕様管理: feature を新設し、実装・検証の後に正本へ反映する。既存の ID を変更しない。

## Verification

1. push 保護の既存テスト、必要な安全性テスト、可能なら `codex execpolicy check` とフック有効・無効ケースを確認する。
2. 手順と仕様のケース照合、workflow ソースと登録済みの一致、`scripts/dev/check-all.sh` を実行する。
3. 仕様反映前後の `scripts/dev/check-spec-ids.sh` と反映後の `python3 scripts/dev/check-spec-format.py` を実行する。
4. PR の CI と GUI は Cloud の手順に従い、環境で未実行の検証は明記する。手動 CI の起動・再実行は別途許可を得る。

## Complexity Tracking

追加の依存や抽象化は予定しない。安全な制約の実現可能性を調査し、無条件許可は採用しない。
