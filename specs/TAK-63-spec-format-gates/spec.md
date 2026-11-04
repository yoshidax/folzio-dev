# Feature Specification: 製品仕様の形式の検査のゲートへの組み込み

**Feature Branch**: `claude/friendly-ride-5inepi`（Cloud が指定する作業ブランチ。feature ディレクトリ名とは独立）

**Created**: 2026-11-04

**Status**: Draft

**Input**: [TAK-63](https://linear.app/takyoshida/issue/TAK-63)
「specs/product の形式チェックを検証ゲート・CI・テンプレートに組み込む」
（前提: TAK-62（検査の追加。マージ済み `5e8d73f`）。関連: TAK-61 / PR #46）

## 既存の仕様との関係

この feature は、TAK-62 で作った形式の検査（FR-296〜FR-306（overview.md））を、検証ゲート・開発用 CI・PR のテンプレート・
SDD increment の手順に組み込む。検査そのもの（検出項目、しきい値、基準値、終了コード）と、アプリの動作は変えない。

- 開発用 CI の動く条件（FR-190（overview.md）。PR の作成時・Ready にしたとき・手動実行）は変えない。
  SC-156（overview.md）の条件も保つ
- 検証ゲートの区分（FR-192（overview.md）。Cloud・CI・保守者）は変えず、各区分に形式の検査を加える
- A-187（overview.md）の「組み込みは TAK-63 で行う。それまでは手で実行する」は、この feature で満たされるので削除する
- 公開書き出し（`scripts/dev/publish.sh`）は変えない。`specs/` は書き出しから除かれ、混入したら書き出しが止まる
  （FR-177〜FR-180（overview.md））

### 現状（2026-11-04、`origin/master` の `5e8d73f` で確認）

- `python3 scripts/dev/check-spec-format.py` は、エラー 0 件・警告 88 件（基準値 88）で成功する
- `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_*.py"` は 33 件すべて成功する
- 検査を実行する指示は `AGENTS.md` の「製品仕様の書き方」と `specs/product/README.md` の「形式の検査」にあり、
  ローカルの Phase の検証ゲート、Cloud の検証ゲート、CI、PR のテンプレートには含まれていない
- 開発用 CI（`.github/workflows/macos-swift-ci.yml`）は、macOS の1つのジョブで `swift build` と `swift test` だけを行う

## Clarifications

### Session 2026-11-04

- Q: 進め方は？ → A: feature ディレクトリで扱う（clarify は skip）。A-187 の削除と CI の要件の追加が `specs/product/` に及ぶため。
- Q: CI で検査をどの形で動かすか？ → A: 既存の workflow に、Linux の軽いジョブを足す。動く条件は macOS のジョブと同じにし、
  FR-190 の CI の運用（push ごとには動かさない、再実行は保守者の許可を得る）を変えない。
  （ほかの案: push ごとに動く別の workflow は、早く検知できるが CI の運用を変えるので採らない。macOS のジョブの step にする案は、
  macOS の使用時間を使い、Swift の結果と混ざるので採らない）
- Q: Issue の任意の項目のどれを入れるか？ → A: PR のテンプレートと、SDD increment の反映の手順（共通の手順と workflow）に入れる。
  `scripts/dev/publish.sh`、`scripts/dev/sdd-codex.py` の検証、Spec Kit の tasks テンプレートには入れない（理由は A-192〜A-194）。

## User Scenarios & Testing *(mandatory)*

### User Story 67 - 仕様の変更が検証ゲートと CI で検査される (Priority: P1)

保守者と Agent は、検証ゲートを行うと、ほかの検査と一緒に `specs/product/` の形式の検査を実行する。
PR を作ると、開発用 CI でも同じ検査が動き、崩れがあれば PR の check が失敗する。
SDD increment で `specs/product/` へ反映したときも、コミットの前に検査が動く。

**Why this priority**: TAK-62 の検査は、手で実行しなければ働かない。ゲートと CI に組み込まなければ、崩れの再発を防げない。

**Independent Test**: 検査が失敗する崩れた文書と、成功する文書のそれぞれで、CI のジョブと同じコマンドを実行し、終了コードを確かめる。
`AGENTS.md`、手順書、PR のテンプレート、SDD increment の手順と workflow を読み、同じコマンドが書かれていることを確かめる。

**Acceptance Scenarios**:

1. **US67-AS1**: **Given** `AGENTS.md` のローカルの Phase の検証ゲート、**When** 保守者がゲートを行う、
   **Then** 形式の検査を、ほかの検査と同じ段階で実行する。
2. **US67-AS2**: **Given** `AGENTS.md` と手順書の Cloud の検証ゲート、**When** Agent がゲートを行う、
   **Then** 形式の検査を実行し、結果を PR の「検証」に書く。
3. **US67-AS3**: **Given** `specs/product/` に形式のエラーがある作業ブランチ、**When** PR の作成時または Ready にしたときに CI が動く、
   **Then** Linux のジョブが失敗し、PR の check で失敗が分かる。
4. **US67-AS4**: **Given** 形式のエラーがなく、警告が基準値以下の作業ブランチ、**When** CI が動く、**Then** Linux のジョブは成功する。
5. **US67-AS5**: **Given** SDD increment の workflow で `specs/product/` へ反映し、反映の確認を approve した、
   **When** 形式の検査が失敗する、**Then** 反映はコミットされずに workflow が止まる。
6. **US67-AS6**: **Given** PR のテンプレート、**When** 作成者が「検証」を書く、**Then** 形式の検査と、形式だけを変える変更での
   equivalence チェックが、結果を書く検査として示されている。

---

### Edge Cases

- **EC-213**: `specs/product/` を変えない PR でも、CI の Linux のジョブは形式の検査を実行する。
  - 取り込んだ master に崩れがあれば、その PR のジョブも失敗する
- **EC-214**: 警告が基準値を下回った場合、CI のジョブは成功する（FR-300（overview.md））。
  - 基準値の更新は、作成者が `--update-baseline` で行う
- **EC-215**: Linux のジョブと macOS のジョブは、互いの結果を待たずに動く。
  - 一方が失敗しても、もう一方は最後まで動く

## Requirements *(mandatory)*

### Functional Requirements

- **FR-307**: ローカルの Phase の検証ゲートと Cloud の検証ゲートは、形式の検査（`python3 scripts/dev/check-spec-format.py`）
  を含まなければならない。
  - 検査は、`specs/product/` を変えない作業でも実行する
- **FR-308**: 開発用 CI は、形式の検査と、形式の検査と equivalence チェックの回帰テストを、macOS のジョブとは別の Linux のジョブで
  実行しなければならない。
  - Linux のジョブの動く条件は、macOS のジョブと同じとする（FR-190（overview.md））
  - 検査またはテストが失敗したら、ジョブが失敗し、PR の check で分かる
- **FR-309**: equivalence チェックは、検証ゲートと CI の必須の検査にしてはならない。
  - 形式だけを変える変更で実行し、結果を PR に書く
- **FR-310**: PR のテンプレートの「検証」は、形式の検査と、形式だけを変える変更での equivalence チェックを、
  実行して結果を書く検査として示さなければならない。
- **FR-311**: SDD increment の手順は、`specs/product/` への反映の後に、形式の検査を実行しなければならない。
  - 対象は、共通の手順（`shared-skills/folzio-sdd-increment.md`）と、sdd-increment の workflow（Claude・Kilo・Codex）
  - workflow は、検査が失敗したら反映をコミットせずに止まる

### Key Entities

- **形式の検査**: `scripts/dev/check-spec-format.py`（FR-296（overview.md））
- **Linux のジョブ**: 開発用 CI の workflow に足す、Swift を使わない検査のジョブ

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-162**: ローカルの検証ゲート、Cloud の検証ゲート、CI の Linux のジョブ、SDD increment の反映の手順のすべてで、
  同じコマンド（`python3 scripts/dev/check-spec-format.py`）が実行される。
- **SC-163**: 形式のエラーを1つ入れた `specs/product/` で、CI の Linux のジョブと同じコマンドが終了コード 1 で終わる。
  - 崩していない `specs/product/` では、終了コード 0 で終わる
- **SC-164**: 開発用 CI の macOS のジョブの動く条件と内容が、TAK-63 の前と変わらない。

## Assumptions

- **A-192**: 公開書き出し（`scripts/dev/publish.sh`）には、形式の検査を加えない。
  - `specs/` は書き出しから除かれ、混入したら書き出しが止まるため、公開物の検査には当たらない
- **A-193**: `scripts/dev/sdd-codex.py` の検証には、形式の検査を加えない。
  - その検証は `specs/product/` への反映の前に動くため、反映の崩れを検出できない
  - 反映の後の検査は、workflow の反映の段階で行う（FR-311）
- **A-194**: Spec Kit の tasks テンプレート（`.specify/templates/tasks-template.md`）には、確認の項目を加えない。
  - Spec Kit が生成する英語の汎用のテンプレートで、更新で上書きされるおそれがある
  - feature の tasks.md の反映のタスクは、`AGENTS.md` と手順書の検証ゲートに従う
- **A-195**: CI の Linux のジョブは、ランナーに入っている Python 3 を使う。
  - Python 3.9 での動作（A-191（overview.md））は、保守者のローカルで確かめる

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| US67-AS1〜AS6 | 追加 | overview.md |
| EC-213〜EC-215 | 追加 | overview.md |
| FR-307〜FR-311 | 追加 | overview.md |
| SC-162〜SC-164 | 追加 | overview.md |
| A-192〜A-195 | 追加 | overview.md |
| A-187 | 削除 | overview.md（この feature で組み込んだため） |
| — | 変更 | README.md（「形式の検査」に、実行される場所を加える） |
