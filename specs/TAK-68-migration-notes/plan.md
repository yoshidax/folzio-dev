# Implementation Plan: 完了 feature の仕様反映と凍結注記

**Branch**: `chore/tak-68-migration-notes` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: [TAK-68](https://linear.app/takyoshida/issue/TAK-68)、[TAK-10](https://linear.app/takyoshida/issue/TAK-10)

## Summary

マージ済み TAK-10 の連番規則を、実装・テストと照合して製品仕様の FR-018・FR-025 に反映する。既存の完了 feature は反映済みかを確認し、注記だけを追加する。005 は開発環境のため製品仕様への反映対象外であることを明記する。

## Technical Context

**Language/Version**: Markdown、既存検査用 Python 3 / Bash。実装の参照先は Swift 6。

**Primary Dependencies**: 既存 Spec Kit とリポジトリの検査スクリプト。新しい依存は追加しない。

**Storage**: リポジトリ内の仕様・feature 記録。

**Testing**: 仕様 ID と形式の検査、`check-all.sh`、既存の連番回帰テストとの照合、注記・リンクと差分の確認。

**Target Platform**: macOS と Cloud の仕様保守。

**Project Type**: 既存アプリの仕様・開発記録の整備。

**Performance Goals**: 該当なし。

**Constraints**: アプリ実装と既存の要件 ID を変えない。既存 feature の記録は保守者の依頼に基づく先頭注記以外を変更しない。

**Scale/Scope**: FR-018・FR-025 と完了済み feature の先頭注記。

## Constitution Check

- 原則 I〜III: アプリの通信・性能・UI に変更なし。
- 原則 IV: 既存の連番回帰テストと照合し、既存の自動検査を実施。実行できない macOS の検査は未実施として報告する。
- 原則 V: 新しいツール・依存・アプリの機能を追加しない。
- 仕様管理: TAK-10 は仕様の正本への反映が未了のため新しい feature に変更点を記載し、設計レビュー後に既存 ID で反映する。
- 凍結記録: 既存 feature の先頭への注記は保守者が TAK-68 で明示的に依頼した作業とする。過去の本文や TAK-49 の ID 対応表を変更しない。
- 設計後の再確認: 上記を満たす。憲章の改定は計画しない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-68-migration-notes/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
specs/product/file-operations.md             # FR-018・FR-025 の反映先
specs/005-codex-speckit-support/spec.md      # 対象外・凍結の注記
specs/TAK-46-fixed-icon-colors/spec.md       # 凍結の注記
specs/TAK-49-video-seek-keys-normal-view/spec.md  # 凍結の注記、既存対応表を維持
specs/TAK-10-unbounded-counters/spec.md      # 仕様反映後に凍結の注記
Sources/FolzioCore/Operations/NameValidation.swift # 既存実装の照合のみ
Tests/FolzioCoreTests/NameValidationTests.swift    # 既存テストの照合のみ
Tests/FolzioCoreTests/FileOperationServiceTests.swift # 操作テストの照合のみ
```

**Structure Decision**: 既存 FR の本文・子項目を保持し、TAK-10 の不足分だけを子項目として追加する。製品仕様への反映はレビュー・検証後の最終段階に行う。

## Complexity Tracking

アプリの実装や依存は変更しない。憲章との衝突は保守者の具体的な注記依頼を優先して扱う。
