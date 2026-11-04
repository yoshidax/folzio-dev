# Tasks: 製品仕様の形式の検査のゲートへの組み込み

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[quickstart.md](quickstart.md)

検査のスクリプト・設定・基準値、アプリのコード（`Sources/`、`Tests/`）、`README*.md`、`docs/`、`scripts/dev/publish.sh`、
`scripts/dev/sdd-codex.py`、`.specify/templates/` は変更しない。User Story は1つなので、タスクは依存順に直列で行う。

## Phase 1: 準備

- [X] T001 `git fetch origin master` の後、`git merge-base --is-ancestor origin/master HEAD` で取り込み済みであることを確かめる。
- [X] T002 変更前の状態を記録する。`python3 scripts/dev/check-spec-format.py` と `test_check_spec_*.py` が成功することを確かめる。

## Phase 2: User Story 67 - 仕様の変更が検証ゲートと CI で検査される (P1) 🎯 MVP

**Goal**: ローカル・Cloud・CI・SDD increment の反映の手順で、同じ形式の検査が実行される。

**Independent Test**: quickstart.md の「失敗することの確認」と「記述の確認」。

- [X] T003 [US67] `.github/workflows/macos-swift-ci.yml` に Linux のジョブ `spec-checks` を足す（FR-308、plan.md の R1）。
  macOS のジョブは変えない（SC-164）。
- [X] T004 [US67] `AGENTS.md` を更新する（FR-307、R3）。ローカルの Phase の検証ゲートの手順 3、Cloud の「検証ゲート」の
  「Cloud で行う」と「CI で行う」、「製品仕様の書き方」（TAK-63 までは手で実行する旨を、ゲートと CI で実行する旨に改める）、
  区分の表の補足、「検証用コマンド」。
- [X] T005 [US67] `docs_private/cloud-agent-workflow.md` を更新する。4 章の CI の構成に Linux のジョブ、5 章の表に形式の検査と
  Linux のジョブ、7 章の反映の後の確認に形式の検査を足す。
- [X] T006 [US67] `.github/pull_request_template.md` の「検証」の案内に、形式の検査と、形式だけを変える変更での
  equivalence チェックを足す（FR-310）。
- [X] T007 [US67] `shared-skills/folzio-sdd-increment.md` の手順 5 に、反映の後の形式の検査を足す（FR-311、R4）。
  `scripts/dev/check-skill-sync.sh` が通ることを確かめる。
- [X] T008 [US67] sdd-increment の workflow の `merge_back` と `commit_product` に形式の検査を足し、版を上げる（FR-311、R4）。
  `.specify/workflow-src/` の3つと、登録済みの `.specify/workflows/<名前>/workflow.yml` の3つに同じ変更を入れ、
  `diff` で同じ内容であることを確かめる。`.specify/workflows/workflow-registry.json` の版を合わせる。

## Phase 3: 検証と反映

- [X] T009 quickstart.md の手順を行う。崩した一時コピーで検査が終了コード 1 になること、記述の確認、macOS のジョブの差分。
  変えた YAML が読めることを確かめる。
- [X] T010 Cloud の検証ゲートを行う（quickstart.md の「この feature の検証」の 2）。`git diff --check` も行う。
- [ ] T011 `specs/product/` への反映（plan.md の「反映の方針」）。`git merge origin/master` の後に `scripts/dev/check-spec-ids.sh` で
  ID の重複を確かめ、`overview.md` の節「製品仕様の形式の検査」に spec.md の「反映先」の項目を加え、A-187 を削除する。
  `README.md` の「形式の検査」に、実行される場所を加える。反映後に形式の検査と ID の検査を実行する。
  spec.md の冒頭に凍結の注記を入れる。
- [ ] T012 [MANUAL] PR を作った場合（保守者の依頼による）、CI の Linux のジョブと macOS のジョブの結果を確かめる。
  macOS のジョブはアプリのコードを変えないので、結果は変わらない見込み。
