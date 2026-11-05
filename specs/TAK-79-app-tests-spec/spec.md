# Feature Specification: 製品仕様の App テストターゲット

> **移行済み（2026-11-05）**: 現在の仕様は [specs/product/](../product/README.md) を正とする。
> このファイルは TAK-79 時点の記録として凍結しており、更新しない。

**Feature Branch**: `feature/tak-79-app-tests-spec`
**Created**: 2026-11-05
**Status**: Draft
**Input**: [TAK-79](https://linear.app/takyoshida/issue/TAK-79)

## User Scenarios & Testing

### User Story 1 - 仕様から現在のターゲットを確認する (Priority: P1)

保守者は製品仕様の Swift Package ターゲット一覧から、App のテストターゲットを含む現在の構成を確認できる。

**Independent Test**: 製品仕様の契約と `Package.swift`、日英の開発ガイドを照合する。

**Acceptance Scenarios**:

1. **Given** 保守者が製品仕様のターゲット一覧を読む、**When** テストターゲットを確認する、**Then** `FolzioCoreTests`、`FolzioAppTests`、`FolzioPerformanceTests` の 3 つが示されている。
2. **Given** 現行のターゲットを照合する、**When** 契約と Package.swift を比べる、**Then** 既存の製品ターゲット、`FixtureKit`、補助ツールの記載が維持される。

### Edge Cases

- ターゲットの一覧だけを追従し、テスト対象や依存関係を新たに定めない。
- 実装・アプリの動作・テストの実行方法を変更しない。

## Requirements

### Functional Requirements

- **契約（変更）**: `specs/product/contracts/app-bundle.md` のターゲット一覧に `FolzioAppTests` を加え、既存のターゲットと補助ツールの記載を維持する。
- 関連する既存要件: `FR-166`・`FR-168`（`specs/product/overview.md`）。既存要件の本文は変更しない。

## Success Criteria

### Measurable Outcomes

- 製品仕様の対象一覧に、現在の 3 つのテストターゲットが過不足なく記載される。
- 製品仕様の形式と ID の検査で新しいエラーを出さない。

## Assumptions

- 実装上のターゲット名の確認には `Package.swift` を用いる。
- 既存の補助ツールの名称を列挙する方式には変更しない。

## 反映先

| 対象 | 種別 | 反映先 |
| --- | --- | --- |
| Swift Package のターゲット一覧 | 変更 | `specs/product/contracts/app-bundle.md` |
