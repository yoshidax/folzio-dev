# Feature Specification: 依存ツール導入時の確認

> **凍結（2026-11-06、製品仕様の反映対象外）**: この feature は開発環境の変更であり、`specs/product/` への反映対象外。
> このファイルは TAK-70 時点の記録として凍結しており、更新しない。

**Feature Branch**: `chore/tak-70-tool-install-approval`
**Created**: 2026-11-06
**Status**: Draft
**Input**: [TAK-70](https://linear.app/takyoshida/issue/TAK-70)

## User Scenarios & Testing

### User Story 1 - 依存ツールの導入前に確認する (Priority: P1)

Claude Code は導入前に保守者に確認し、Codex と Kilo Code は直接の Homebrew 導入を禁止して保守者に依頼する。

**Independent Test**: 各設定の規則とそのエージェントの判定方法を確認する。実際のインストールは実行しない。

**Acceptance Scenarios**:

1. **Given** 各エージェントで設定が有効、**When** `brew install webp` を直接実行する、**Then** Claude は保守者に確認し、Codex と Kilo は実行を禁止する。
2. **Given** 設定の判定範囲外から導入できる可能性がある、**When** 保守者が手順を読む、**Then** 設定だけで全経路を保証しないことと、依存ツールの導入前に確認する規則が分かる。

### Edge Cases

- 絶対パス・環境変数・ラッパー・シェルの入れ子・別の導入コマンドなど、単純な接頭辞で表せない経路の防御を保証しない。
- 設定はセッション開始時に読み込まれる。反映確認は新しいセッションで行う。
- Claude の保護された設定ファイルは保守者が変更する。自動的な編集を試みない。

## Requirements

### Functional Requirements

- 直接の `brew install` を Claude は承認対象とし、Codex と Kilo は禁止する。必要な導入は保守者に依頼する。
- 適用するルールとその限界、別の導入方法にも既存の確認規則が適用されることを文書に記す。
- 自動・手動の検証で実際にパッケージをインストールしない。

## Success Criteria

### Measurable Outcomes

- Claude に `brew install` の確認規則、Codex と Kilo に禁止規則がある。
- Codex のルール判定はインストール用の模擬コマンドで `forbidden` となり、読み取り用コマンドはその規則の対象とならない。
- 各エージェントの設定内容と、利用可能な環境での実動確認状況を区別して記録する。

## Assumptions

- 今回は実際に問題となった Homebrew の直接の `brew install` を機械的な対象とする。`pip install` や `npm install -g` などは依存ツールの導入前に保守者へ確認する既存規則で扱い、今回の自動判定には追加しない。
- Claude の設定変更は保守者が行う。新規セッションによる実動確認も各エージェントを利用できる環境が必要。

## 反映先

この変更はエージェントの権限設定と運用文書を対象とする。製品の機能や `specs/product/` の要件は変更しない。
