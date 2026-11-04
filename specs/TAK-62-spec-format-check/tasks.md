# Tasks: 製品仕様の形式の検査

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、
[contracts/cli.md](contracts/cli.md)、[quickstart.md](quickstart.md)

テストは FR-305 が求めるので作る。US64（形式の検査）と US65（equivalence チェック）は別のファイルなので並列（`[P]`）にできるが、
既存の分断の修正（T012）は両方の完成を前提とする。アプリのコード（`Sources/`、`Tests/`）、`.github/`、`README*.md`、`docs/` は変更しない。
検証ゲート・CI・テンプレートへの組み込みは TAK-63 で行うので、このタスクには含めない。

## Phase 1: 準備

- [X] T001 `git fetch origin master` の後、`git merge-base --is-ancestor origin/master HEAD` で取り込み済みであることを確かめる。
  先に進んでいたら `git merge origin/master` で取り込む（履歴は書き換えない）。
- [X] T002 変更前の状態を記録する。`scripts/dev/check-spec-ids.sh` が成功すること、既存の `scripts/dev/tests` のうち
  `test_check_git_push.py` と `test_check_skill_sync.py` が通ることを確かめる。

## Phase 2: User Story 64 - 製品仕様の形式の崩れを検出する (P1) 🎯 MVP

**Goal**: `scripts/dev/check-spec-format.py` が、FR-297 のエラーと FR-298 の警告を検出し、基準値と比べて合否を出す。

**Independent Test**: `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_format.py"`（quickstart.md）。

- [X] T003 [P] [US64] `scripts/dev/tests/test_check_spec_format.py` を作る（この時点では失敗することを確かめる）。一時ディレクトリに
  スクリプトをコピーし、`specs/product/` に Markdown、`scripts/dev/` に設定と基準値を置いて実行する。次を確かめる。
  - 崩していない文書（見出し・箇条書き・表・`下記` と「表の詳細」・コードブロック・1行で閉じた引用とインラインコード）で成功する
  - 各エラー（`line-width` の 160 桁超、`table-row-split` の2つの形、`table-columns`、`table-separator`、`table-empty`、`code-split`、
    `quote-split`（「」と“ ”）、`english-split`、`see-below-detail`）で、該当する行が出力され、終了コード 1 になる（US64-AS2〜AS4）
  - 各警告（`line-width` の 120 桁超、`cell-width`、`multi-sentence`）が、基準値を超えると終了コード 1、基準値以下なら 0 になる。
    基準値を下回ると 0 で、更新を促す表示が出る（US64-AS5、AS6）
  - `--update-baseline` で基準値が現在の件数になる。エラーがあるときは書き換えない
  - 表示幅: 全角は 2 桁、`→` などの曖昧な幅の文字は 1 桁、行頭のインデントを含む（FR-299）
  - コードブロックの中の長い行・`|` で始まる行・閉じない引用は検出しない（EC-207）
  - 入れ子の引用とインラインコードの中の `「` を誤検出しない（EC-208）。`\|` を列の区切りとして数えない（EC-209）
  - `下記` の行が、キーで始まる見出しの「表の詳細」の項目と対応する（同じキーの行が複数ある場合を含む。EC-210）
  - 設定の `section` と `table_columns` で指定した範囲の、指定した検出項目だけが対象外になる（US64-AS7）。存在しないファイル・見出しの
    指定は終了コード 2
- [X] T004 [US64] `scripts/dev/spec-format-config.json` を作る（data-model.md の「設定」。しきい値 120 / 160 / 80、対象外の 2 件と理由）。
- [X] T005 [US64] `scripts/dev/check-spec-format.py` を作る（contracts/cli.md、research.md の R2〜R10）。Python 3.9 で動く書き方にし、
  コメントは英語で書く。行の種類の判定、表のまとまりの検査、各検出項目、対象外の適用、基準値との比較、`--update-baseline`、終了コードを実装する。
- [X] T006 [US64] T003 のテストが通ることを確かめる。`python3 scripts/dev/check-spec-format.py` を現在の `specs/product/` に実行し、
  エラーが spec.md の「現状」の分断（引用 6、英語句 3。`overview.md` の「出発点となった要望」は対象外）だけであり、警告の件数が
  計測（行の幅 10、セルの幅 41、複数の文 34）と一致するかを確かめる。差があれば理由を research.md に追記する。

## Phase 3: User Story 65 - 形式のみの変更であることを確かめる (P1)

**Goal**: `scripts/dev/check-spec-equivalence.py BASE` が、本文の移動・追加・削除を一覧にし、合否を出す。

**Independent Test**: `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_equivalence.py"`（quickstart.md）。

- [X] T007 [P] [US65] `scripts/dev/tests/test_check_spec_equivalence.py` を作る（この時点では失敗することを確かめる）。一時ディレクトリに
  git のリポジトリを作り、スクリプトをコピーし、`specs/product/` の基準の版をコミットしてから作業ツリーを変えて実行する。次を確かめる。
  - 改行の位置・インデント・箇条書きの入れ子・句読点（`。`・`、`）だけの変更で、終了コード 0 と差分なしの表示（US65-AS1）
  - 表のセルの文を「表の詳細」へ移してセルを `下記` にした変更で、終了コード 0 と「移動」の表示（US65-AS2）
  - 語句の書き換え、文の追加、文の削除で、終了コード 1 と「追加」「削除」の表示（ファイルと行の番号を含む。US65-AS3）
  - コミットしていない変更と追跡していないファイルが比較に入る（US65-AS4）。ファイルの追加・削除と、ファイルの間の移動（EC-211）
  - 存在しない版の指定で終了コード 2（EC-212）
- [X] T008 [US65] `scripts/dev/check-spec-equivalence.py` を作る（contracts/cli.md、research.md の R11）。Python 3.9 で動く書き方にし、
  コメントは英語で書く。
- [X] T009 [US65] T007 のテストが通ることを確かめる。TAK-61 の差分で試す。作業ツリーを変えないため、スクラッチのディレクトリに
  このリポジトリを `git clone` して `f734a08` をチェックアウトし、その中のスクリプトで `b4e48eb` を基準に比べる。一覧が research.md の
  R11 の説明（移動と、`keyboard-and-menus.md` などの見出しの書き換え）と合うかを確かめ、結果を research.md に追記する。
- [X] T010 [US65] 全体の実行時間を計る（plan.md の Performance Goals: 30 秒以内）。超える場合は、research.md に理由と対策を書く。

## Phase 4: 既存の分断の修正（US64-AS1、SC-157、SC-160）

- [X] T011 Phase 2 と Phase 3 の成果（スクリプト・設定・テスト）をコミットする（`TAK-62: ...`）。
- [X] T012 形式の検査のエラーを、改行の位置だけを変えて直す（`contracts/settings.md`、`file-operations.md`、`window-layout.md`）。
  行の幅が 120 桁を超えないように改行の位置を選ぶ。
- [X] T013 `python3 scripts/dev/check-spec-format.py --update-baseline` で基準値を記録し、もう一度実行して成功することを確かめる（SC-157）。
  `python3 scripts/dev/check-spec-equivalence.py HEAD` が差分なしで成功することを確かめる（SC-160）。
- [X] T014 T012〜T013 をコミットする。

## Phase 5: User Story 66 - 書き方のルールを文書で確かめる (P2)

**Goal**: `specs/product/README.md` と `AGENTS.md` だけで、書き方のルールと検査の実行方法が分かる。

**Independent Test**: spec.md の US66-AS1、AS2 の問いに、2つの文書だけで答えられるかを読み比べる（SC-161）。

- [X] T015 [P] [US66] `specs/product/README.md` に節「書き方のルール」と「形式の検査」を足す（FR-306、research.md の R3〜R10）。
  書き方のルール（1項目1事項、子項目、表のセルと「表の詳細」、`下記` の対応づけ、途中で改行しないもの）、検査の実行方法、
  エラーと警告と基準値、表示幅の数え方、対象外の指定のしかた、equivalence チェックの使い方。追記後に形式の検査が成功することを確かめる。
- [X] T016 [P] [US66] `AGENTS.md` に【共通】の節「製品仕様の書き方」を足し、「運用の区分」の表に行を加える。要点（1項目1事項、
  表のセルは短く、途中で改行しない）と、詳細と検査の参照先（`specs/product/README.md`）だけを書く。ゲートへの組み込みは TAK-63 で行う旨を書く。
- [X] T017 T015〜T016 をコミットする。

## Phase 6: 検証と反映

- [ ] T018 Cloud の検証ゲートを行う（`AGENTS.md` の「Cloud Agent の作業」の「検証ゲート」）。`scripts/check-no-network.sh`、
  `scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、
  `scripts/dev/check-spec-ids.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"`、
  `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_*.py"`。
- [ ] T019 [MANUAL] 保守者のローカル（macOS の `python3`。Command Line Tools の 3.9 の場合を含む）で、
  `python3 scripts/dev/check-spec-format.py` と `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_spec_*.py"`
  が成功することを確かめてもらう。あわせて、マージ前の確認として起動スモーク（`scripts/make-app.sh` の後に
  `open .build/Folzio.app` で3ペインが表示されること）を依頼する。アプリのコードは変えないため、結果は変わらない見込み。
- [ ] T020 `specs/product/` への反映（plan.md の「反映の方針」）。`git merge origin/master` の後に `scripts/dev/check-spec-ids.sh` で
  ID の重複を確かめ、`overview.md` に節「製品仕様の形式の検査」を作って spec.md の「反映先」の項目を移す。反映後に形式の検査と
  ID の検査を実行する。spec.md の冒頭に凍結の注記を入れる。反映した項目と差分を保守者に示し、承認を得てからコミットする。
- [ ] T021 作業ブランチに push し、保守者に、PR を作成できる状態であること、検証の結果、確認していないことを報告する。
