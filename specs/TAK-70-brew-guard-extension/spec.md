# Feature Specification: TAK-70 の Homebrew ガード拡張

**Feature Branch**: `chore/tak-70-tool-install-approval`
**Created**: 2026-11-06
**Status**: Draft
**Input**: [TAK-70](https://linear.app/takyoshida/issue/TAK-70) の PR #60 レビューへの対応

## User Scenarios & Testing

### User Story 1 - 更新や再導入も保守者が実行する (Priority: P1)

保守者は Codex と Kilo に直接の Homebrew 操作を任せず、必要な導入・更新を自分で実行できる。Claude の直接の `brew install` も保守者が実行する。

**Independent Test**: 実際に導入せず Codex の規則判定と Kilo・Claude の設定を検査し、実セッションの確認結果を区別して記録する。

**Acceptance Scenarios**:

1. **Given** 各エージェントの設定が有効、**When** Codex または Kilo が直接の `brew install`、`brew reinstall`、`brew upgrade`、`brew bundle` を実行する、**Then** 規則により拒否する。
2. **Given** Claude の設定が有効、**When** 直接の `brew install` を実行する、**Then** 規則により拒否する。
3. **Given** 保守者が確認する、**When** 手順を読む、**Then** 必要な導入・更新は保守者に依頼することと規則の限界が分かる。

### Edge Cases

- `brew bundle` はサブコマンドを問わず拒否するため `brew bundle check` などの読み取り系も対象となる。
- `brew list` や `brew info` は今回の禁止規則の対象外。
- 絶対パス・ラッパー・別コマンドなど、これらの規則で全経路を保証しない。

## Requirements

### Functional Requirements

- Codex と Kilo は直接の `brew install`・`reinstall`・`upgrade`・`bundle` を禁止し、保守者に実行を依頼する。
- Claude の直接の `brew install` は保守者が設定を `ask` から `deny` に変更する。
- 設定の検査と運用文書を追従し、実際にインストールしない。

## Success Criteria

- 4 種類のコマンドが Codex の規則判定で禁止となり、`brew list` は対象外になる。
- Kilo と Claude の設定の禁止規則を検査し、実セッションでの確認と区別する。
- `scripts/dev/check-all.sh` が成功する。

## Assumptions

- 2026-11-06 に保守者は 4 種類への対象拡大と Claude の deny を選択した。
- `specs/TAK-70-tool-install-approval/` は既に凍結されたため更新せず、追加の変更はこの記録で扱う。
- 製品仕様やアプリの動作は変更しない。

## 反映先

エージェント権限設定と開発用文書の変更。`specs/product/` への反映対象外。
