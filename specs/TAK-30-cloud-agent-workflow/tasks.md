# Tasks: Cloud Agent 向けの開発 workflow

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、[quickstart.md](quickstart.md)

変更は `AGENTS.md` と `docs_private/cloud-agent-workflow.md` の同じファイルに集まるため、並列実装（`[P]`）は行わず、順次実施する。アプリのコード、`.claude/settings.json`、`.github/workflows/` は変更しない（`.github/workflows/` は T012 で読むだけ）。

## Phase 1: 準備

- [ ] T001 `grep -n '^## ' AGENTS.md` の出力が、`data-model.md` の分類表の 14 節と一致することを確認する。差があれば `data-model.md` を直す。
- [ ] T002 `git fetch origin master` の後、`origin/master` が作業ブランチの祖先であることを確認する。先に進んでいたら `git merge origin/master` で取り込む（履歴は書き換えない）。

## Phase 2: 基盤（`AGENTS.md` の区分づけ。すべての User Story の前に行う）

- [ ] T003 `AGENTS.md` の「プロジェクト概要」の直後に「運用の区分」の節を追加する。凡例【共通】【ローカル】【Cloud】と、変更後の全節の一覧表（`data-model.md` の分類表に従う）を載せる。（FR-195）
- [ ] T004 `AGENTS.md` の各節の見出しに区分を付ける。【共通】: プロジェクト概要、Issue 管理、コードコメント（英語）、バグ修正、AppKit UI の不変条件、テスト、検証用コマンド、公開用リポジトリ、README の英語版と日本語版、参照。【ローカル】: Phase の検証ゲート、起動しないときの初動（AppKit / macOS）、並列実装（worktree 標準）。「Codex / Spec Kit」は T016 で分ける。（FR-195）
- [ ] T005 `AGENTS.md` に、小見出しだけの「Cloud Agent の作業【Cloud】」の節を追加する。`docs_private/cloud-agent-workflow.md` を新規に作り、章立て（見出しのみ）を置く: 1 feature の始め方、2 Linear、3 PR とマージ、4 CI の確認、5 検証ゲート（Cloud 版）、6 ブランチ、7 並行する作業と競合。

## Phase 3: User Story 1 - Issue の指定から Cloud Agent が feature を始める (P1)

**Independent Test**: 手順書の 1・2 章と `AGENTS.md` の Cloud の節だけを読んだ Agent が、Issue の指定から、feature ディレクトリの作成、Issue の `In Progress` への更新、URL の記録、PR 作成後の `In Review` とリンクの追加まで、迷わず進められる（US27-AS1〜AS4）。

- [ ] T006 [US1] `docs_private/cloud-agent-workflow.md` の「1 feature の始め方」を書く。Cloud が指定した作業ブランチ上で作業し、`speckit.git.feature`（`before_specify` フック）を実行しないこと。`SPECIFY_FEATURE_DIRECTORY=specs/TAK-nn-<slug>` を明示して `speckit-specify` を実行すること。`.specify/feature.json` は `.specify/.gitignore` で除外済みであること。`specs/TAK-nn-*` が既にあるときは上書きせず保守者に確認すること。（FR-186、FR-187、EC-129、R3、A-114）
- [ ] T007 [US1] `docs_private/cloud-agent-workflow.md` の「2 Linear」を書く。着手時に Linear の MCP（`save_issue`）で `In Progress` に更新し、Issue の URL または ID を feature の仕様書またはバグの assessment に記録して、作業ブランチとともに保守者へ知らせること。PR を作った後に、`save_issue` の `links` で PR のリンクを追加して `In Review` に更新すること。Linear に接続できないときは失敗を報告し、更新できたと扱わないこと。`Done`、`Canceled`、`Duplicate` の Issue は保守者の明示的な指示なしに再着手しないこと。（FR-188、FR-197、FR-199、R5、A-115）
- [ ] T008 [US1] `AGENTS.md` の「Cloud Agent の作業【Cloud】」に、feature の始め方と Linear の更新の要点（各 2〜4 行）を書き、手順書の該当章へのリンクを置く。

## Phase 4: User Story 2 - CI の結果を読んで Cloud で修正を進める (P1)

**Independent Test**: 手順書の 4・5 章を読んだ Agent が、PR の CI の成否を確認し、失敗なら原因をログから判断し、修正をまとめて push し、手動実行で再確認するか保守者へ頼む流れを説明できる（US28-AS1〜AS4）。

- [ ] T009 [US2] `docs_private/cloud-agent-workflow.md` の「4 CI の確認」を書く。CI は PR の作成時と Ready にしたときに自動で動き、以後の push では動かないこと。成否は GitHub MCP の `pull_request_read`（`get_check_runs`）で確認し、失敗は `get_job_logs` でログを読むこと。実行中のログは取得できないので完了またはタイムアウトを待つこと（EC-132）。修正はログを読んでまとめてから push し、macOS の使用時間を無駄にしないこと（EC-134）。同じ原因の失敗を 3 回直しても解決しない場合は作業を止めて報告すること。再確認は `workflow_dispatch` の手動実行で行うこと（起動の可否は T025 で確認して書き足す）。（FR-190、US28-AS1〜AS3、R4）
- [ ] T010 [US2] `docs_private/cloud-agent-workflow.md` の「5 検証ゲート（Cloud 版）」を書く。Cloud で実行する検査（`check-no-network.sh`、`check-english-comments.sh`、`check-readme-sync.sh master`、`test_check_git_push.py`）、CI で実行する検査（`swift build`、`swift test`、性能テスト）、保守者が行う検査（起動スモーク、ローカルの Swift 最新版でのビルド、公開・配布の Python テスト）の 3 区分の表。起動スモークを省略して完了としないこと。憲章の「マージ前のゲート」は、CI の成功と保守者のローカルでの確認で満たすと解釈すること。（FR-192、R7、R8、A-113）
- [ ] T011 [US2] `.github/workflows/macos-swift-ci.yml` を読み取り専用で確認し、テストの各ステップに、ジョブ全体（30 分）より短い `timeout-minutes`（10 分）があり、止まったテストをログから特定できることを確認する。事実を手順書の「4 CI の確認」に 1〜2 行で書く。（FR-191、SC-095、US28-AS4）
- [ ] T012 [US2] `AGENTS.md` の「Cloud Agent の作業【Cloud】」に、CI の確認と検証ゲート（Cloud 版）の要点を書き、手順書へのリンクを置く。

## Phase 5: User Story 3 - 保守者だけがマージと完了を決める (P2)

**Independent Test**: 手順書の 3・6 章を読んだ Agent が、PR を依頼なしに作らないこと、マージしないこと、`Done` を依頼なしに付けないこと、マージ済みのブランチを再利用しないことを説明できる（US29-AS1〜AS3、EC-131）。

- [ ] T013 [US3] `docs_private/cloud-agent-workflow.md` の「3 PR とマージ」を書く。保守者が依頼したときだけ PR を作り、作業が終わっても依頼なしには作らず、作成できる状態であることを報告すること。PR のタイトルと本文に Issue 番号（`TAK-nn`）を入れること。マージは保守者だけが行うこと。保守者にローカルでの確認（起動スモークなど）が必要なことを知らせること。マージ後に保守者が完了更新を依頼したら、マージを確認してから `Done` に更新し、確認できなければ完了にしないこと。（FR-198、FR-197、US29-AS1〜AS2）
- [ ] T014 [US3] `docs_private/cloud-agent-workflow.md` の「6 ブランチ」を書く。作業ブランチ（許可された接頭辞）にだけ push し、`master` / `main` への push、強制 push、リモートブランチの削除を行わないこと。マージ済みのブランチは再利用せず、最新の `master` から新しい `claude/` のブランチを作ること（Cloud が指定した名前と別のときは保守者の許可を得る）。作業の途中で `master` が先に進んだら、取り込んで（`git merge origin/master`）から PR を更新すること。権限の設定はセッションの起動時に読み込まれるため、途中で設定を変えても実行中のセッションに反映されず、新しいセッションが要ること。（FR-189、EC-130、EC-131、EC-133、R9、A-108、A-109）
- [ ] T015 [US3] `AGENTS.md` の「Cloud Agent の作業【Cloud】」に、PR・マージ・ブランチの要点を書き、手順書へのリンクを置く。

## Phase 6: User Story 4 - ローカル運用と共存する (P2)

**Independent Test**: `AGENTS.md` の全規則が 3 区分のどれかに属し、同じ状況に異なる指示を出す規則がなく、ローカル専用の規則の意味が変更前と同じである（US30-AS1〜AS3）。

- [ ] T016 [US4] `AGENTS.md` の「Codex / Spec Kit」の節を、`data-model.md` の行の単位の分類に従って分ける。「Codex / Spec Kit」【共通】（スキルの場所、標準・git・bug スキル、`.codex/` の設定）、新しい「Git の規則」【共通】（`git push`、`reset --hard`・`clean`・sandbox の無効化、`merge-to-master.sh`、GUI の起動の依頼）、「Codex の自動実行」【ローカル】（`sdd-run-codex.sh`、順次実装）。規則の文言は変えず、置き場所だけを動かす。（FR-194、FR-195）
- [ ] T017 [US4] `AGENTS.md` の「バグ修正」の手順 1（`bugfix/<slug>` ブランチ）と手順 5（検証ゲート）に、「ローカル: …／Cloud: 作業ブランチをそのまま使う、ビルドとテストは CI」の注記を足す。「テスト」と「検証用コマンド」に、Cloud では `swift` を使うコマンドを実行できず CI で確認する旨を、「起動しないときの初動」に Cloud では保守者に依頼する旨を、それぞれ 1 文足す。（FR-194、data-model.md の「変更後の扱い」）
- [ ] T018 [US4] `docs_private/folzio-sdd-increment.md` の冒頭に、この手順がローカル専用であること（事前確認がクリーンな `master` を前提とする）と、Cloud では `docs_private/cloud-agent-workflow.md` に従うことを 1〜2 文で書く。
- [ ] T019 [US4] `AGENTS.md` の「参照」に、`docs_private/cloud-agent-workflow.md` を追加する。
- [ ] T020 [US4] `quickstart.md` の A に従って、分類表と変更後の `AGENTS.md` の突き合わせ（A2）、`git push`・検証ゲート・ブランチ・完了の報告の読み比べ（A3）、ローカル専用の規則の差分確認（A4）を行い、結果を `quickstart.md` の末尾に記録する。矛盾が見つかったら `AGENTS.md` を直す。（SC-093、SC-094）

## Phase 7: User Story 5 - 複数の Cloud セッションが並行して作業する (P3)

**Independent Test**: 手順書の 7 章を読んだ Agent が、別の Issue の作業と衝突しない feature ディレクトリの付け方と、`specs/product/` の競合の解消の手順を説明できる（US31-AS1〜AS2）。

- [ ] T021 [US5] `docs_private/cloud-agent-workflow.md` の「7 並行する作業と競合」を書く。並列の単位は Issue（サブエージェントによるタスク分割の並列実装は行わない）。feature ディレクトリは Issue 番号を含むので衝突しない。`specs/product/` への反映は PR の最後の作業とし、直前に `git merge origin/master` で取り込み、同じ領域ファイルの競合は Agent が解消すること。履歴を書き換えないこと（強制 push は禁止）。（FR-193、US31-AS1〜AS2、R6）
- [ ] T022 [US5] `AGENTS.md` の「Cloud Agent の作業【Cloud】」に、並行する作業と `specs/product/` の反映の要点を書き、手順書へのリンクを置く。

## Phase 8: 確認

- [ ] T023 手順書と `AGENTS.md` を通読し、`spec.md` の `FR-186`〜`FR-199` と `EC-129`〜`EC-134` のすべてに、対応する記述があることを確認する。抜けがあれば追記する。結果を `quickstart.md` の末尾に記録する。（FR-196）
- [ ] T024 quickstart.md の B のコマンド（`scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py" -v`）を実行し、通過を確認する。
- [ ] T025 [MANUAL] 保守者が「PR を作って」と依頼する。Agent が PR を作る（FR-198）。作成後、PR の CI の自動実行と成否を `get_check_runs` で確認し、追加の push の後に `actions_run_trigger` で `workflow_dispatch` を起動できるか確かめて、結果（起動できた／できなかった）を手順書の「4 CI の確認」に反映する。（quickstart.md の C2、C3、US28-AS1、AS2）
- [ ] T026 PR の作成後、Agent が TAK-30 に PR のリンクを追加して `In Review` に更新し、Linear 上で状態の履歴とリンクを確認する。`master` への push、強制 push、PR のマージが拒否されることを、`git push --dry-run` などの無害な操作で確認する。結果を `quickstart.md` の末尾に記録する。（quickstart.md の C1、C4、US27-AS4、US29-AS3）
- [ ] T027 [MANUAL] 保守者がローカルで、最新の `master` に PR のブランチを取り込み、`swift build`、`swift test`、`python3 -I -m unittest discover -s scripts/dev/tests -v`、`scripts/make-app.sh`、`open .build/Folzio.app`（3 ペインの表示）を実行し、結果を報告する。この feature はアプリのコードを変えないため、結果は変更前と同じになる。（quickstart.md の D）

## Phase 9: `specs/product/` への反映

- [ ] T028 `git merge origin/master` で最新の `master` を取り込み、`spec.md` の「反映先」の表に従って `specs/product/overview.md` に反映する（US27〜US31 の受け入れシナリオ、`EC-129`〜`EC-134`、`FR-186`〜`FR-199`、`SC-090`〜`SC-095`、`A-105`〜`A-115`）。`spec.md` の冒頭に移行済み・凍結の注記を入れる。ID の付け方は `specs/product/README.md` に従う。コミットしない。反映した項目と差分を保守者へ示す。
- [ ] T029 [MANUAL] 保守者が反映の差分を確認して承認する。承認後に反映をコミットして push する。
- [ ] T030 [MANUAL] 保守者が PR をマージし、完了更新を依頼する。Agent がマージを確認して TAK-30 を `Done` にする。確認できなければ完了にしない。（FR-197、quickstart.md の E）

## Dependencies & Execution Order

T001 → T002 → T003 → T004 → T005 → T006 → … → T024 を順番に行う。T003〜T005（基盤）は、すべての User Story の前に終える。User Story 1〜3 の手順書の章は同じファイルを書くため並列にしない。T016（`AGENTS.md` の分割）は T004 の後であればいつでもよいが、Cloud の節の追記（T008、T012、T015、T022）と同じファイルを編集するため、順番に行う。

T025 は保守者の依頼を待つ独立した確認で、依頼があるまで未チェックとする。T026 は T025（PR の作成）の後。T028 は T025〜T027 の確認が済んだ後に行う（検証が終わってから `specs/product/` に反映する、という規則による）。T029、T030 は保守者の操作で、報告まで未チェックとする。

## Implementation Strategy

MVP は User Story 1 と 2（手順書の 1〜2 章と 4〜5 章、`AGENTS.md` の Cloud の節）。Cloud Agent が feature を始めて CI で確認するところまでが成立すれば、運用を始められる。続けて User Story 3（マージと完了の境界）、User Story 4（ローカルとの共存）、User Story 5（並行）を足す。

この feature はアプリのコードを変えないため、ビルドとテストの結果は変更前と同じになる。Cloud の実機確認（T025、T026）は、この feature 自身の PR で行う。確認の結果は手順書と `quickstart.md` に記録し、起動できなかった手段があれば、保守者に頼む手順として手順書に書く。
