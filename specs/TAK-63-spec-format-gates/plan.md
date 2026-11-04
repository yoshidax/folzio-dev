# Implementation Plan: 製品仕様の形式の検査のゲートへの組み込み

**Branch**: `claude/friendly-ride-5inepi` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-63-spec-format-gates/spec.md`

## Summary

TAK-62 の形式の検査（`python3 scripts/dev/check-spec-format.py`）を、ローカルと Cloud の検証ゲート、開発用 CI の Linux のジョブ、
PR のテンプレート、SDD increment の反映の手順に組み込む。検査のスクリプト・設定・基準値と、アプリのコードは変えない。
最後に、spec.md の「反映先」に従って `specs/product/overview.md` と `specs/product/README.md` へ反映する。

## Technical Context

**Language/Version**: GitHub Actions の workflow（YAML）、Spec Kit の workflow（YAML）、Markdown の運用文書。
検査は TAK-62 の Python 3 のスクリプトをそのまま使う

**Primary Dependencies**: `actions/checkout@v4`（既存の macOS のジョブと同じ）、`ubuntu-24.04` のランナーの Python 3 と git

**Testing**: 既存の回帰テスト（`test_check_spec_*.py`）と、崩した `specs/product/` での CI と同じコマンドの手動の実行（quickstart.md）

**Target Platform**: 開発用リポジトリの GitHub Actions、保守者の macOS、Cloud の Linux

**Project Type**: 開発用の CI と運用文書。アプリ（Swift）のコードは変えない

**Constraints**: CI の動く条件（FR-190）を変えない。macOS のジョブの内容を変えない（SC-164）。公開書き出しに影響しない

**Scale/Scope**: workflow 1、PR のテンプレート 1、`AGENTS.md`、手順書 1、SDD increment の共通の手順 1、
Spec Kit の workflow 6（`workflow-src` の3つと、登録済みの3つ）と登録表、反映先の `overview.md` と `README.md`

## Constitution Check

| 原則 | 判定 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 適合 | アプリのコードを変えない。追加するジョブはネットワークを使う検査をしない |
| II 体感パフォーマンス | 対象外 | アプリの動作を変えない |
| III キーボードファースト | 対象外 | UI を変えない |
| IV テスト必須 | 適合 | CI で検査の回帰テストを実行する。崩した入力での失敗を手で確かめる（SC-163） |
| V シンプルさ | 適合 | 新しい依存はない。既存の workflow に1ジョブを足すだけで、新しい workflow とトリガーを作らない |

## 設計の判断

### R1 CI のジョブの形

- 既存の `.github/workflows/macos-swift-ci.yml` に、`ubuntu-24.04` のジョブ `spec-checks` を足す
- トリガーは workflow で共有するので、動く条件は macOS のジョブと同じになる（FR-190、SC-156 を保つ）
- `needs` を付けず、macOS のジョブと独立に動かす（EC-215）。`concurrency` も workflow で共有する
- 手順: チェックアウト → `python3 --version` → 形式の検査 → 回帰テスト（`test_check_spec_*.py`）。タイムアウトは 5 分
- ランナーは `ubuntu-latest` ではなく `ubuntu-24.04` に固定する。macOS のジョブが `macos-15` に固定しているのにそろえる
- workflow の名前（`macOS Swift CI`）は変えない。手順書の手動実行の案内（Actions タブの workflow 名）が変わらないようにする
- 却下した案: push ごと（`synchronize`）に動く別の workflow。FR-190 と、CI の起動に保守者の許可を求める運用を変えるため

### R2 equivalence チェックを CI に入れない

- equivalence チェックは、本文を変える通常の PR では必ず失敗する（FR-304）。形式だけを変える PR でしか意味がないので、
  必須の検査にしない（FR-309）
- 回帰テストは CI で実行し、検査器そのものの故障は検出する

### R3 検証ゲートでの位置

- ローカルの Phase の検証ゲートでは、手順 3（ネットワーク・README・コメント・スキルの検査）に加える
- Cloud の検証ゲートでは、`AGENTS.md` と手順書 5 章の「Cloud で行う」に加え、「CI で行う」にも Linux のジョブを書く
- 検査は 1 秒程度で終わるので、`specs/product/` を変えない作業でも実行する（FR-307）

### R4 SDD increment の手順

- 共通の手順（`shared-skills/folzio-sdd-increment.md`）の手順 5 に、反映の後に形式の検査を実行し、
  エラー 0 件・警告が基準値以下であることを確かめてから提示する、と加える
- workflow（`sdd-increment`・`sdd-increment-kilo`・`sdd-increment-codex`）は、次の2か所を変える
  - `merge_back` の指示に、反映の後に形式の検査を実行して直すことと、結果を出力に含めることを加える
  - `commit_product` で、コミットの前に形式の検査を実行し、失敗したらコミットせずに止める（US67-AS5）
- 変えるのは `.specify/workflow-src/` と、登録済みの `.specify/workflows/<名前>/workflow.yml` の両方。
  両者は同じ内容である（`specify workflow add --dev` が複製する）ので、同じ変更を入れ、版を上げる
- 登録表（`.specify/workflows/workflow-registry.json`）の版も合わせる。Cloud では `specify` の CLI を使えないため手で直す。
  保守者がローカルで `specify workflow add --dev` を実行し直しても、内容は同じになる

### R5 入れない項目（A-192〜A-194）

- `scripts/dev/publish.sh`: `specs/` は書き出しから除かれ、混入したら止まる
- `scripts/dev/sdd-codex.py` の `verify_workspace`: 反映の前に動くので、反映の崩れを検出できない。反映の後は R4 の workflow で検査する
- `.specify/templates/tasks-template.md`: Spec Kit の生成物で、更新で上書きされるおそれがある

## Project Structure

### Documentation (this feature)

```text
specs/TAK-63-spec-format-gates/
├── spec.md
├── plan.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
.github/
├── workflows/macos-swift-ci.yml   # Linux のジョブ spec-checks を足す（R1）
└── pull_request_template.md       # 「検証」の案内に形式の検査を足す（FR-310）

AGENTS.md                          # ローカルと Cloud の検証ゲート、「製品仕様の書き方」、区分の表、検証用コマンド
docs_private/cloud-agent-workflow.md  # 4 章（CI の構成）、5 章（検証ゲート）、7 章（反映の後の検査）
shared-skills/folzio-sdd-increment.md # 手順 5（R4）

.specify/workflow-src/sdd-increment{,-kilo,-codex}.yml          # R4
.specify/workflows/sdd-increment{,-kilo,-codex}/workflow.yml    # R4（同じ内容）
.specify/workflows/workflow-registry.json                        # 版

specs/product/
├── overview.md                    # 最後に要件を反映する。A-187 を削除する
└── README.md                      # 「形式の検査」に、実行される場所を加える
```

**Structure Decision**: 新しいファイルは作らない。既存の workflow・テンプレート・文書に追記する。

## 反映の方針

- 実装と検証の後、spec.md の「反映先」に従い、`overview.md` の節「製品仕様の形式の検査」に US・EC・FR・SC・A を加え、A-187 を削除する
- 反映の直前に `git merge origin/master` で最新の master を取り込み、`scripts/dev/check-spec-ids.sh` で ID の重複を確かめる
- 反映した `specs/product/` に形式の検査をかけ、エラー 0 件と基準値以下を確かめる

## Complexity Tracking

違反はない。
