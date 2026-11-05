# Implementation Plan: ID 重複解消規則の整合

**Branch**: `feature/tak-76-spec-id-policy` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: `specs/TAK-76-spec-id-policy/spec.md`

## Summary

EC-135 を憲章と揃え、詳細手順の正本は憲章が既に参照する `docs_private/cloud-agent-workflow.md` の 7 章とする。製品仕様には検証可能な要求と正本への参照を残し、ID の付け方からも手順へ誘導する。

## Technical Context

**Language/Version**: Markdown、既存検査用 Python 3 / Bash

**Primary Dependencies**: 既存の Spec Kit とリポジトリの検査スクリプト

**Storage**: リポジトリ内の仕様・手順文書

**Testing**: ID 検査、仕様形式検査、`check-all.sh`、手動の文脈・リンク照合

**Target Platform**: ローカルおよび Cloud での仕様保守

**Project Type**: 内部の仕様・運用文書

**Performance Goals**: 該当なし

**Constraints**: 憲章 1.3.0 に従い、凍結済み feature の本文と既存 ID を変更しない

**Scale/Scope**: EC-135 と ID の参照経路、7 章の重複解消手順

## Constitution Check

- 原則 I〜III: アプリの通信・性能・UI を変更しない。
- 原則 IV: 文書変更を既存の自動検査とケース別照合で検証する。アプリのテスト・起動は既存ゲートに従う。
- 原則 V: 新しいツール・依存・実装は追加しない。
- 仕様管理: 新規 feature に変更内容を記録し、承認後に EC-135 を既存 ID のまま反映する。
- 憲章との整合: マージ状態による対象、凍結記録への注記、一意性と再利用禁止を維持する。
- 設計後の再確認: 上記を満たす。憲章の変更は不要。

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
docs_private/cloud-agent-workflow.md  # 重複解消の詳細手順
.specify/memory/constitution.md      # 優先される原則と手順への参照（本文は変更しない）
```

**Structure Decision**: 現在の 7 章を詳細手順の正本とし、他の文書にはその役割に必要な要約とリンクを置く。FR-193 は EC-135 への参照を維持する。EC-135 の反映後、憲章の Sync Impact Report の追従 TODO を完了済みに更新するが、憲章本文とバージョンは変えない。

## Complexity Tracking

憲章違反・追加の複雑さはない。
