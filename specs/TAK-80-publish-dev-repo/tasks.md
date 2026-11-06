# Tasks: TAK-80 開発用リポジトリの公開の準備

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、
[contracts/readme-dev-note.md](contracts/readme-dev-note.md)、[quickstart.md](quickstart.md)

**Tests**: FR-316 が書き出しの回帰検証を求めるので、US68 にテストのタスクを置く。

## Phase 1: 設計

- [x] T001 `specs/TAK-80-publish-dev-repo/` に仕様・計画・調査・契約・検証手順を作り、`speckit-analyze` で整合性を確かめる。
- [x] T002 `specs/TAK-80-publish-dev-repo/` の設計を保守者に示し、実装の前に承認を得る。
  2026-11-06 に承認。ブランチ保護に例外を置かず、`merge-to-master.sh` を削除する（論点 1 は案 B）。

## Phase 2: US68 開発用リポジトリを訪れた人を公開用リポジトリへ案内する (P1)

**Goal**: 開発用リポジトリの README に注記を置き、書き出しで除く。

**Independent Test**: `test_strip_readme_dev_note` で、注記を除いた結果が注記を置く前の README と一致し、崩れた印で失敗することを確かめる。
CI の `test_publish_folzio` で、書き出しの README に注記がなく、崩れた印で同期の前に止まることを確かめる。

- [x] T003 [P] [US68] `scripts/dev/tests/test_strip_readme_dev_note.py` を新しく作る。契約（`contracts/readme-dev-note.md`）の各項目を確かめる:
  範囲と直後の空行の除去、注記を置く前の内容との一致、直後が空行でない場合、印がないファイルを変えないこと、
  開始だけ・終了だけ・逆順・入れ子・2 つの範囲・行の一部の印での終了コード 1 とファイルを変えないこと、ファイルがない場合、
  複数ファイルの指定。先に失敗することを確かめる。
- [x] T004 [US68] `scripts/dev/strip-readme-dev-note.sh` を新しく作る（bash 3.2 と BSD・GNU の awk で動く書き方、コメントは英語）。
  T003 のテストを通す。実行権限を付ける。
- [x] T005 [US68] `scripts/dev/tests/test_publish_folzio.py` に回帰テストを足す（FR-316）: `PublishFixture` で、注記を含む `README.md` と
  `README.ja.md` を書き出すと公開先の README が注記を置く前と同じになること、崩れた印で非ゼロ終了し公開先が変わらないこと。
  `PublishFixture` と `exercise_publish` が `scripts/dev/strip-readme-dev-note.sh` を一時リポジトリへ写すようにする。
- [x] T006 [US68] `scripts/dev/publish.sh` で、`git archive` の展開の直後（混入の検査の前）に、一時ディレクトリの `README.md` と
  `README.ja.md` に `scripts/dev/strip-readme-dev-note.sh` を適用する。失敗したら同期の前に止まる。冒頭のコメントにも書く。
- [x] T007 [US68] `README.md` と `README.ja.md` の言語の切り替えの行の後に、契約の形で注記を置く。英語版と日本語版で同じ内容にする。
  `scripts/check-readme-sync.sh` が通ることと、T004 のスクリプトで除くと変更前の README と一致することを確かめる。

## Phase 3: US69 PR の最新の head を CI で検証してからマージする (P1)

**Goal**: CI を PR への push のたびに動かし、CI の起動・再実行の許可の規則をなくす。

**Independent Test**: この PR に追加の push をして、CI が自動で動くことを PR の checks で確かめる（保守者が公開した後）。

- [x] T008 [P] [US69] `.github/workflows/macos-swift-ci.yml` の `pull_request` の `types` を `[opened, synchronize, reopened, ready_for_review]` にする。
  `permissions: contents: read`（FR-319）を含め、ほかは変えない（R3）。
- [x] T009 [P] [US69] `.codex/rules/sdd.rules` から `gh workflow run`・`gh run rerun` の規則とコメントを消す。
  `.kilo/kilo.jsonc` から `gh workflow run *`・`gh run rerun *`・`github_actions_run_trigger` の `ask` を消す。
  関係するテスト（`scripts/dev/tests/`）が通ることを確かめる。
- [x] T010 [US69] `AGENTS.md` の「CI の起動・再実行…許可を得る」の行を消す。`scripts/dev/check-agents-md.sh` が通ることを確かめる。
  変更の理由を PR の本文に書くため、このファイルの末尾の「PR に書く理由」に記録する。
- [x] T011 [US69] `docs_private/cloud-agent-workflow.md` を直す: 全体の流れ・3 章（PR を依頼で作る理由を、費用ではなく
  レビューの準備ができた状態で作るためと書く）、4 章（いつ動くか、修正と再確認、許可と権限設定の段落の削除、
  `.claude/settings.json` は保守者が直すことの注記）、5 章の表は変えない。
- [x] T012 [P] [US69] `docs_private/agents/README.md` の TAK-53 の例を、今も有効な例（TAK-70 の依存ツールの導入の `deny`・`ask`）に替える。
- [x] T013 [P] [US69] `.github/pull_request_template.md` の「検証」の CI の記入案内を、push のたびに動く前提に直す
  （「実行の種類（PR の作成時か、`workflow_dispatch` か）」→ 対象のコミットが PR の最新の head であること）。

## Phase 4: US70 公開後にブランチ保護を設定する (P2)

**Goal**: 保守者が手順だけでブランチ保護と fork の承認を設定できる。

**Independent Test**: 手順だけを読んで、保護の項目、必須チェックの名前、fork の承認の設定を答えられる（SC-169）。

- [x] T014 [US70] `docs_private/repository-and-release.md` に節「開発用リポジトリの公開とブランチ保護」を足す（R4）:
  bypass なしの ruleset 1 つの項目、必須チェックの選び方（CI が 1 回動いた後に候補から選ぶ）、fork の承認の設定、
  ジョブの名前を変えるときの手順（EC-218）、workflow に実行の条件を付けない理由（EC-217）、設定後の確かめ方、
  rulesets が使えない場合の classic の代わりの設定、未確認の点。

## Phase 5: 「非公開」の前提の記述を直す（FR-317）

- [x] T015 `docs_private/repository-and-release.md` の非公開の前提を直す: 冒頭、「2つのリポジトリ」の表（remote）、
  「開発用 master へのマージとバックアップ」（PR によるマージの手順に置き換える。FR-321）、「ドキュメントの配置」の `docs_private/` の説明
  （公開用リポジトリへ書き出さない文書）、「公開用リポジトリの方針」（開発の履歴は開発用リポジトリで公開している）、
  「公開の手順」に README の注記を除く手順を足す。
- [x] T016 `AGENTS.md` の「`docs/`・README・ソースのコメントは公開される」の行を、公開用リポジトリへ書き出されることが分かる文言にする。
  行数を増やさない。理由を末尾の「PR に書く理由」に記録する。
- [x] T017 `grep -rnI "非公開\|private リポジトリ\|private repository\|無料枠\|使用時間"` で、現行の文書・規約・設定・スクリプトのコメントに
  残る非公開と費用の前提を洗い出して直す（凍結した記録は除く。EC-219）。`scripts/dev/merge-to-master.sh` の冒頭のコメント
  （private development repository）を含む。結果をこのファイルの末尾に記録する。

## Phase 5b: `master` への統合を PR だけにする（FR-321）

- [x] T023 `scripts/dev/merge-to-master.sh` を削除する。参照を直す: `AGENTS.md` の PR の行（行数を増やさない。理由を末尾に記録）、
  `docs_private/agents/README.md` の「`merge-to-master.sh` で `master` へ入れるとき」の項目、`docs_private/codex-speckit.md` の最後の統合、
  `.codex/rules/sdd.rules` と `.kilo/kilo.jsonc` の禁止の規則。`grep -rn merge-to-master` で、凍結した記録のほかに残らないことを確かめる。

## Phase 6: 仕様の反映と検証

- [x] T018 `git fetch origin master` と `git merge origin/master` で最新を取り込み、`scripts/dev/check-spec-ids.sh` と、
  開いている作業ブランチとの ID の衝突を確かめる（衝突したら `docs_private/spec-id-conflicts.md`）。
- [x] T019 `specs/product/overview.md` に spec.md の「反映先」の項目を反映する。FR-317〜FR-320 は新しい節「開発用リポジトリの公開」に置く。
  `specs/product/contracts/scripts.md` に README の注記の書き出しを足し、`specs/product/README.md` の件数を直す。
  `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を反映の前と後に実行する。
- [x] T020 `quickstart.md` の Cloud の検証を行い、結果をこのファイルの末尾に記録する。
- [x] T021 反映した項目と差分、検証の結果を保守者に示し、承認を得てからコミットする。
  2026-11-06 に保守者が承認した（反映のコミット `4fb34b5` は、コンテナの回収に備えて承認の前に作業ブランチへ push した）。
- [ ] T022 保守者に依頼することを示す: `.claude/settings.json` の 3 項目の削除、ブランチ保護の設定と確認、マージ後の書き出しでの確認、
  起動スモーク（アプリは変えないが規約に従う）。確認されるまで、このタスクは未チェックのままにする。

## Dependencies

- T002（設計の承認）の後に実装を始める。
- US68: T003 → T004 → T005・T006 → T007。T004 は T003 のテストを通すことで完了とする。
- US69: T008・T009・T012・T013 は独立。T010 と T011 は同じ規則を扱うので続けて行う。
- US70 と Phase 5 の T015 は同じファイルなので、T014 → T015 の順にする。T023 は T015 の後（同じファイルの節を扱う）。
- Phase 6 は、ほかのすべての後に行う。仕様の反映は PR の最後の作業にする（`docs_private/cloud-agent-workflow.md` の 7 章）。

## Implementation Strategy

- MVP は US68 と US69（どちらも P1）。公開した直後に README の案内と CI の検証が揃う。
- US70 の手順は、保守者がこの PR の CI が動いた後に使うので、同じ PR に含める。

## PR に書く理由（`AGENTS.md` の変更）

- 削除「CI の起動・再実行（`workflow_dispatch`、rerun）は、毎回…保守者の許可を得る」（T010）: TAK-53 で、2026-11-02 に Actions の
  予算が 0 ドルになり CI が止まった件から足した行。TAK-80 で開発用リポジトリを公開し、macOS を含む標準ランナーの使用が無料になったため、
  費用の制約がなくなった。保守者の決定（2026-11-06）で削除する。Codex・Kilo・Claude の権限設定の確認も外した（Claude は保守者が対応）。
- 変更「PR のマージと `master` への統合（`scripts/dev/merge-to-master.sh`）は保守者が行う」→「PR のマージは保守者が行う
  （`master` への統合は PR だけで行う）」（T023）: 保守者は `master` への統合をすべて PR で行っており、`merge-to-master.sh` は使っていない。
  公開後のブランチ保護（PR と必須チェック）に例外を置かないため、スクリプトを削除する（保守者の決定、2026-11-06）。
- 変更「`docs/`・README・ソースのコメントは公開される」→「公開用リポジトリ（`yoshidax/folzio`）へ書き出される。書き出さない …」
  （T016）: 開発用リポジトリも公開されたので、「公開される」だけでは、どのリポジトリのことか分からなくなった。規則（書き出さないファイルへ
  リンクしない）は、公開用リポジトリでリンクが切れるので維持する。

## 検証記録

T017（2026-11-06）: `grep -rnIi "非公開\|private リポジトリ\|private repo\|private development\|無料枠\|使用時間\|予算\|0\.062"` を、凍結した記録
（`specs/NNN-*`・`specs/TAK-*`、`.specify/bugs/`、`docs_private/retrospective/`、`docs_private/release-notes/`）を除いて実行した。
直したもの: `docs_private/repository-and-release.md`、`docs_private/cloud-agent-workflow.md`、`AGENTS.md`、`.codex/rules/sdd.rules`。
`scripts/dev/merge-to-master.sh` の冒頭のコメントは、スクリプトごと削除した（T023）。残った行と、残す理由:
- `docs_private/folzio-rename.md:17` の「非公開ディレクトリ」: 設定のバックアップの置き場所のことで、リポジトリの公開とは関係がない
- `docs_private/agents/README.md` の `TAK-53: … 予算が 0 になり CI が止まった`: 理由の書き方の例で、過去の出来事として正しい
- `docs_private/repository-and-release.md` の「非公開のつもりだった運用情報」: 公開前の点検の記録
- `specs/product/overview.md` の FR-176・EC-134・A-106: T019 の反映で直す

T018（2026-11-06）: `origin/master`（88ede54）は作業ブランチの祖先で、取り込みは不要だった。`check-spec-ids.sh` は重複なし。
開いている PR はない。マージされていないリモートのブランチでは、`claude/friendly-ride-5inepi`（TAK-63、2026-11-04 が最後）が EC-215 を使う。
このブランチは、すでにマージ済みの FR-311・EC-213・EC-214 とも重複しているため、マージの際に自分で振り直す側になる（憲章の「仕様の管理」）。
TAK-80 の EC-215 は振り直さない。

T020（2026-11-06、Cloud）:
- `scripts/dev/check-all.sh`: 成功（`test_check_*.py` は 73 件）
- `test_strip_readme_dev_note`: 15 件成功。実装の前に 14 件が失敗することを確かめた
- `test_publish_folzio`: 17 件成功。Cloud に `rsync` がないため、scratchpad に置いたテスト用の簡単な代わり
  （`-a --delete --exclude` だけを扱う）で実行した。`publish.sh` を変更前に戻すと、追加した 3 件のうち 2 件
  （注記の除去、崩れた印での停止）が失敗することを確かめた。実際の `rsync` での実行は CI で確かめる
- README の注記を `strip-readme-dev-note.sh` で除いた結果は、英語版・日本語版とも変更前の README とバイト単位で一致した
- `check-spec-format.py`: エラー 0 件、警告 88 件（基準値と同じ）。`check-spec-ids.sh`: 重複なし。`git diff --check`: 問題なし
- workflow の `pull_request` の `types` は `[opened, synchronize, reopened, ready_for_review]`（YAML として読み込んで確かめた）

## PR のレビューへの対応（2026-11-06、PR #62 の `/code-review high` の 7 件）

- test-coverage: `test_strip_readme_dev_note` を CI の「Test publication script」と `scripts/dev/check-all.sh` で実行するようにした
- correctness（`awk -v` のエスケープ）: ファイル名を環境変数で、内容を標準入力で awk に渡すようにした。名前に `=` があるファイルを
  awk が変数の代入と見なす問題も、あわせて直した（テストを追加）
- correctness（末尾の改行）: 印のあるファイルでも、末尾の改行の有無を保つようにした（テストを追加）
- correctness（CRLF）: 印の行の改行が CRLF なら、そのことを示して止めるようにした（テストを追加）
- spec の正確さ: `specs/product/overview.md` の FR-313 の括弧書きを「同期の検査の対象外なので、差分で確かめる」に直した
- simplification: `publish.sh` は 2 つの README を直接渡し、README がなければ同期の前に止まる（テストを追加）
- conventions: `publish.sh` に足したコメントは、ファイルの既存のコメントに合わせて日本語のままにした（保守者の判断を求める）

検証: `test_strip_readme_dev_note` 19 件、`test_publish_folzio` 18 件（Cloud では `rsync` の代わりを使用）、`check-all.sh`、
`check-spec-format.py`（エラー 0 件、警告 88 件）が成功した。追加した 4 件のテストは、修正の前に失敗することを確かめた
（`=` の名前のテストは、修正と同時に足したので、修正前の失敗は確かめていない）。

