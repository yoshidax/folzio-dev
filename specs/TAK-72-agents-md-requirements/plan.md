# Implementation Plan: エージェント向けの規約の置き場所を AGENTS.md に限らない

**Branch**: `claude/tak-72-agents-md-spec` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-72-agents-md-requirements/spec.md`

## Summary

製品仕様のうち、内容を `AGENTS.md` の本文に置くことを求めている要件（FR-195・FR-306 と、その受け入れシナリオ・成功基準）を、
「エージェント向けの規約（`AGENTS.md` と、そこから参照する文書）」に置けばよい形に改める。あわせて、仕様が今後 `AGENTS.md` の
本文を指定しないこと（FR-307）、参照に読むべき作業を示すこと（FR-308）、行数の上限と参照切れの検査（FR-309・FR-310）を要件にする。

実装は文書の変更だけで行う。

- `AGENTS.md` から `specs/product/` の書き方の要点（4 行）を外し、`specs/product/README.md` を読むという参照に置き換える（50 → 46 行）
- `AGENTS.md` から参照する `docs_private/` の運用の文書の冒頭に、適用範囲の行を置く
- 検査（FR-309・FR-310）は TAK-71 の `scripts/dev/check-agents-md.sh` をそのまま使う。新しいコードは書かない
- 変更点を `specs/product/overview.md` に反映する

TAK-71（PR #50）のマージを待ってから実装する（research.md の R1〜R7）。

## Technical Context

**Language/Version**: Markdown の文書だけ。コードは変えない（検査は TAK-71 の bash スクリプトを使う）

**Primary Dependencies**: TAK-71 の `scripts/dev/check-agents-md.sh` と `docs_private/agents/README.md`（PR #50、未マージ）

**Storage**: リポジトリのファイル

**Testing**: `scripts/dev/check-all.sh`（`check-agents-md.sh` と `test_check_*.py` を含む）、
`python3 scripts/dev/check-spec-format.py`、`scripts/dev/check-spec-ids.sh`。quickstart.md の確認手順

**Target Platform**: 保守者の macOS と Cloud の Linux

**Project Type**: 運用文書と製品仕様。アプリ（Swift）のコードは変えない

**Performance Goals**: 該当なし

**Constraints**: `AGENTS.md` の行数を増やさない（SC-163）。`specs/product/` の書き方のルールと形式の検査に従う

**Scale/Scope**: 変更するファイルは `AGENTS.md`、`docs_private/` の運用の文書 9、`specs/product/overview.md`。
`specs/product/README.md` は変えない（FR-306 の本文の要件は満たしている）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 対象外 | アプリのコードを変えない |
| II 体感パフォーマンス | 対象外 | アプリの動作を変えない |
| III キーボードファースト | 対象外 | UI を変えない |
| IV テスト必須 | 適合 | 検査（FR-309・FR-310）の回帰テストは TAK-71 の `test_check_agents_md.py` にある。この feature はコードを足さない |
| V シンプルさ | 適合 | 新しい依存・スクリプトはない。適用範囲の行を検査する仕組みは作らない（R4） |

Phase 1 の後の再確認: data-model.md と quickstart.md の設計でも、上の判定は変わらない。

「仕様の管理」との関係: 変更点は、実装と検証の後に `specs/product/overview.md` へ反映する。反映の前と後に `check-spec-ids.sh` を
実行し、反映の後に `check-spec-format.py` を実行する。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-72-agents-md-requirements/
├── spec.md
├── plan.md              # このファイル
├── research.md          # R1〜R7
├── data-model.md        # エージェント向けの規約・参照・適用範囲
├── quickstart.md        # SC-094・SC-161〜SC-165 の確認手順
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で作る
```

### Files changed by this feature

```text
AGENTS.md                                   # 書き方の要点を参照に置き換える（R2）
docs_private/agents/README.md               # 冒頭に適用範囲の行（R3）
docs_private/agents/bugfix.md               # 同上
docs_private/agents/launch-debugging.md     # 同上
docs_private/agents/linear.md               # 同上
docs_private/agents/parallel-worktree.md    # 同上
docs_private/agents/skills-and-codex.md     # 同上
docs_private/cloud-agent-workflow.md        # 同上
docs_private/comment-translation-glossary.md  # 同上
docs_private/repository-and-release.md      # 同上
specs/product/overview.md                   # 変更点の反映（R5）
```

**Structure Decision**: 新しいファイルとコードは作らない。既存の文書の冒頭に 1 行を足し、`AGENTS.md` の 4 行を 1 行の参照にまとめる。

## Complexity Tracking

該当なし（憲章の違反はない）。
