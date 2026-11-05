# Feature Specification: ID 重複解消規則の整合

**Feature Branch**: `feature/tak-76-spec-id-policy`

**Created**: 2026-11-05

**Status**: Draft

**Input**: [TAK-76](https://linear.app/takyoshida/issue/TAK-76)

## User Scenarios & Testing

### User Story 1 - ID の重複を一貫して解消する (Priority: P1)

仕様の保守者は、並行作業の衝突とマージ後に発見された重複の双方について、憲章に整合する手順を確認できる。

**Why this priority**: 正本の不一致を残すと、作業者が誤った側の ID を変更するおそれがある。

**Independent Test**: 未マージ側がある場合と両方マージ済みの場合を、憲章・EC-135・手順書に照らし、それぞれ変更すべき側を一意に判断できることを確認する。

**Acceptance Scenarios**:

1. **Given** 未マージ側とマージ済み側で ID が衝突した、**When** 重複を解消する、**Then** 未マージ側を振り直し、マージ済み側を維持する。
2. **Given** 両方がマージ済みの ID が重複した、**When** 重複を解消する、**Then** 後にマージされた側を振り直す。
3. **Given** 凍結済み feature の ID を振り直した、**When** 旧 ID を参照する箇所を確認する、**Then** 文脈を確認して対象項目の参照を追従し、凍結記録は対応表の注記を除いて維持する。

### User Story 2 - 正本と参照先を見つける (Priority: P2)

仕様の保守者は ID の振り直し規則と具体的な手順の参照先を迷わず見つけられる。

**Why this priority**: 規則の分散による今後の食い違いを防ぐ。

**Independent Test**: EC-135、FR-193、ID の付け方、憲章から重複解消手順まで参照をたどり、同じ判断と手順に到達することを確認する。

**Acceptance Scenarios**:

1. **Given** FR-193 から EC-135 を参照する、**When** 重複解消の規則を確認する、**Then** 詳細な手順の正本へたどれる。
2. **Given** 仕様の ID を割り当てる、**When** ID の付け方から衝突時の手順を探す、**Then** 詳細な手順の正本へたどれる。

### Edge Cases

- 旧 ID が複数項目を指す場合、文脈で変更対象を特定できなければ推測せず保守者に確認する。
- 凍結済み feature の記録は本文を変更せず、マージ済み ID の重複解消に必要な対応表のみを先頭に注記する。
- ID 重複検査は定義の重複を検出するが、参照先の意味の正しさを保証しない。

## Requirements

### Functional Requirements

- **EC-135（変更）**: 仕様 ID が重複した場合、Agent は重複の解消手順に従う。
  - 未マージの ID がマージ済み ID と重複した場合は、未マージ側を振り直す。
  - 両方がマージ済みの ID が重複した場合は、後にマージされた側を振り直す。
  - 重複解消の詳細は `docs_private/cloud-agent-workflow.md` の 7 章に従う。

### Key Entities

- **仕様 ID**: 項目の識別子。マージ状態と、重複時に指していた項目によって対応を判断する。

## Success Criteria

### Measurable Outcomes

- 未マージ側を含む衝突と両方マージ済みの衝突の 2 ケースで、憲章・製品仕様・手順書が同じ側を指定する。
- 憲章、FR-193、EC-135、ID の付け方の 4 か所から、重複解消手順へ到達できる。
- 凍結記録と旧 ID の参照の扱いについて、対象の取り違えと未確認の一括置換を避ける手順がある。

## Assumptions

- TAK-67 で改定された憲章の優先順位、一意性、再利用禁止、凍結記録の例外は変更しない。
- アプリの動作・ソースコード・既存の ID 定義の番号は変更しない。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| EC-135 | 変更 | overview.md |
