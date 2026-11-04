# Implementation Plan: 開発用と公開用の workflow の管理

**Branch**: `claude/gracious-dijkstra-du6nx2` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-40-oss-workflow-policy/spec.md`

## Summary

開発用リポジトリの `.github/workflows/` をディレクトリごと公開書き出しから除き（`.gitattributes`）、公開用リポジトリだけで動かす workflow は
`scripts/dev/oss-workflows/` で管理する。`scripts/dev/publish.sh` は、`git archive` の後に、`HEAD` の管理元の直下にある `*.yml`・`*.yaml` を
書き出しの `.github/workflows/` に置き、混入と配置を同期の前に確かめる。公開先の `.github/workflows/` は保護しないので、書き出しを繰り返すと
管理元と一致する。回帰テストを `scripts/dev/tests/test_publish_folzio.py` に足し、方針を `docs_private/repository-and-release.md` に書く。
公開用 workflow の本体は TAK-41 で作る（research.md の R1〜R7）。

## Technical Context

**Language/Version**: Bash（`scripts/dev/publish.sh`）、Python 3（`scripts/dev/tests`）、GitHub Actions の YAML（変更しない）

**Primary Dependencies**: `git`（`archive`、`ls-tree`、`cat-file`）、`tar`、`rsync`。すべて既存の依存

**Storage**: なし（リポジトリのファイル）

**Testing**: `python3 -I -m unittest`（`scripts/dev/tests/test_publish_folzio.py`）。Cloud では `rsync` を入れれば実行できる（research.md の R6）

**Target Platform**: 保守者の macOS（書き出し）、GitHub Actions（開発用 CI。変更しない）

**Project Type**: 開発・公開用のスクリプトと運用文書。アプリ（Swift）のコードは変えない

**Performance Goals**: なし（書き出しの時間は、workflow のファイル数件の分しか増えない）

**Constraints**: 公開先の初期化・同期・ステージより前に検査で止まる（`contracts/scripts.md`）。公開版のファイルに `scripts/dev/` などへの参照を書かない

**Scale/Scope**: 変更するファイルは 8 前後（`.gitattributes`、`publish.sh`、テスト、管理元の README、文書 3、`specs/product/` の 2）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 適合 | アプリのコードを変えない。`scripts/check-no-network.sh` の対象（Swift のソース）に変更はない。書き出しの `$HOME`・ユーザー名の検査は、公開用 workflow にも広げる |
| II 体感パフォーマンス | 対象外 | アプリの動作を変えない |
| III キーボードファースト | 対象外 | UI を変えない |
| IV テスト必須 | 適合 | 書き出しのロジックの変更に、回帰テスト（FR-294）を足す。異常系（除外設定の不備、定義ではないファイル、サブディレクトリ）も含める |
| V シンプルさ | 適合 | 新しい依存はない。管理元は既存の `scripts/dev/` の中に置き、除外の指定は 1 行だけ足す。公開用 workflow の本体や変換の仕組み（テンプレート・置換）は作らない |

Phase 1 の後の再確認: data-model.md と contracts/ の設計でも、上の判定は変わらない。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-40-oss-workflow-policy/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── publish-workflows.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
.gitattributes                          # /.github/workflows export-ignore を追加
.github/workflows/macos-swift-ci.yml    # 変更しない（開発用のまま）
scripts/dev/
├── publish.sh                          # 混入検査の対象の拡大、公開用 workflow の配置と確認
├── oss-workflows/
│   └── README.md                       # 新規。管理元の説明（定義はまだない）
└── tests/
    └── test_publish_folzio.py          # 回帰テストを追加
docs_private/
├── repository-and-release.md           # 方針の正本。「GitHub Actions の workflow」の節など
└── cloud-agent-workflow.md             # 4 章に 1 文
AGENTS.md                               # 「公開用リポジトリ」に 1 行
specs/product/
├── overview.md                         # 反映（spec.md の「反映先」）
└── contracts/scripts.md                # 反映（workflow の除外と配置）
```

**Structure Decision**: 既存の開発専用の配置（`scripts/dev/`、`docs_private/`）の中で完結させる。公開版のファイル（`README*.md`、`docs/`、
`Sources/`、`scripts/` 直下）は変えない（research.md の R8）。

## 反映の方針

- `specs/product/overview.md`: spec.md の「反映先」のとおり。新しい小見出し「開発用と公開用の workflow」を「公開用と開発用スクリプト」の後に置く
- `specs/product/contracts/scripts.md`: [contracts/publish-workflows.md](contracts/publish-workflows.md) の「除外」と「配置」の要点を加える
- 反映の直前に `git merge origin/master` で取り込み、`scripts/dev/check-spec-ids.sh` で ID の衝突を確かめる（手順書 7 章）

## Complexity Tracking

違反はない。
