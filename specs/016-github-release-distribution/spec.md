# Feature Specification: GitHub Releases での配布

> **移行済み（2026-10-29）**: 現在の仕様は [specs/product/](../product/README.md) を正とする。
> このファイルは 016 時点の記録として凍結しており、更新しない。

**Feature Branch**: `016-github-release-distribution`
**Created**: 2026-10-29
**Status**: Migrated and frozen
**Input**: 公開用リポジトリの公開コミットから Apple silicon 専用アプリを作り、GitHub Release のドラフトとして配布する。

## User Scenarios & Testing

### User Story 1 - 配布物を準備する (Priority: P1)

公開担当者は開発用プロジェクトから公開用リポジトリの確定したコミットを使い、対象とバージョンが明確なアプリを作る。

**Independent Test**: 一時公開用リポジトリの固定コミットから配布物を作成し、内容とメタデータを調べる。

**Acceptance Scenarios**:

1. **Given** 公開用コミットが確定し公開済みである、**When** 配布物を準備する、**Then** そのコミットに対応した macOS 15 以降・Apple silicon 用 ZIP が作られる。
2. **Given** 対象コミットやバージョンが確認できない、**When** 準備を試みる、**Then** 理由を示して停止する。

### User Story 2 - ドラフトを作成する (Priority: P1)

公開担当者は配布物とリリースノートを確認し、開発用プロジェクトから公開用リポジトリにドラフトを作成する。

**Independent Test**: 外部公開を行わない代替手段でタグ・リポジトリ・添付物とドラフト指定を確認する。

**Acceptance Scenarios**:

1. **Given** 対応する公開済みタグと検証済み配布物がある、**When** ドラフト作成を指示する、**Then** 対象タグに ZIP とリリースノートを添付した未公開の Release が作成される。
2. **Given** タグが存在しない、または配布物と異なるコミットを指す、**When** 作成を指示する、**Then** ドラフト作成前に停止する。

### User Story 3 - 利用者が入手して起動する (Priority: P1)

利用者は対応環境、インストール方法、未公証アプリの注意を読んでアプリを入手し、起動できる。

**Independent Test**: 英語版・日本語版の案内を確認し、ユーザーが配布 ZIP を展開して起動する。

**Acceptance Scenarios**:

1. **Given** 利用者が案内を読む、**When** 対応環境を確認する、**Then** Apple silicon 専用で Intel Mac は対象外と分かる。
2. **Given** macOS が初回起動をブロックする、**When** 利用者が配布元を信頼すると判断する、**Then** 案内を参照してシステム設定から開ける。

### Edge Cases

- **EC-124**: 公開用リポジトリに未コミット変更がある、想定と異なるリモートやコミットを参照する、または公開済みの状態を確認できない場合は理由を示して中止する。
- **EC-125**: 同名タグや Release が存在する、成果物が欠ける・一致しない、または外部コマンドが失敗した場合は上書きせず停止し、再開に必要な状況を表示する。
- **EC-126**: GUI または実際のダウンロードからの確認が未実施の場合は未実施と記録し、完了扱いにしない。

## Requirements

### Functional Requirements

- **FR-169**: 公開担当者は開発用プロジェクトから配布物の準備と Release ドラフト作成を操作できる。既存の公開用リポジトリへの書き出し・公開担当者によるコミットと push は維持する。
- **FR-170**: 配布物は公開用リポジトリで確定・公開された単一のコミットから生成し、リリースタグがそのコミットを指すことを確認する。
- **FR-171**: 配布 ZIP の名前と内容はバージョン、macOS、Apple silicon 対象を識別でき、アプリのバージョンはリリースタグと一致する。
- **FR-172**: 配布アプリは ad hoc 署名とし、Developer ID 署名・Apple 公証を行わない。
- **FR-173**: 公開用 Release は指定したリポジトリと既存の公開済みタグに対してドラフトとして作成し、配布 ZIP、チェックサム、リリースノートを含める。公開は担当者が確認後に行う。
- **FR-174**: README の英語版と日本語版は同じ内容で、配布場所、macOS 15 以降・Apple silicon 専用、Intel 対象外、インストールと未公証アプリの開き方を案内する。
- **FR-175**: 配布前にアーキテクチャ、バンドルのバージョン、署名の整合性、ZIP の内容とチェックサムを確認し、展開後の起動と3ペイン表示をユーザーが確認できる手順を提供する。
- **FR-176**: 開発用の非公開ファイルや履歴を配布物へ含めず、アプリにネットワーク機能を追加しない。既存の公開時の除外・テストを維持する。

### Key Entities

- **公開コミット**: 公開用リポジトリに存在する、配布の基準となる固定されたコミット。
- **リリース**: 公開コミットを指すタグ、バージョン、ZIP、チェックサムとリリースノートの組。

## Success Criteria

### Measurable Outcomes

- **SC-079**: 検証済み ZIP の実行ファイルは arm64 のみで、アプリのバージョン・タグ・ファイル名が一致する。
- **SC-080**: タグ不一致、未公開コミット、破損・不一致の成果物の各ケースでドラフト作成が行われない。
- **SC-081**: 両言語の README に同じ対応環境と起動手順があり、ユーザーが展開後のアプリで3ペインを確認できる。
- **SC-082**: 検証用の一時環境でドラフト作成までの指定内容を確認でき、本番 Release の公開を伴わない。

## Assumptions

- **A-95**: Intel Mac、Universal Binary、自動更新、Mac App Store、Developer ID 署名・公証は対象外。
- **A-96**: 公開担当者が公開用リポジトリのコミット・push、公開済みタグの作成と push、GUI 確認、ドラフトの最終確認と公開を行う。
- **A-97**: 配布担当者は macOS 上に必要な Swift/Xcode ツール、Git、GitHub CLI と適切な認証を用意する。配布のためのネットワーク通信は開発ツールによる明示操作でありアプリの通信ではない。

## Clarifications

### Session 2026-10-29

- Q: Intel 実機を確認できない場合の配布対象は？ → A: Apple silicon 専用。Intel 対象外を明記する。
- Q: チェックサムを添付するか？ → A: SHA-256 を添付する。配布物の破損・取り違えを確認できる。
- Q: 公開済みタグの作成は誰が行うか？ → A: push は既存規約に従いユーザーが行い、ツールは対象を確認する。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| FR-169 | 追加 | overview.md |
| FR-170 | 追加 | overview.md |
| FR-171 | 追加 | overview.md |
| FR-172 | 追加 | overview.md |
| FR-173 | 追加 | overview.md |
| FR-174 | 追加 | overview.md |
| FR-175 | 追加 | overview.md |
| FR-176 | 追加 | overview.md |
| SC-079 | 追加 | overview.md |
| SC-080 | 追加 | overview.md |
| SC-081 | 追加 | overview.md |
| SC-082 | 追加 | overview.md |
| EC-124 | 追加 | overview.md |
| EC-125 | 追加 | overview.md |
| EC-126 | 追加 | overview.md |
| A-95 | 追加 | overview.md |
| A-96 | 追加 | overview.md |
| A-97 | 追加 | overview.md |
