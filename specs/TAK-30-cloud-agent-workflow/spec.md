# Feature Specification: Cloud Agent 向けの開発 workflow

> **移行済み（2026-10-31）**: 現在の仕様は [specs/product/](../product/README.md) を正とする。
> このファイルは TAK-30 時点の記録として凍結しており、更新しない。

**Feature Branch**: `claude/tak-30-cloud-agent-workflow`（Cloud が指定する作業ブランチ。feature ディレクトリ名とは独立）
**Created**: 2026-10-30
**Status**: Draft
**Input**: [TAK-30](https://linear.app/takyoshida/issue/TAK-30/cloud-agent-向けの開発-workflow-を整備するpr-駆動linearci-連携)（前提: TAK-25、TAK-27、TAK-28）

## 既存の仕様との関係

この feature は、保守者向けの開発 workflow を扱う。アプリの動作（閲覧・整理・検索など）は変えない。
既存の **FR-168、FR-169、FR-177〜FR-180（overview.md）** と公開用アプリ生成の契約（contracts/app-bundle.md、contracts/scripts.md）を維持する。
ローカルでの開発（クリーンな master から feature ブランチを切り、ローカルでビルド・検証し、保守者が `scripts/dev/merge-to-master.sh` で統合する運用）は、そのまま使える。

## Clarifications

### Session 2026-10-30

- Q: master へのマージ方式は？ → A: GitHub 上の PR マージに統一する。マージは保守者だけが行い、Agent は行わない。ローカル運用の `merge-to-master.sh` などは残し、ローカルと Cloud の両方で開発できるようにする。
- Q: Cloud Agent の並列の単位は？ → A: feature（Linear Issue）単位。サブエージェントによるタスク分割の並列実装は、Cloud 用の運用では行わない。
- Q: Cloud の feature の番号は？ → A: Linear の Issue 番号（`TAK-nn`）。ディレクトリは `specs/TAK-nn-<slug>` とし、既存の連番（001〜018）とは別に扱う。
- Q: `specs/product/` への反映の時期は？ → A: 各 feature の PR に含める。同じ領域のファイルで競合した場合は、Agent が master を取り込んで解消する。
- Q: Linear の状態は誰が更新するか？ → A: Agent が自分で更新する（着手時の `In Progress` など）。`Done` は、保守者がマージ後に依頼したときだけ更新する。
- Q: ビルドとテストの確認は？ → A: Cloud 環境には Swift がないため、macOS の CI（TAK-25）で確認する。CI は PR の作成時と Ready にしたときに自動で動き、以後の再確認は手動実行で行う。
- Q: master を守る仕組みは？ → A: 無料プランの private リポジトリのため branch protection は使えない。Agent の権限設定（TAK-27）で、master への push、強制 push、PR のマージを止める。
- Q: Agent が PR を作るタイミングは？ → A: 保守者が依頼したときだけ作る。CI が PR の作成時に 1 回だけ自動で動く設計のため、作業の途中で PR を作ると、空に近い状態で CI が動くことを避ける。
- Q: PR を作ったときの Linear の `In Review` への更新とリンクは誰が行うか？ → A: Agent が行う。Linear の GitHub 連携は PR の作成を検知しなかった（TAK-28 の PR #3 は、タイトルに Issue 番号を含んでいたのに、`In Review` にならずリンクも付かなかった）ため、連携には頼らない。当初は「連携に任せる」と決めたが、その前提（TAK-25 が連携で `In Review` になった）が誤りだったため、取り直した。
- Q: マージ済みの作業ブランチは再利用できるか？ → A: 再利用しない。スカッシュマージで履歴が変わるため、同じ名前で作り直すには強制 push が要り、禁止されている。最新の master から新しい作業ブランチを作る。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Issue の指定から Cloud Agent が feature を始める (Priority: P1)

保守者が Linear の Issue を指定して Cloud Agent に作業を頼むと、Agent は Issue の内容を読み、Issue の番号を含む feature ディレクトリを作って仕様を書き始める。

**Why this priority**: Cloud Agent による開発の入口。ここが成立しないと、以後の流れが始まらない。

**Independent Test**: Cloud のセッションで Issue を指定し、feature ディレクトリ、Issue の URL の記録、Linear の状態の更新、作業ブランチへの push までを確認する。

**Acceptance Scenarios**:

1. **US27-AS1**: **Given** Cloud の作業ブランチにいて Issue（`TAK-nn`）を指定された、**When** Agent が feature を始める、**Then** `specs/TAK-nn-<slug>/` ができ、Agent はブランチを新しく作らず、feature の状態ファイルがこのディレクトリを指す。
2. **US27-AS2**: **Given** 着手する Issue が `Backlog` などの状態にある、**When** Agent が着手する、**Then** Agent は Issue を `In Progress` に更新し、Issue の URL または ID を feature の仕様書に記録して、作業ブランチとともに保守者へ知らせる。
3. **US27-AS3**: **Given** Linear に接続できない、**When** Agent が Issue を読む、または状態を更新しようとする、**Then** Agent は失敗を報告し、更新できたとは扱わない。

4. **US27-AS4**: **Given** 保守者の依頼で Agent が PR を作った、**When** PR の作成が終わる、**Then** Agent は対象の Issue に PR のリンクを追加して `In Review` に更新し、結果を保守者へ知らせる。Linear に接続できなければ、失敗を報告する。

---

### User Story 2 - CI の結果を読んで Cloud で修正を進める (Priority: P1)

Cloud 環境には Swift がないため、Agent は PR の CI の結果を読み、失敗の原因を判断して修正する。

**Why this priority**: Cloud ではビルドとテストを直接実行できず、CI が唯一の検証手段になる。

**Independent Test**: 意図的にビルドを失敗させた PR で、Agent が CI のログから原因を特定し、修正を push し、手動実行で再確認できることを確認する。

**Acceptance Scenarios**:

1. **US28-AS1**: **Given** PR を作成した、**When** CI が完了する、**Then** Agent は成否を確認し、失敗ならログを読んで原因を判断する。
2. **US28-AS2**: **Given** 追加のコミットを push した、**When** CI が自動では動かない、**Then** Agent は手動実行で再確認するか、保守者に実行を頼む。
3. **US28-AS3**: **Given** 同じ原因の失敗を 3 回直しても解決しない、**When** Agent が次の修正を考える、**Then** Agent は作業を止め、状況を保守者へ報告する。
4. **US28-AS4**: **Given** CI のテストが止まっている、**When** ステップのタイムアウトに達する、**Then** ジョブは終了し、Agent はログから止まった箇所を読める。

---

### User Story 3 - 保守者だけがマージと完了を決める (Priority: P2)

保守者は PR を確認し、ローカルで動作を確認してからマージする。Agent はマージも Linear の完了更新も、保守者の依頼なしには行わない。

**Why this priority**: 無料プランでは branch protection が使えないため、人が最後の関門になる。

**Independent Test**: Agent に PR のマージを頼まない状態で作業を終えさせ、Agent がマージも `Done` への更新も行わないことを確認する。

**Acceptance Scenarios**:

1. **US29-AS1**: **Given** CI が成功した PR がある、**When** Agent が作業を終える、**Then** Agent は PR のマージを行わず、保守者にローカルでの確認（起動スモークなど）が必要なことを知らせる。
2. **US29-AS2**: **Given** 保守者が PR をマージした、**When** 保守者が完了更新を依頼する、**Then** Agent はマージを確認してから Issue を `Done` に更新する。確認できなければ完了にせず、状況を報告する。
3. **US29-AS3**: **Given** Agent が master への push、強制 push、PR のマージを行おうとする、**When** 権限設定を適用する、**Then** 実行が拒否される。

---

### User Story 4 - ローカル運用と共存する (Priority: P2)

保守者は、従来どおりローカルで feature ブランチを切って実装し、ローカルでマージしても、Cloud 用の規則に邪魔されない。

**Why this priority**: 個人開発では、ローカルと Cloud を状況に応じて使い分ける。

**Independent Test**: ローカルのセッションで、従来の手順（feature ブランチ、ローカルの検証ゲート、`merge-to-master.sh`）を実行し、結果が変わらないことを確認する。

**Acceptance Scenarios**:

1. **US30-AS1**: **Given** ローカルで開発する、**When** 従来の手順に従う、**Then** Cloud 用の規則によって手順が変わらない。
2. **US30-AS2**: **Given** `AGENTS.md` を読む、**When** ある規則が適用される運用を知りたい、**Then** 共通・ローカル専用・Cloud 専用のどれかが分かる。
3. **US30-AS3**: **Given** 同じ状況（例: `git push`）に対して、ローカル専用と Cloud 専用の規則がある、**When** それぞれを読む、**Then** 互いに矛盾する指示が出ない。

---

### User Story 5 - 複数の Cloud セッションが並行して作業する (Priority: P3)

別の Issue を担当する複数の Cloud セッションが並行して作業しても、ファイルの競合が最小で済む。

**Why this priority**: 並列実装が Cloud 化の目的の 1 つだが、まず 1 セッションで流れが成立することが先。

**Independent Test**: 2 つの Issue を別々のセッションで同時に進め、feature ディレクトリや状態ファイルが衝突しないことを確認する。

**Acceptance Scenarios**:

1. **US31-AS1**: **Given** 2 つのセッションが別の Issue を担当する、**When** それぞれが feature を始める、**Then** feature ディレクトリの名前は衝突しない。
2. **US31-AS2**: **Given** 2 つの PR が `specs/product/` の同じ領域ファイルを変更した、**When** 先の PR がマージされる、**Then** 後の PR の Agent は master を取り込んで競合を解消できる。

### Edge Cases

- **EC-129**: `specs/TAK-nn-*` が既にある Issue で再度 feature を始めようとした場合、既存のディレクトリを上書きせず、保守者に確認する。
- **EC-130**: master が作業の途中で先に進んだ場合、Agent は master を取り込んでから PR を更新する。履歴を書き換えない。
- **EC-131**: PR がスカッシュマージされて、作業ブランチの履歴が master と一致しなくなった場合、Agent は同じ名前のブランチを強制 push で作り直さず、最新の master から新しい作業ブランチを作る。
- **EC-132**: CI のログが実行中で取得できない場合、Agent は推測で修正せず、完了またはタイムアウトを待つ。
- **EC-133**: 権限設定をセッションの途中で変更しても、実行中のセッションには反映されない。反映するには新しいセッションが要る。
- **EC-134**: macOS の CI の使用時間が不足している場合、Agent は CI を無駄に繰り返さず、保守者へ知らせる。
- **EC-135**: 並行する別の feature が同じ番号の ID（`FR`・`SC`・`EC`・`A`・`US`）を使っていた場合（反映の直前に `master` を取り込んだときに分かる）、まだマージされていない側が、自分の feature の ID を振り直してから `specs/product/` に反映する。マージ済みの ID は振り直さない。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-186**: Cloud Agent は、Linear Issue の指定から、`specs/TAK-nn-<slug>/` の feature ディレクトリで仕様を始められなければならない。ブランチ名と feature ディレクトリ名は独立とする。Cloud が指定した作業ブランチがあるときは、Agent はそのブランチ上で作業し、feature 用のブランチを新しく作らない。
- **FR-187**: feature の状態ファイル（`.specify/feature.json`）は、バージョン管理の対象外のままでなければならない。並行する PR の間で競合させない。現在は `.specify/.gitignore` で除外されている（A-114）。
- **FR-188**: Agent は feature またはバグ修正に着手するとき、対象の Issue を確認して `In Progress` に更新し、Issue の URL または ID を feature の仕様書またはバグの assessment に記録して、作業ブランチとともに保守者へ知らせなければならない。Linear に接続できない場合は失敗を報告し、更新できたと扱ってはならない。
- **FR-189**: Agent は作業ブランチ（許可された接頭辞を持つもの）への push だけを行い、`master` / `main` への push、強制 push、リモートブランチの削除、PR のマージを行ってはならない。マージ済みのブランチは再利用せず、最新の master から新しい作業ブランチを作らなければならない。Cloud が指定したブランチと別の名前を使うときは、保守者の許可を得る。
- **FR-190**: Cloud ではビルドとテストを CI で確認しなければならない。CI は PR の作成時と Ready にしたときに自動で動き、以後の再確認は手動実行で行う。Agent は CI の失敗をログから判断し、同じ原因の失敗を 3 回直しても解決しない場合は作業を止めて報告しなければならない。
- **FR-191**: CI のテストの各ステップには、ジョブ全体より短いタイムアウトを設定し、止まったテストがランナーを占有し続けず、ログから止まった箇所を読めなければならない。
- **FR-192**: 検証ゲートは、Cloud で実行できる検査（ネットワーク API の検査、コメントの英語、README の同期）、CI で実行する検査（`swift build`、`swift test`）、保守者が行う検査（起動スモーク）を区別して定めなければならない。起動スモークを省略して完了としてはならない。
- **FR-193**: `specs/product/` への反映は、その feature の PR に含めなければならない。同じ領域ファイルの競合は、Agent が master を取り込んで解消する。履歴を書き換えてはならない。ID（`FR`・`SC`・`EC`・`A`・`US`）は、反映の直前に取り込んだ master と突き合わせて衝突を確かめ、衝突していれば EC-135 に従う。
- **FR-194**: ローカル運用（ローカルでの feature ブランチ、ローカルの検証ゲート、`scripts/dev/merge-to-master.sh`、worktree による並列実装）は維持しなければならない。Cloud 用の規則はこれらと区別して定め、互いに矛盾してはならない。
- **FR-195**: `AGENTS.md` は、共通の規則、ローカル専用の規則、Cloud 専用の規則を区別して示さなければならない。各規則が、どの運用に適用されるか読み取れること。
- **FR-196**: Cloud Agent の作業の手順（feature の始め方、Linear の更新、PR の作成、CI の確認、完了の報告）は、Agent が `AGENTS.md` と手順書だけで進められる形でまとめなければならない（SC-090 で確認する）。
- **FR-197**: Agent は、Linear の `Done`、`Canceled`、`Duplicate` の Issue を、保守者の明示的な指示なしに再着手してはならない。`Done` への更新は、保守者がマージ後に依頼したときだけ、マージを確認した上で行う。
- **FR-198**: Agent は、保守者が依頼したときだけ PR を作らなければならない。作業が終わっても、依頼なしには PR を作らず、作成できる状態であることを報告する。
- **FR-199**: Agent は PR を作ったら、対象の Issue に PR のリンクを追加し、`In Review` に更新しなければならない。Linear に接続できない場合は失敗を報告し、更新できたと扱ってはならない。

### Key Entities *(include if feature involves data)*

- **Linear Issue**: 作業の単位。番号（`TAK-nn`）が feature ディレクトリ名の接頭辞になり、状態は Agent が更新する。
- **feature ディレクトリ**: `specs/TAK-nn-<slug>/`。仕様、計画、タスク、検証の記録を持つ。ブランチ名とは独立。
- **作業ブランチ**: Cloud が指定する、またはこの運用で作る、許可された接頭辞を持つブランチ。マージ後は再利用しない。
- **PR**: 作業の統合の単位。CI の結果と保守者の確認を経て、保守者がマージする。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-090**: 新しい Cloud セッションが、Issue の指定から、仕様の作成、実装、保守者の依頼による PR の作成、CI の結果の確認まで、保守者の依頼とマージ・確認以外の操作なしに進められる。
- **SC-091**: 別の Issue を担当する 2 つ以上の Cloud セッションが並行して作業しても、feature ディレクトリ名と状態ファイルの競合が 0 件であり、両方がマージされた後の `specs/product/` に重複した ID が 0 件である。
- **SC-092**: Cloud の規則に従った作業で、`master` への直接 push、強制 push、Agent による PR のマージが 0 件である。
- **SC-093**: ローカルの従来の手順（feature ブランチ、検証ゲート、`merge-to-master.sh`）が、この feature の前と同じ結果で動く。
- **SC-094**: `AGENTS.md` の共通・ローカル専用・Cloud 専用の規則を読み比べたとき、同じ状況に対して異なる指示を出す規則が 0 件である。
- **SC-095**: CI のテストが止まった場合、ジョブはステップのタイムアウト（ジョブ全体の上限より短い）で終了し、止まった箇所をログから特定できる。

## Assumptions

- **A-105**: Cloud 環境には Swift ツールチェーンがなく、`swift build` と `swift test` は CI（TAK-25）でしか確認できない。
- **A-106**: macOS の CI の使用時間（GitHub Free の private リポジトリ）には上限がある。修正はログを読んでまとめてから push し、無駄な再実行を避ける。
- **A-107**: Agent は Linear の MCP と GitHub の MCP を使える。GitHub の一部の書き込み系ツール（`master` への書き込み、PR のマージなど）は権限設定で禁止されている（TAK-27）。
- **A-108**: master へのマージはスカッシュマージで行われる（PR #3 で確認）。
- **A-109**: Agent の権限設定は、セッションの起動時に読み込まれる。
- **A-110**: ローカルの `master` ブランチは古いことがある。作業の前に `git fetch` して、最新の master から始める。
- **A-111**: この feature は `AGENTS.md`、手順書、リポジトリの設定を変更する。アプリのコード（`Sources/`）は変更しない。
- **A-112**: Claude と Codex の両方の Cloud Agent が `AGENTS.md` を読む。各 Agent に固有のスキルの差（`.claude/skills/` と `.agents/skills/`）は、この feature の対象外とする。
- **A-113**: 憲章の「マージ前のゲート」（自動テストの通過）は、Cloud では CI の成功と、保守者のローカルでの確認で満たされると解釈する。憲章の文言は、この feature では改定しない。
- **A-114**: `.specify/feature.json` は `.specify/.gitignore` で既に管理対象外である。この feature では追加の除外設定を要しない。
- **A-115**: Linear の GitHub 連携は、PR の作成を検知して Issue にリンクを付けたり状態を変えたりしない（TAK-28 の PR #3 で確認した）。Agent が、PR を作った後に、Issue へ PR のリンクを追加して `In Review` に更新する。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| US27-AS1〜AS4、US28-AS1〜AS4、US29-AS1〜AS3、US30-AS1〜AS3、US31-AS1、AS2 | 追加 | overview.md |
| EC-129〜EC-135 | 追加 | overview.md |
| FR-186〜FR-199 | 追加 | overview.md |
| SC-090〜SC-095 | 追加 | overview.md |
| A-105〜A-115 | 追加 | overview.md |

契約 `contracts/scripts.md` への反映は行わない（スクリプトを変更しないため。plan.md で決定）。
