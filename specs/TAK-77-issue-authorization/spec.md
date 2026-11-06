# Feature Specification: Issue 対応の操作とレビュー

> **移行済み（2026-11-06）**: 現在の仕様は [specs/product/](../product/README.md) を正とする。
> このファイルは TAK-77 時点の記録として凍結しており、更新しない。

**Feature Branch**: `work`

**Created**: 2026-11-06

**Status**: 設計レビュー承認済み

**Input**: [TAK-77](https://linear.app/takyoshida/issue/TAK-77)

## User Scenarios & Testing

### User Story 1 - Issue の依頼から PR を作成・更新する (Priority: P1)

保守者が Codex に Issue 対応を依頼すると、Agent は Issue の範囲で作業と検証を行い、作業ブランチに通常 push して PR を作成・更新できる。

**Independent Test**: Issue の依頼から設計レビューを経て PR を作る例と、PR を明示的に除外した依頼を規約に照らして判断する。

**Acceptance Scenarios**:

1. **US27-AS4（変更）**: **Given** 保守者が Issue の対応を依頼し PR 作成を除外していない、
   - **When** Agent が必要な検証とレビューを経て PR を作成する、
   - **Then** Agent は対象 Issue に PR のリンクを追加し `In Review` に更新して結果を知らせる。Linear に接続できなければ失敗を報告する。
2. **Given** 保守者が Issue 対応を依頼した、**When** 対応範囲の検証、コミット、通常 push、PR 作成・更新・Ready 化を行う、**Then** 操作ごとの追加依頼を要求しない。
3. **Given** 保守者が PR の作成や Ready 化を明示的に除外した、**When** Agent が依頼の範囲を判断する、**Then** 除外された操作を行わない。
4. **Given** PR 作成または Ready 化で CI が自動起動する、**When** 依頼の範囲を判断する、**Then** その自動 CI は Issue 対応の依頼に含まれる。

### User Story 2 - 成果物のレビューと手動 CI を区別する (Priority: P1)

保守者は設計と製品仕様の変更をレビューでき、追加の CI 実行は従来どおり個別に判断できる。

**Independent Test**: 設計レビュー前、製品仕様反映後、追加 CI 起動前のそれぞれについて停止条件を確認する。

**Acceptance Scenarios**:

1. **Given** 仕様・計画・タスクの分析が終わった、**When** 実装に進もうとする、**Then** 保守者の設計レビューと承認を待つ。
2. **Given** 製品仕様への反映と凍結注記の案ができた、**When** その変更をコミットしようとする、**Then** 変更 ID と差分を提示し保守者の承認を待つ。
3. **US28-AS2（変更）**: **Given** 追加のコミットを push した、
   - **When** CI が自動では動かない、
   - **Then** Agent は手動実行・再実行ごとに理由と対象を示して許可を得るか、保守者に実行を頼む。

### User Story 3 - 保護を維持して操作する (Priority: P1)

保守者は作業ブランチへの操作を依頼しながら、保護されたブランチと履歴、実行環境の承認を維持できる。

**Independent Test**: 許可された操作と master / main、強制 push、削除、別リモート、曖昧な宛先を比較し、フック無効時も含めて各保護の適用範囲を確かめる。

**Acceptance Scenarios**:

1. **Given** Agent が通常 push を行う、**When** 宛先を確認する、**Then** 許可されたリモートの作業ブランチだけを対象とする。
2. **Given** master / main、強制 push、削除またはマージを行おうとする、**When** Agent が操作を判断する、**Then** 実行しない（FR-189・US29-AS3）。
3. **Given** アプリや実行環境の承認・制限が必要、**When** リポジトリ設定を適用する、**Then** 外側の制限を解除できると扱わず、拒否または未承認を報告する。

### Edge Cases

- Issue が不明確、依頼範囲に入らない、またはユーザーが特定の操作を除外したときは、推測で範囲を拡張しない。
- 手動 CI の追加起動・再実行は自動 CI と別であり、追加 push 後に未実施なら検証未完了として報告する。
- 安全な push の条件を実効的に限定できない場合、無条件の許可を加えず限界を報告する。
- 人による GUI 確認、設計承認、製品仕様の反映承認を別の操作の許可で代替しない。

## Requirements

### Functional Requirements

- **FR-198（変更）**: Agent は、保守者の Issue 対応の依頼に含まれる範囲で PR を作成・更新できなければならない。
  - 依頼に含まれる検証、コミット、作業ブランチへの通常 push、PR の作成・更新・Ready 化に操作ごとの追加依頼を求めない。
  - PR 作成または Ready 化に伴う自動 CI は Issue 対応の依頼に含める。
  - 保守者が操作を明示的に除外した場合は行わない。
  - 設計レビューと製品仕様の反映差分の承認、手動 CI の個別許可、実行環境の承認は別に扱う。
  - マージと master への統合は保守者が行う。

### Key Entities

- **Issue 対応の依頼**: Issue の内容とユーザーの制約により範囲が定まる作業の依頼。
- **成果物レビュー**: 実装前の設計、またはコミット前の製品仕様反映差分に対する保守者の判断。

## Success Criteria

### Measurable Outcomes

- **SC-090（変更）**: 新しい Cloud セッションが Issue の指定から設計・仕様反映のレビューと必要な手動確認を経て、操作ごとの追加依頼なしに PR の作成と CI 結果の確認まで進められる。
- 対象となる 5 種類の保護操作（master / main、強制、削除、別リモート、不明な宛先）の判断を、許可対象の通常 push と区別できる。
- Issue の依頼、自動 CI、手動 CI、設計レビュー、製品仕様反映の 5 ケースについて、適切な承認の要否が規約間で一致する。
- `SC-092`・`SC-094`（overview.md）と、CI と手動確認の既存条件を維持する。

## Assumptions

- 保守者は A 案（設計レビューと製品仕様の反映差分レビューの維持）を 2026-11-06 に了承した。
- 実行環境や Codex アプリによる承認を、リポジトリの設定だけで保証・無効化しない。
- 既存の Cloud の操作制限（FR-189）と、保守者のみが行うマージは維持する。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| US27-AS4 | 変更 | overview.md |
| US28-AS2 | 変更 | overview.md |
| FR-198 | 変更 | overview.md |
| SC-090 | 変更 | overview.md |
