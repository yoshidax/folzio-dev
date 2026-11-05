# Feature Specification: ID 重複解消規則の整合

**Feature Branch**: `feature/tak-76-spec-id-policy`

**Created**: 2026-11-05

**Status**: Draft

**Input**: [TAK-76](https://linear.app/takyoshida/issue/TAK-76)

## User Scenarios & Testing

### User Story 1 - ID の重複を一貫して解消する (Priority: P1)

仕様の保守者は、並行作業の衝突とマージ後に発見された重複の双方について、憲章に整合する手順を確認できる。

**Why this priority**: 正本の不一致を残すと、作業者が誤った側の ID を変更するおそれがある。

**Independent Test**: EC-135 から憲章と共通手順をたどり、未マージ側がある場合と両方マージ済みの場合の変更対象と作業順序を判断できることを確認する。

**Acceptance Scenarios**:

1. **Given** 反映直前に `master` を取り込んで未マージ側とマージ済み側の ID の衝突が分かった、**When** 重複を解消する、**Then** 未マージ側を振り直してから反映し、マージ済み側を維持する。
2. **Given** 両方がマージ済みの ID が重複した、**When** 重複を解消する、**Then** 後にマージされた側を振り直す。
3. **Given** 凍結済み feature の ID を振り直した、**When** 旧 ID を参照する箇所を確認する、**Then** 文脈を確認して対象項目の参照を追従し、凍結記録は対応表の注記を除いて維持する。

### User Story 2 - 正本と参照先を見つける (Priority: P2)

仕様の保守者は ID の振り直し規則と具体的な手順の参照先を迷わず見つけられる。

**Why this priority**: 規則の分散による今後の食い違いを防ぐ。

**Independent Test**: EC-135、FR-193、ID の付け方、憲章から重複解消手順まで参照をたどり、同じ判断と手順に到達することを確認する。

**Acceptance Scenarios**:

1. **Given** FR-193 から EC-135 を参照する、**When** 重複解消の規則を確認する、**Then** 判断規則の正本である憲章と共通の詳細手順へたどれる。
2. **Given** ローカルまたは Cloud で仕様の ID を割り当てる、**When** ID の付け方から衝突時の手順を探す、**Then** 共通の詳細手順へたどれる。

### Edge Cases

- 旧 ID が複数項目を指す場合、文脈で変更対象を特定できなければ推測せず保守者に確認する。
- 凍結済み feature の記録は本文を変更せず、マージ済み ID の重複解消に必要な対応表のみを先頭に注記する。
- ID 重複検査は定義の重複を検出するが、参照先の意味の正しさを保証しない。

## Requirements

### Functional Requirements

- **EC-135（変更）**: 並行する feature 間で仕様 ID（`FR`・`SC`・`EC`・`A`・`US`）が重複した場合、Agent は憲章の仕様管理の規則に従い重複を解消する。
  - `specs/product/` への反映直前に `master` を取り込み、ID の衝突を確認する。
  - 未マージ側の ID が衝突した場合は、憲章に従って対象の ID を振り直してから `specs/product/` に反映する。
  - マージ済みの ID は、憲章に定める例外を除き振り直さない。
  - 作業の詳細は `docs_private/spec-id-conflicts.md` に従う。

### Key Entities

- **仕様 ID**: 項目の識別子。マージ状態と、重複時に指していた項目によって対応を判断する。

## Success Criteria

### Measurable Outcomes

- 未マージ側を含む衝突と両方マージ済みの衝突の 2 ケースで、EC-135・README・共通手順から憲章の判断規則をたどり、同じ側を特定できる。
- EC-135 に対象ラベル、検出時点、反映前に振り直す順序と、マージ済み ID の保護が記載されている。
- 憲章、FR-193、EC-135、ID の付け方の 4 か所から、共通の重複解消手順へ到達できる。
- 凍結記録と旧 ID の参照の扱いについて、対象の取り違えと未確認の一括置換を避ける手順がある。

## Assumptions

- TAK-67 で改定された憲章の優先順位、一意性、再利用禁止、凍結記録の例外は変更しない。詳細手順への参照先は変更する。
- アプリの動作・ソースコード・既存の ID 定義の番号は変更しない。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| EC-135 | 変更 | overview.md |

ID を持たない文書の変更先: `specs/product/README.md`（共通手順への導線）。憲章、共通手順、Cloud 手順も変更する。
