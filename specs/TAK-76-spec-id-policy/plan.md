# Implementation Plan: ID 重複解消規則の整合

**Branch**: `feature/tak-76-spec-id-policy` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-76-spec-id-policy/spec.md`

## Summary

ID の振り直し対象の判断規則は憲章を正本とする。詳細手順はローカルと Cloud に共通の `docs_private/spec-id-conflicts.md` に置き、EC-135・README・Cloud 手順から参照する。EC-135 の対象ラベル・検出時点・反映前に振り直す順序は維持する。

## Technical Context

**Language/Version**: Markdown、既存検査用 Python 3 / Bash

**Primary Dependencies**: 既存の Spec Kit とリポジトリの検査スクリプト

**Storage**: リポジトリ内の仕様・手順文書

**Testing**: ID 検査、仕様形式検査、`check-all.sh`、手動の文脈・リンク照合

**Target Platform**: ローカルおよび Cloud での仕様保守

**Project Type**: 内部の仕様・運用文書

**Performance Goals**: 該当なし

**Constraints**: 憲章の ID 判断規則に従い、凍結済み feature の本文と既存 ID を変更しない

**Scale/Scope**: EC-135、憲章の参照、共通手順と Cloud 固有手順の分離

## Constitution Check

- 原則 I〜III: アプリの通信・性能・UI を変更しない。
- 原則 IV: 文書変更を既存の自動検査とケース別照合で検証する。アプリのテスト・起動は既存ゲートに従う。
- 原則 V: 新しいツール・依存・実装は追加しない。
- 仕様管理: 新規 feature に変更内容を記録し、承認後に EC-135 を既存 ID のまま反映する。
- 憲章との整合: マージ状態による対象、凍結記録への注記、一意性と再利用禁止を維持する。
- 設計後の再確認: ID の判断規則は変更しない。詳細手順の参照先を変更する憲章改定を Spec Kit の手続きに従って行う。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-76-spec-id-policy/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
specs/product/overview.md            # EC-135 の正本
specs/product/README.md              # ID の付け方と手順への参照
AGENTS.md                            # 共通の ID 衝突時の参照先
docs_private/spec-id-conflicts.md     # ローカルと Cloud に共通する詳細手順（新規）
docs_private/cloud-agent-workflow.md  # Cloud 固有の手順と共通手順への参照
.specify/memory/constitution.md      # 判断規則の正本、共通手順への参照
```

**Structure Decision**: 判断規則は憲章にのみ定義し、操作の詳細は共通手順に集約する。Cloud 手順には PR・master 取り込みなど Cloud 固有の事項と共通手順へのリンクを残す。FR-193 は EC-135 への参照を維持する。憲章の参照先を変えるため 1.3.0 → 1.3.1 の PATCH 改定とし、改定日・Sync Impact Report に TAK-76、変更理由、影響と EC-135 追従の完了を記録する。判断規則の意味は変えない。改定日は実際の改定日とし、元の制定日を保持する。

`AGENTS.md` の共通の ID 衝突時の参照先を共通手順に変える。変更前に `docs_private/agents/README.md` を読み、変更後に `scripts/dev/check-agents-md.sh` で行数と参照先を検査する。変更理由は PR 本文の「変更」に独立して記録する。

## Complexity Tracking

憲章違反・追加の複雑さはない。
