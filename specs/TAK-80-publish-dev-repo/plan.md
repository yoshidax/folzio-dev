# Implementation Plan: 開発用リポジトリの公開の準備

**Branch**: `claude/modest-euler-2bxq9s` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-80-publish-dev-repo/spec.md`

## Summary

保守者が開発用リポジトリ（`yoshidax/folzio-dev`）を公開した後の運用に、文書・書き出し・CI・規約を合わせる。

- README の冒頭に、開発用リポジトリであることと公開用リポジトリへの案内を置き、書き出しで除く（US68）。
  除く処理は開発専用の小さなスクリプトに分け、`publish.sh` から呼ぶ（research R1・R2）。
- CI を PR への push のたびに動かし、CI の起動・再実行の許可の規則（TAK-53）をなくす（US69、R3・R5）。
- `master` のブランチ保護と fork の workflow の承認の設定手順を書く。設定は保守者が行う（US70、R4）。
- 「非公開」を前提にした現行の記述を直す（FR-317、R6）。
- 最後に `specs/product/` へ反映する。

## Technical Context

**Language/Version**: Bash（macOS の bash 3.2 でも動く書き方）、Python 3（テスト）、GitHub Actions の YAML、Markdown

**Primary Dependencies**: git、awk（BSD と GNU の両方で動く書き方）。新しい依存は加えない

**Storage**: なし

**Testing**: `python3 -m unittest`（`scripts/dev/tests/`）。注記を除くスクリプトの単体テストは Cloud でも実行できる。
`test_publish_folzio` は `rsync` が要るので CI（macOS）で確かめる

**Target Platform**: 開発用リポジトリの運用（macOS のローカル、Cloud、GitHub Actions の macOS ランナー）

**Project Type**: 開発の運用（スクリプト・設定・文書）。アプリのコードは変えない

**Performance Goals**: なし

**Constraints**: アプリにネットワーク機能を加えない。公開用リポジトリに開発用のファイルと印を書き出さない。履歴を書き換えない

**Scale/Scope**: README 2 件、スクリプト 2 件、テスト 2 件、workflow 1 件、Agent の設定 2 件（`.claude/settings.json` は保守者）、
運用の文書 4〜5 件、`AGENTS.md`、`specs/product/` 3 ファイル

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. ローカル完結・プライバシー | 適合 | アプリは変えない。公開前の点検は Issue で済み、公開から外すものはない（保守者の決定） |
| II. 体感パフォーマンス | 対象外 | アプリの動作を変えない |
| III. キーボードファースト & アクセシビリティ | 対象外 | UI を変えない |
| IV. テスト必須 | 適合 | 注記を除くスクリプトの単体テストと、書き出しの回帰テスト（FR-316）を加える |
| V. シンプルさ（YAGNI） | 適合 | 新しい依存を加えない。`docs_private/` の改名などの大きな整理はしない（R6） |
| マージ前のゲート | 適合 | 自動テストは CI と Cloud の検査で確かめる。起動スモークは保守者に依頼する（アプリは変えないが、規約に従う） |

Phase 1 の後の再確認: 違反はない。Complexity Tracking は不要。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-80-publish-dev-repo/
├── spec.md
├── plan.md              # このファイル
├── research.md          # R1〜R6 と出典
├── contracts/
│   └── readme-dev-note.md   # README の注記と書き出しの契約
├── quickstart.md        # 検証の手順
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks で作る
```

data-model.md は作らない（データを扱わない）。

### 変更するファイル（リポジトリのルートから）

```text
README.md, README.ja.md                       # 注記を追加（US68、FR-313）
scripts/dev/strip-readme-dev-note.sh          # 新規。注記を除き、印を検査する（FR-314・FR-315）
scripts/dev/publish.sh                        # 一時ディレクトリの README に上を適用
scripts/dev/tests/test_strip_readme_dev_note.py   # 新規。単体テスト（Cloud でも実行可）
scripts/dev/tests/test_publish_folzio.py      # 書き出しの回帰テスト（FR-316、CI で実行）
.github/workflows/macos-swift-ci.yml          # pull_request の types に synchronize・reopened（FR-190、SC-156）
AGENTS.md                                     # CI の許可の行を削除、公開の文言を明確化（FR-317・FR-320）
.codex/rules/sdd.rules, .kilo/kilo.jsonc      # CI の起動・再実行の確認を削除（FR-320）
.claude/settings.json                         # 同上。Agent は編集できないので、保守者に依頼する（A-198）
docs_private/cloud-agent-workflow.md          # 3・4・5 章の CI と PR の記述
docs_private/repository-and-release.md        # 非公開の前提を直し、ブランチ保護の手順と注記の書き出しを追加（FR-317・FR-318）
docs_private/agents/README.md                 # TAK-53 の例を替える
.github/pull_request_template.md              # CI の実行の種類の記述（workflow_dispatch の前提）を直す
specs/product/overview.md, README.md, contracts/scripts.md   # 最後に反映
```

**Structure Decision**: 既存の配置（公開用は `scripts/`、開発専用は `scripts/dev/`）に従う。新しいスクリプトは開発専用なので
`scripts/dev/` に置き、書き出しから自動で除かれる（FR-177）。

## 設計の要点

### README の注記（R1、[contracts/readme-dev-note.md](contracts/readme-dev-note.md)）

- 言語の切り替えの行の後に、開始の印・`> [!NOTE]` の注記・終了の印・空行を置く。
- 書き出しは、開始の印から終了の印までと、直後の空行 1 行を除く。結果は注記を置く前の README と一致する。
- 印の対応が崩れていれば（開始だけ、終了だけ、逆順、入れ子、2 つ以上）非ゼロで終了し、`publish.sh` は同期の前に止まる。
- 除いた後に印の文字列（`dev-repo-note:`）が残れば（行の一部に書いた場合など）、同じく止まる。
- 印がなければ README を変えない（EC-216）。

### CI（R3）

- `types: [opened, synchronize, reopened, ready_for_review]`。それ以外（`workflow_dispatch`、`concurrency`、`permissions`、ジョブの名前）は変えない。
- この PR の CI 自体も、公開後の条件（push のたびに動く）で動く。

### ブランチ保護（R4）

- `docs_private/repository-and-release.md` に「開発用リポジトリの公開とブランチ保護」の節を足し、2 つの ruleset と fork の承認の
  設定、設定後の確かめ方（CI が成功していない PR はマージできない、`merge-to-master.sh` の push が通る、強制 push が拒否される）を書く。
- 未確認の点（rulesets の可否、bypass の動作）は、手順の中に「確かめる」として書き、使えない場合の classic の代わりの設定も書く。

### 規約と権限（R5）

- `AGENTS.md` の行数は 46 行（上限 50、警告 45）。CI の許可の行を消すと 45 行になる。公開の文言の行は書き換えで、行数を増やさない。
- `AGENTS.md` の変更の理由は、PR の本文の「変更」に独立した項目で書く（`docs_private/agents/README.md` の「追加の理由を残す」）。

### 仕様の反映

- PR の最後の作業として、`git merge origin/master` の後に `scripts/dev/check-spec-ids.sh` で ID の衝突を確かめ、
  `specs/product/` に反映する（spec.md の「反映先」）。FR-317〜FR-320 は overview.md に新しい節「開発用リポジトリの公開」を作って置く。
- 反映した項目と差分を保守者に示し、承認を得てからコミットする（`docs_private/cloud-agent-workflow.md` の 7 章）。

## 保守者が行うこと（Agent はできない）

1. この PR の前に、リポジトリを公開する（A-196）。
2. `.claude/settings.json` の `permissions.ask` から、CI の起動・再実行の 3 項目を消す（A-198）。
3. この PR の CI が 1 回動いた後に、手順に従ってブランチ保護と fork の承認を設定し、確かめる（A-197）。
4. マージ後に、書き出し（`scripts/dev/publish.sh`）で README から注記が消えることを確かめる（ローカルの macOS）。

## Complexity Tracking

違反はないので記入しない。
