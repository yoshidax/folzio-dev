# Tasks: エージェント向けの規約の置き場所を AGENTS.md に限らない

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、[quickstart.md](quickstart.md)

この feature は文書の変更だけで、新しいコードとテストは作らない。検査（FR-309・FR-310）とその回帰テストは TAK-71 の
`scripts/dev/check-agents-md.sh` と `scripts/dev/tests/test_check_agents_md.py` を使う（research.md の R1）。
**TAK-71（PR #50）が `master` にマージされるまで、Phase 2 以降に進まない**。
アプリのコード（`Sources/`、`Tests/`）、`.github/`、`README*.md`、`docs/`、`specs/product/README.md`、憲章は変更しない。
`AGENTS.md` を変えるときは、`docs_private/agents/README.md` の基準に従い、PR の本文の「変更」に理由を書く。

## Phase 1: 準備

- [ ] T001 `git fetch origin master` の後、TAK-71 の変更（`scripts/dev/check-agents-md.sh` と `docs_private/agents/README.md`）が
  `origin/master` にあることを確かめる。なければ止めて、保守者に TAK-71 のマージを待つことを報告する。あれば `git merge origin/master` で
  取り込む（履歴は書き換えない）。
- [ ] T002 変更前の状態を記録する。`scripts/dev/check-all.sh` が成功すること、`awk 'END { print NR }' AGENTS.md` の行数、
  `grep -n 'AGENTS.md' specs/product/*.md specs/product/contracts/*.md` の結果を控える。

## Phase 2: User Story 67 - 運用の規則を足しても AGENTS.md が増えない (P2) 🎯 MVP

**Goal**: `AGENTS.md` から `specs/product/` の書き方の要点を外し、参照に置き換える。参照先の運用の文書が適用範囲を示す。

**Independent Test**: quickstart.md の 1・2・6・7。

- [ ] T003 [US67] `AGENTS.md` の「仕様と進捗【共通】」の節で、書き方の要点の4行（「`specs/product/` の書き方の要点（…）」の親項目と子項目 3 つ）
  と、検査の行（「`specs/product/` を変えたら …」）を、次の1行に置き換える（research.md の R2、FR-306（変更）、US66-AS2（変更））。
  - 「`specs/product/` を変える前に `specs/product/README.md` の「書き方のルール」を読む。変えたら `python3 scripts/dev/check-spec-format.py` を、
    反映の前と後に `scripts/dev/check-spec-ids.sh` を実行する。ID が衝突したら `docs_private/cloud-agent-workflow.md` の 7 章に従う」
  - インラインコードと引用を途中で改行しない。行数が T002 より 4 行減ったことを確かめる（SC-163）
- [ ] T004 [P] [US67] `AGENTS.md` から参照する `docs_private/` の運用の文書 9 個の、最初の見出しの直後に、適用範囲の行を置く
  （research.md の R3、FR-195（変更））。形式は `**適用範囲**: 【共通】` などとし、必要なら括弧で補足する。
  - `docs_private/agents/README.md`: 【共通】
  - `docs_private/agents/bugfix.md`: 【共通】（手順 1 と 5 はローカルと Cloud で違う）
  - `docs_private/agents/launch-debugging.md`: 【ローカル】（Cloud では保守者に依頼する）
  - `docs_private/agents/linear.md`: 【共通】
  - `docs_private/agents/parallel-worktree.md`: 【ローカル】
  - `docs_private/agents/skills-and-codex.md`: 【共通】（「Codex の自動実行」の節は【ローカル】。節の見出しにも付ける）
  - `docs_private/cloud-agent-workflow.md`: 【Cloud】
  - `docs_private/comment-translation-glossary.md`: 【共通】
  - `docs_private/repository-and-release.md`: 【共通】（公開の手順は保守者が行う）
  - 既存の冒頭の説明文に、適用範囲を述べた文（例: 「ローカルと Cloud の両方で使う」）があれば、重複しないように消す
- [ ] T005 [US67] `scripts/dev/check-all.sh` を実行し、成功することを確かめる。`check-agents-md.sh` の行で、警告も参照切れも出ないこと。

**Checkpoint**: `AGENTS.md` は 46 行以下で、参照先の文書はすべて適用範囲を示している。

## Phase 3: 製品仕様への反映（FR-195・FR-306・FR-307〜FR-310 ほか）

**Goal**: spec.md の変更点を `specs/product/overview.md` に反映する（research.md の R5、spec.md の「反映先」）。

**Independent Test**: quickstart.md の 3。`python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` が成功する。

- [ ] T006 反映の直前に `git fetch origin master` と `git merge origin/master` で取り込む。TAK-63 などが FR-306・`AGENTS.md`・
  ID を変えていないか確かめ、衝突していたら `docs_private/cloud-agent-workflow.md` の 7 章に従って、この feature の ID を振り直す
  （research.md の R6）。`scripts/dev/check-spec-ids.sh` を実行する。
- [ ] T007 `specs/product/overview.md` を、spec.md の決定後の本文で更新する。`## Clarifications` は feature 側に残す。
  - US30-AS2 と US66-AS2 を、spec.md の（変更）の本文に書き換える
  - US66 の後に US67（AS1・AS2）を足す
  - FR-195（「Cloud Agent の開発 workflow」の節）と FR-306（「製品仕様の形式の検査」の節）を、spec.md の（変更）の本文に書き換える
  - 「製品仕様の形式の検査」の節の後に、新しい節「エージェント向けの規約」を作り、FR-307〜FR-310 を置く
  - EC-213・EC-214 をエッジケースの末尾に、SC-162〜SC-165 を成功基準の末尾に、A-192〜A-195 を前提の末尾に足す
  - SC-094 と SC-161 を、spec.md の（変更）の本文に書き換える
- [ ] T008 `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行し、成功することを確かめる。
  警告が基準値を超えたら、`specs/product/README.md` の「書き方のルール」に従って直す。
- [ ] T009 `specs/TAK-72-agents-md-requirements/spec.md` の冒頭に、001 と同じ形式で移行済み・凍結の注記を入れる。

## Phase 4: 仕上げ

- [ ] T010 quickstart.md の 1〜7 を順に行い、結果を記録する。4（参照切れ）は、確認の後に元に戻して `git status` に差分がないことを確かめる。
- [ ] T011 `git diff --check` を実行し、変更をコミットして作業ブランチに push する。PR は保守者の依頼があったときだけ作る。
  PR の本文の「変更」に、`AGENTS.md` を変えた理由（TAK-72、Clarifications の Q2）を独立した項目で書く（`docs_private/agents/README.md`）。

## Dependencies

- Phase 1 → Phase 2 → Phase 3 → Phase 4 の順に進める
- T001 は TAK-71 のマージを前提とする
- T003 と T004 は別のファイルなので並列にできる（T004 の 9 個も互いに独立）。T005 は両方の後
- Phase 3 は Phase 2 の後に行う（反映は PR の最後の作業。`docs_private/cloud-agent-workflow.md` の 7 章）

## Parallel Example

```text
T003（AGENTS.md）と T004（docs_private/ の 9 個）を同時に進め、T005 でまとめて検査する。
```

## Implementation Strategy

- MVP は Phase 2（US67）。`AGENTS.md` が短くなり、参照先の文書が適用範囲を示す
- Phase 3 で仕様を実装に合わせ、Phase 4 で quickstart の確認を行う
- Cloud にはサブエージェントによる並列実装がないので、上の並列の印は依存関係を示すだけで、順に実施する
