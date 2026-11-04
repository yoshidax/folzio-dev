# Feature Specification: エージェント向けの規約の置き場所を AGENTS.md に限らない

> **移行済み（2026-11-04）**: 現在の仕様は [specs/product/](../product/README.md) を正とする。
> このファイルは TAK-72 時点の記録として凍結しており、更新しない。

**Feature Branch**: `claude/tak-72-agents-md-spec`（Cloud が指定した作業ブランチ。feature ディレクトリ名とは独立）

**Created**: 2026-11-04

**Status**: Draft

**Input**: [TAK-72](https://linear.app/takyoshida/issue/TAK-72)
「製品仕様が AGENTS.md の中に置く内容を指定している要件を、参照先の文書でも満たせるように改める」
（関連: TAK-66 / PR #49、TAK-71 / PR #50、TAK-73）

## 既存の仕様との関係

この feature は、保守者とエージェントの開発の運用（エージェント向けの規約の置き場所）を扱う。アプリの動作は変えない。

- `AGENTS.md` はエージェントが毎回読むので、短いほどよい（TAK-66 で 313 行から 50 行に絞った）
- 次の要件は、内容を `AGENTS.md` の中に置くことを求めている。このため、TAK-66 では次の内容を本文に残す必要があった
  - FR-195・US30-AS2・SC-094（overview.md）: 共通・ローカル専用・Cloud 専用の規則の区別
  - FR-306・US66-AS2・SC-161（overview.md）: 製品仕様の書き方のルールの要点
- 運用に関わる feature が `AGENTS.md` の中身を要件にすると、feature を足すたびに `AGENTS.md` が増える（TAK-30 では +91 行）
- FR-196（overview.md）の「`AGENTS.md` と手順書だけで進められる」は、参照先の文書を認めているので変えない
- A-91（overview.md）と `contracts/localization.md` の「Phase の検証ゲート（AGENTS.md）」は、節の名前の参照なので変えない
- TAK-71 で、`AGENTS.md` の行数と参照先のパスの検査（`scripts/dev/check-agents-md.sh`）と、置き場所の基準
  （`docs_private/agents/README.md`）を入れた（PR #50。2026-11-04 にマージ済み）
- TAK-63（作業中）も FR-306 の近く（形式の検査の検証ゲートへの組み込み）を変える可能性がある

## Clarifications

### Session 2026-11-04

- Q: 共通・ローカル専用・Cloud 専用の区分を、どこで示すか？ → A: `AGENTS.md` の見出し（参照の行を含む）に必ず示す。
  参照先の文書は、文書全体の区分を冒頭に示す。区分は、エージェントがどの規則に従うかを決める入口なので、`AGENTS.md` に残す。
  参照先の文書のうち、区分を示すのは運用の文書（`docs_private/` の文書）に限る。製品仕様と記録の文書は区分を持たない（research.md の R3）
  （ほかの案: 参照先の文書ごとにだけ示す案は、区分を知るのに参照先を開く必要があるため採らない）
- Q: `specs/product/` の書き方のルールの要点（3 行）を `AGENTS.md` に残すか？ → A: 残さない。`AGENTS.md` には、
  `specs/product/` を変える前に `specs/product/README.md` の書き方のルールを読むという参照だけを置く。要点は `specs/product/` を
  変えるときにしか使わないので、参照先に置く（`docs_private/agents/README.md` の置き場所の基準の 3）
- Q: 参照切れの検出（TAK-71 の検査）を、この feature の要件に含めるか？ → A: 含める。`AGENTS.md` の行数の上限と、参照先の
  パスの検出を要件にする。仕様と検査を対応させ、検査をやめると仕様に反するようにする

## User Scenarios & Testing *(mandatory)*

### User Story 30 - ローカル運用と共存する（変更する受け入れシナリオだけ）

**Acceptance Scenarios**:

2. **US30-AS2**（変更）: **Given** エージェント向けの規約（`AGENTS.md` と、そこから参照する文書）を読む、
   - **When** ある規則が適用される運用を知りたい、
   - **Then** 共通・ローカル専用・Cloud 専用のどれかが分かる。

### User Story 66 - 書き方のルールを文書で確かめる（変更する受け入れシナリオだけ）

**Acceptance Scenarios**:

2. **US66-AS2**（変更）: **Given** `AGENTS.md`、
   - **When** Agent が `specs/product/` を変更しようとする、
   - **Then** 変更の前に `specs/product/README.md` の書き方のルールを読むことが分かる。

### User Story 67 - 運用の規則を足しても AGENTS.md が増えない (Priority: P2)

保守者が、運用に関わる feature で新しい規則を定めるとき、置き場所の基準に従って、特定の作業でしか使わない規則を
参照先の文書に置ける。製品仕様は、規則が `AGENTS.md` の本文にあることを求めない。

**Why this priority**: 仕様が `AGENTS.md` の本文を指定すると、feature のたびに `AGENTS.md` が増え、エージェントが毎回読む量が増える。
アプリの動作には影響しないので、P2 とする。

**Independent Test**: この feature の後の `specs/product/` を読み、内容を `AGENTS.md` の本文に置くことを求める要件が残っていないことと、
エージェント向けの規約として求める内容が、`AGENTS.md` かその参照先のどちらかにあれば満たされることを確かめる。

**Acceptance Scenarios**:

1. **US67-AS1**: **Given** 運用に関わる新しい feature の spec.md を書く、
   - **When** エージェントが従う規則を要件にする、
   - **Then** 置き場所を「エージェント向けの規約」として書き、`AGENTS.md` の本文とは指定しない。
2. **US67-AS2**: **Given** 特定の作業でしか使わない規則を、参照先の文書だけに置いた、
   - **When** エージェントがその作業を始める、
   - **Then** `AGENTS.md` の参照の文言から、その作業のときに読む文書が分かる。

### Edge Cases

- **EC-213**: 参照先の文書が移動・改名され、`AGENTS.md` の参照が切れた場合。
  - 参照先にしかない規則がエージェントに届かなくなるので、検査で検出して失敗させる（FR-310）。
- **EC-214**: 規則が `AGENTS.md` と参照先の文書で食い違う場合。
  - SC-094 の「異なる指示を出す規則が 0 件」は、`AGENTS.md` と参照先の文書の両方を対象に数える。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-195**（変更）: エージェント向けの規約（`AGENTS.md` と、そこから参照する文書）は、共通の規則、ローカル専用の規則、
  Cloud 専用の規則を区別して示さなければならない。
  - 各規則が、どの運用に適用されるか読み取れること。
  - `AGENTS.md` は、見出しと参照の行に区分を示す。
  - `AGENTS.md` から参照する運用の文書（`docs_private/` の文書）は、文書全体の区分を冒頭に示す。
  - FR-307 の例外: `AGENTS.md` の見出しと参照の行の区分は、エージェントがどの規則に従うかを決める入口なので、`AGENTS.md` に置く。
- **FR-306**（変更）: `specs/product/README.md` は、製品仕様の書き方のルールと、検査の実行方法、警告と基準値、
  表示幅の数え方、対象外の指定のしかたを示さなければならない。
  - 書き方のルールは、次のとおりとする
    - 1つの箇条書きに1つの要件・条件・例外を書き、条件と例外は子項目に分ける
    - 表のセルは短い要約にし、詳細は「表の詳細」に置く。`下記` と「表の詳細」を対応づける
    - インラインコード・引用・英語句・表の行を途中で改行しない
  - `AGENTS.md` は、`specs/product/` を変える前に `specs/product/README.md` を読むことを示す
    - FR-307 の例外: 書き方のルールへの参照は、`specs/product/` を変える作業の入口なので、`AGENTS.md` に置く。ルールの本文は置かない
- **FR-307**: 製品仕様が、エージェントが従う規則の置き場所を定めるときは、「エージェント向けの規約
  （`AGENTS.md` と、そこから参照する文書）」と書かなければならない。
  - `AGENTS.md` の本文に置くことを求めてはならない。
  - 例外: 規約の入口として `AGENTS.md` に置く必要がある内容（参照の一覧など）は、理由とともに要件にしてよい。
- **FR-308**: `AGENTS.md` から参照する文書への参照は、その文書を読むべき作業や状況を示さなければならない
  （例: 「バグを直す: <文書>」）。
- **FR-309**: `AGENTS.md` の行数には上限がなければならない。
  - 開発用の検査は、上限を超えたら失敗しなければならない。
  - 上限の値は検査の設定を正とし、製品仕様には書かない。
- **FR-310**: 開発用の検査は、`AGENTS.md` が参照するリポジトリのパスが存在しないとき、失敗しなければならない。
  - ブランチ名・スラッシュコマンドなど、パスでない語は対象にしない。

### Key Entities

- **エージェント向けの規約**: `AGENTS.md` と、そこから参照する文書（`docs_private/agents/`、`docs_private/cloud-agent-workflow.md`、
  `specs/product/README.md` など）の全体。エージェントが従う運用の規則を置く場所。
- **参照**: `AGENTS.md` の中で、参照先の文書と、それを読むべき作業や状況を示す1行。
- **運用の文書**: `AGENTS.md` から参照する文書のうち、エージェントが従う運用の規則を書いた `docs_private/` の文書。
  冒頭に適用範囲を示す（FR-195）。製品仕様（`specs/product/`）、憲章、feature の記録は含まない。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-094**（変更）: エージェント向けの規約の共通・ローカル専用・Cloud 専用の規則を読み比べたとき、
  同じ状況に対して異なる指示を出す規則が 0 件である。
  - `AGENTS.md` と参照先の文書の間の食い違いも数える。
- **SC-161**（変更）: 保守者と Agent が、`specs/product/README.md` と、`AGENTS.md` から参照する文書だけを読んで、
  書き方のルールと検査の実行方法を答えられる。
- **SC-162**: この feature の後の `specs/product/` で、内容を `AGENTS.md` の本文に置くことを求める要件が 0 件である
  （FR-307 の例外として理由とともに定めたものを除く）。
- **SC-163**: この feature の後の `AGENTS.md` の行数が、この feature の前（50 行）を超えない。
- **SC-164**: `AGENTS.md` が参照する文書を1つ改名すると、開発用の検査が失敗し、切れた参照のパスが表示される。
- **SC-165**: `AGENTS.md` の行数を上限より1行多くすると、開発用の検査が失敗する。

## Assumptions

- **A-192**: `AGENTS.md` に何を書くかの判断の基準は、`docs_private/agents/README.md`（TAK-71）に置く。製品仕様には置かない。
- **A-193**: 開発用の検査（FR-309・FR-310）は TAK-71（PR #50）の `scripts/dev/check-agents-md.sh` で実装する。
  この feature の実装は、TAK-71 のマージの後に行う。
- **A-194**: TAK-63 が FR-306 または `AGENTS.md` を変えた場合は、先にマージされた側に合わせて、後の側が反映の前に取り込む。
- **A-195**: アプリのコード（`Sources/`）と、Swift のビルド・テストは変更しない。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| US30-AS2、US66-AS2 | 変更 | overview.md |
| US67-AS1、AS2 | 追加 | overview.md |
| EC-213、EC-214 | 追加 | overview.md |
| FR-195、FR-306 | 変更 | overview.md |
| FR-307〜FR-310 | 追加 | overview.md |
| SC-094、SC-161 | 変更 | overview.md |
| SC-162〜SC-165 | 追加 | overview.md |
| A-192〜A-195 | 追加 | overview.md |
| エージェント向けの規約、参照、運用の文書（Key Entities） | 追加 | overview.md（主なエンティティ） |
