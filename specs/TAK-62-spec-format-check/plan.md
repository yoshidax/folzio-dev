# Implementation Plan: 製品仕様の形式の検査

**Branch**: `claude/gallant-faraday-2z1fe7` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/TAK-62-spec-format-check/spec.md`

## Summary

`specs/product/` の形式の崩れを検出する `scripts/dev/check-spec-format.py` と、形式のみの変更であることを確かめる
`scripts/dev/check-spec-equivalence.py` を、Python の標準ライブラリだけで作る。形式の検査は行単位の状態機械で Markdown を読み、
エラー（1件でも失敗）と警告（ファイル・項目ごとの基準値を超えたら失敗）を出す。対象外の範囲としきい値は設定ファイル、
警告の件数は基準値ファイルに置く。equivalence チェックは、記号・空白・句読点と形式の印を除いた本文を文字単位で比べ、
移動・追加・削除の一覧を出す。既存の分断のうち 7 か所を形式のみで直し、書き方のルールを `specs/product/README.md` と `AGENTS.md` に書く。
ゲートへの組み込みは TAK-63 で行う（research.md の R1〜R14）。

## Technical Context

**Language/Version**: Python 3.9 以降（標準ライブラリだけ。Cloud は 3.13、保守者のローカルは 3.9 の場合がある）

**Primary Dependencies**: `unicodedata`、`difflib`、`json`、`argparse`、`subprocess`（`git merge-base`、`git ls-tree`、`git show`）

**Storage**: リポジトリのファイル（設定 `scripts/dev/spec-format-config.json`、基準値 `scripts/dev/spec-format-baseline.json`）

**Testing**: `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_*.py"`（Cloud とローカルの両方）

**Target Platform**: 保守者の macOS と Cloud の Linux

**Project Type**: 開発用のスクリプトと運用文書。アプリ（Swift）のコードは変えない

**Performance Goals**: 形式の検査は `specs/product/` 全体で 2 秒以内。equivalence チェックは全体が整形された場合でも 30 秒以内

**Constraints**: 外部パッケージを使わない。ネットワークを使わない。`specs/product/` の本文に検査のための記述を入れない（R10）

**Scale/Scope**: `specs/product/` は 15 ファイル、約 5,900 行。変更するファイルは、スクリプト 2、設定と基準値 2、テスト 2、
`specs/product/` の 3（分断の修正）と README、`AGENTS.md`、反映先の `overview.md`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I ローカル完結・プライバシー | 適合 | アプリのコードを変えない。スクリプトはネットワークを使わない |
| II 体感パフォーマンス | 対象外 | アプリの動作を変えない |
| III キーボードファースト | 対象外 | UI を変えない |
| IV テスト必須 | 適合 | 検出項目と合否の判定ごとに、崩した入力と崩していない入力の回帰テストを付ける（FR-305） |
| V シンプルさ | 適合 | 新しい依存はない。Markdown のパーサーは作らず、`specs/product/` が使う構文だけを行単位で読む。設定は対象外としきい値だけ |

Phase 1 の後の再確認: data-model.md と contracts/ の設計でも、上の判定は変わらない。

「仕様の管理」との関係: この feature の変更点は、実装と検証の後に `specs/product/overview.md` と `specs/product/README.md` へ反映する。
既存の分断の修正は、改行の位置だけを変え、ID と本文は変えない（SC-160 で確かめる）。

## Project Structure

### Documentation (this feature)

```text
specs/TAK-62-spec-format-check/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cli.md           # 2つの検査のコマンド・出力・終了コード、設定と基準値の形式
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で作る
```

### Source Code (repository root)

```text
scripts/dev/
├── check-spec-format.py           # 新規: 形式の検査（FR-296〜FR-301）
├── check-spec-equivalence.py      # 新規: equivalence チェック（FR-302〜FR-304）
├── spec-format-config.json        # 新規: しきい値と対象外の範囲（R5、R10）
├── spec-format-baseline.json      # 新規: 警告の基準値（R4）
└── tests/
    ├── test_check_spec_format.py       # 新規（FR-305）
    └── test_check_spec_equivalence.py  # 新規（FR-305）

specs/product/
├── README.md                      # 書き方のルールと形式の検査（FR-306）
├── overview.md                    # 最後に要件を反映する（「出発点となった要望」の引用は対象外の設定にし、変えない）
├── file-operations.md             # 分断の修正
├── window-layout.md               # 分断の修正
└── contracts/settings.md          # 分断の修正

AGENTS.md                          # 【共通】「製品仕様の書き方」と区分の表（FR-306）
```

**Structure Decision**: 既存の開発用の検査（`check-spec-ids.sh`、`check-skill-sync.sh`）と同じく `scripts/dev/` に置き、
テストは `scripts/dev/tests/` に置く。どちらも `.gitattributes` の既存の設定で公開書き出しから除かれる（`scripts/dev/` 全体が対象）。

## 反映の方針

- 実装と検証の後、spec.md の「反映先」の表に従い、`overview.md` に節「製品仕様の形式の検査」を作って US・EC・FR・SC・A を移す
- 反映の直前に `git merge origin/master` で最新の master を取り込み、`scripts/dev/check-spec-ids.sh` で ID の重複を確かめる
  （`docs_private/cloud-agent-workflow.md` の 7 章）。重複したら、この feature の ID を振り直す
- 反映した `specs/product/` にも形式の検査をかけ、エラー 0 件と基準値以下を確かめる。新しい警告が出た場合は、直すか、
  理由を示して基準値を更新する

## Complexity Tracking

違反はない。
