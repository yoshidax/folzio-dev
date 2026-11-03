# Feature Specification: 開発用と公開用の workflow の管理

> **移行済み（2026-11-03）**: 現在の仕様は [specs/product/](../product/README.md) を正とする。
> このファイルは TAK-40 時点の記録として凍結しており、更新しない。

**Feature Branch**: `claude/gracious-dijkstra-du6nx2`（Cloud が指定する作業ブランチ。feature ディレクトリ名とは独立）

**Created**: 2026-11-03

**Status**: Draft

**Input**: [TAK-40](https://linear.app/takyoshida/issue/TAK-40)「開発用 macOS CI を公開対象から除外し、dev / OSS 固有の workflow 管理方針を決める」
（関連: TAK-41（この feature の後に、公開用リポジトリでアプリをビルドしてリリースする）、TAK-35、TAK-25）

## 既存の仕様との関係

この feature は、開発用リポジトリから公開用リポジトリへの書き出しを扱う。アプリの動作は変えない。

- **FR-177〜FR-180（overview.md）** と `contracts/scripts.md` の「開発専用のファイルを個別の除外設定なしに書き出しから除き、
  混入したら同期の前に止める」という考え方を、GitHub Actions の workflow に広げる
- 開発用の CI（FR-190〜FR-192（overview.md））の動く条件と内容は変えない
- 現行の配布方式（FR-169〜FR-176（overview.md））は変えない。公開用リポジトリの Actions による配布への移行は TAK-41 で扱う
- 公開用リポジトリは手で編集せず、開発用から書き出すという方針（`docs_private/repository-and-release.md`）を維持する

### 現状（2026-11-03、`origin/master` の `be9d576` で確認）

- `.gitattributes` で除外している `.github/` 配下のファイルは `pull_request_template.md` だけで、`.github/workflows/macos-swift-ci.yml`
  は書き出しに含まれる
- 書き出しは `git archive HEAD` で取り出し、`rsync -a --delete` で公開先を書き出し内容にそろえる。保護するのは `.git`、`.build`、
  `.vscode` だけなので、公開先にだけ置いた workflow は次の書き出しで消える

## Clarifications

### Session 2026-11-03

- Q: 公開用リポジトリ専用の workflow（TAK-41 のビルド・リリース用など）の元ファイルを、どこで管理するか？ → A: 開発用リポジトリの
  専用ディレクトリ `scripts/dev/oss-workflows/` で管理し、公開書き出しのときに公開用リポジトリの workflow の配置
  （`.github/workflows/`）へ置く。開発用リポジトリの `.github/workflows/` はディレクトリごと書き出しから除く。
  （ほかの案: 開発用の `.github/workflows/` に同居させてリポジトリ名の条件で止める案は、開発用の Actions に公開用の workflow が並び、
  除外の指定漏れで混入するため採らない。公開用リポジトリで直接管理する案は、管理元が 2 か所になり、手で編集しない方針と矛盾するため採らない）
- Q: この feature で扱う範囲は？ → A: 開発用 workflow の書き出しからの除外、公開用 workflow を書き出しで置く仕組み、検査、回帰テスト、
  運用手順まで。公開用の workflow 本体（ビルドと Release への添付）は TAK-41 で作る。この feature の時点では、公開用の workflow の定義はない
- Q: 進め方は？ → A: Spec Kit の feature（`specs/TAK-40-oss-workflow-policy/`）として進め、最後に `specs/product/overview.md` へ反映する

## User Scenarios & Testing *(mandatory)*

### User Story 61 - 開発用の CI を公開から除く (Priority: P1)

保守者が公開用リポジトリへ書き出すと、開発用リポジトリの CI（今の macOS の CI と、今後増える開発用の workflow）は書き出しに含まれない。
開発用リポジトリでは、CI が今までどおり動く。

**Why this priority**: TAK-40 の直接の目的。開発用の CI（Cloud Agent の運用に合わせたトリガーや、開発専用の検査）が公開用リポジトリで
動くと、公開用リポジトリの利用者と保守者に無意味な実行と失敗を見せ、macOS の実行時間も使う。

**Independent Test**: 一時リポジトリに開発用の workflow（既存の名前と新しい名前）を置いて書き出し、公開先の workflow の配置に
含まれないことを確かめる。

**Acceptance Scenarios**:

1. **US61-AS1**: **Given** 開発用リポジトリの workflow の配置に `macos-swift-ci.yml` がある、**When** 公開用に書き出す、
   **Then** 公開先に `macos-swift-ci.yml` は置かれない。
2. **US61-AS2**: **Given** 開発用リポジトリの workflow の配置に、新しい開発用の workflow（例: TAK-35 の検査ジョブ）を追加した、
   **When** 除外の設定を変えずに書き出す、**Then** 新しい workflow も公開先に置かれない。
3. **US61-AS3**: **Given** 除外の設定の不備で、開発用の workflow が書き出しに含まれる、**When** 公開前の混入検査を行う、
   **Then** 公開先への同期の前に失敗し、公開先は変わらない。
4. **US61-AS4**: **Given** この feature の変更後の開発用リポジトリ、**When** PR を作る、Ready にする、または手動で実行する、
   **Then** 開発用の CI が今までと同じ条件で動く。

---

### User Story 62 - 公開用の workflow を開発用リポジトリで管理して書き出す (Priority: P1)

保守者は、公開用リポジトリだけで動かす workflow（将来のアプリのビルドと Release への添付）を開発用リポジトリの管理元に置き、
書き出しで公開用リポジトリの workflow の配置へ反映する。追加・変更・削除のどれも、書き出しを繰り返して正しく反映される。

**Why this priority**: TAK-41（公開用リポジトリでのビルドとリリース）の前提。管理元が決まっていないと、公開用の workflow が
次の書き出しで消えるか、公開用リポジトリを手で編集することになる。

**Independent Test**: 一時リポジトリの管理元に公開用の workflow を置いて書き出し、公開先の workflow の配置に同じ内容で置かれることを
確かめる。続けて、管理元から削除して書き出し、公開先からも消えることを確かめる。

**Acceptance Scenarios**:

1. **US62-AS1**: **Given** 管理元に公開用の workflow `release.yml` がある、**When** 書き出す、**Then** 公開先の workflow の配置に、
   管理元と同じ内容の `release.yml` が置かれる。開発用リポジトリでは、`release.yml` は workflow として動かない。
2. **US62-AS2**: **Given** 前回の書き出しで公開先に置いた `release.yml` を、管理元で変更した、**When** 書き出す、
   **Then** 公開先の `release.yml` が変更後の内容になる。
3. **US62-AS3**: **Given** 前回の書き出しで公開先に置いた `release.yml` を、管理元から削除した、**When** 書き出す、
   **Then** 公開先から `release.yml` が消える。
4. **US62-AS4**: **Given** 管理元に公開用の workflow がない（この feature の時点の状態）、**When** 書き出す、
   **Then** 公開先に workflow は置かれない。
5. **US62-AS5**: **Given** 管理元と同じ名前の workflow が開発用リポジトリの workflow の配置にもある、**When** 書き出す、
   **Then** 公開先には管理元のほうの内容だけが置かれる。

---

### User Story 63 - workflow の管理の方針を文書で確かめる (Priority: P2)

保守者と Agent は、運用手順を読んで、開発用・公開用それぞれの workflow をどこに置き、どう更新し、書き出しでどう扱われるかを確かめられる。

**Why this priority**: 置き場所を間違えると、開発用の workflow が公開されるか、公開用の workflow が書き出しで消える。
TAK-41・TAK-35 で workflow を足す人が、手順書だけで正しく置けるようにする。

**Independent Test**: 運用手順だけを読んで、開発用の workflow と公開用の workflow を追加する場所、更新の手順、書き出しでの扱い、
公開用リポジトリで直接編集した場合の結果を答えられるかを確かめる。

**Acceptance Scenarios**:

1. **US63-AS1**: **Given** 運用手順、**When** 保守者が公開用の workflow を追加しようとする、**Then** 管理元の場所、書き出しで置かれる場所、
   公開用リポジトリでの反映の手順（書き出し・確認・コミット・push）が分かる。
2. **US63-AS2**: **Given** 運用手順、**When** 保守者が開発用の workflow を追加しようとする、**Then** 置く場所と、除外の設定を足さなくても
   書き出しから除かれることが分かる。

---

### Edge Cases

- **EC-203**: 公開用リポジトリの workflow の配置に、書き出しを通さずに直接加えた workflow は、次の書き出しで消える（FR-292）。
  公開用リポジトリでコミット済みのファイルなら、書き出しの最後に示す変更の一覧に削除として現れる。コミットしていないファイルは、
  一覧に現れずに消える。
- **EC-204**: 管理元に workflow の定義ではないファイル（説明の文書など）がある場合、そのファイルは公開先に置かない。
- **EC-205**: 管理元にサブディレクトリがある場合、その中のファイルは公開先に置かない（GitHub Actions は workflow の配置の直下の定義だけを読むため）。
- **EC-206**: 開発用リポジトリの `.github/` 配下の、workflow 以外のファイル（PR テンプレートなど）の扱いは、この feature では変えない。
  既存の個別の除外設定に従う。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-289**: 開発用リポジトリの workflow の配置（`.github/workflows/`）にある workflow は、すべて開発用とし、個別の除外設定なしに
  公開書き出しから除かれなければならない。開発用リポジトリでは、引き続き CI として動く。
- **FR-290**: 公開用リポジトリだけで動かす workflow は、開発用リポジトリの開発専用ディレクトリの中の管理元（`scripts/dev/oss-workflows/`）
  で管理しなければならない。管理元の workflow は、開発用リポジトリでは workflow として動かない。公開用リポジトリでは直接編集しない。
- **FR-291**: 公開書き出しは、管理元の直下にある workflow の定義（拡張子 `.yml` または `.yaml` のファイル）だけを、同じ名前と内容で
  公開先の workflow の配置へ置かなければならない。それ以外のファイルは置かない（EC-204・EC-205）。管理元に定義がないときは、
  公開先に workflow を置かない。
- **FR-292**: 書き出しを繰り返したとき、公開先の workflow の配置は、そのときの管理元の workflow の定義と一致しなければならない。
  管理元での追加・変更・削除が反映され、公開先に直接加えた workflow は残らない。
- **FR-293**: 公開前の混入検査は、開発用の workflow が書き出しに含まれる場合と、書き出しの workflow の配置が管理元の workflow の定義と
  一致しない場合に、公開先への同期の前に中止しなければならない。
- **FR-294**: 書き出しの回帰検証は、既存・新規の開発用 workflow の除外、管理元の workflow の配置と内容、管理元に定義がない場合、
  管理元で削除した workflow の公開先からの削除、定義ではないファイルを置かないこと、除外設定の不備での同期前の停止を確かめなければならない。
- **FR-295**: 運用手順は、開発用と公開用それぞれの workflow について、管理元、公開先での配置、追加と更新の手順、書き出しでの扱い
  （公開用リポジトリで直接編集した場合を含む）を示さなければならない。

### Key Entities

- **開発用 workflow**: 開発用リポジトリの `.github/workflows/` にある workflow。開発用リポジトリだけで動き、書き出さない
  （例: `macos-swift-ci.yml`、TAK-35 の検査ジョブ）
- **公開用 workflow**: 公開用リポジトリだけで動かす workflow。元のファイルは開発用リポジトリの管理元にあり、書き出しで公開用リポジトリの
  `.github/workflows/` に置かれる（例: TAK-41 のビルドとリリース）
- **管理元**: 公開用 workflow の元のファイルを置く、開発用リポジトリの `scripts/dev/oss-workflows/`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-153**: 公開書き出しの結果に含まれる開発用 workflow が 0 件である（既存の macOS の CI と、除外の設定を変えずに追加した開発用 workflow の両方）。
- **SC-154**: 管理元での追加・変更・削除の後に書き出しを繰り返したとき、公開先の workflow の配置と管理元の workflow の定義の差（混入、消し忘れ、
  古い内容の残り）が、どの回でも 0 件である。
- **SC-155**: 保守者が運用手順だけを読んで、開発用と公開用の workflow それぞれについて、追加する場所と書き出しでの扱いを正しく答えられる。
- **SC-156**: 開発用リポジトリの CI が、この feature の前と同じ条件（PR の作成時・Ready にしたとき・手動実行）で動く。

## Assumptions

- **A-182**: 公開用 workflow の本体（アプリのビルドと Release への添付）は TAK-41 で作る。この feature の時点では、管理元に workflow の
  定義はなく、公開先にも workflow は置かれない。
- **A-183**: 公開用 workflow は、開発用リポジトリでは実行できない。動作の確認は、公開用リポジトリで実行するとき（TAK-41）に行う。
- **A-184**: 公開用リポジトリは、書き出しでだけ更新する。公開用リポジトリで GitHub の画面などから workflow を直接編集する運用は採らない。
- **A-185**: 開発用 workflow と公開用 workflow で、同じファイル名を使ってもよい。開発用 workflow は書き出さないため、公開先では衝突しない。
- **A-186**: 公開書き出しの検証のうち、`scripts/dev/tests` の公開のテストは、保守者がローカル（macOS と `rsync`）で実行する。
  Cloud では実行できない場合がある（`docs_private/cloud-agent-workflow.md` の「検証ゲート」）。

## 反映先

| ID | 種別 | 反映先 |
|---|---|---|
| US61-AS1〜AS4、US62-AS1〜AS5、US63-AS1、AS2 | 追加 | overview.md |
| EC-203〜EC-206 | 追加 | overview.md |
| FR-289〜FR-295 | 追加 | overview.md |
| SC-153〜SC-156 | 追加 | overview.md |
| A-182〜A-186 | 追加 | overview.md |
| — | 追加 | contracts/scripts.md（書き出しでの workflow の除外と配置。plan.md の「反映の方針」） |
