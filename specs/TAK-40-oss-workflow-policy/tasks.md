# Tasks: 開発用と公開用の workflow の管理

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、
[contracts/publish-workflows.md](contracts/publish-workflows.md)、[quickstart.md](quickstart.md)

テストは FR-294 が求めるので作る。US61 と US62 の変更は `scripts/dev/publish.sh` と `scripts/dev/tests/test_publish_folzio.py` の同じファイルに
集まるため、並列（`[P]`）にはしない。文書のタスク（US63）は別のファイルなので、互いに並列にできる。アプリのコード（`Sources/`、`Tests/`）、
`.github/workflows/macos-swift-ci.yml`、`README*.md`、`docs/` は変更しない。

## Phase 1: 準備

- [X] T001 `git fetch origin master` の後、`git merge-base --is-ancestor origin/master HEAD` で取り込み済みであることを確かめる。先に進んでいたら
  `git merge origin/master` で取り込む（履歴は書き換えない）。
- [X] T002 変更前の状態を記録する。`git archive HEAD | tar -t | grep -E '^\.github/workflows/'` に `macos-swift-ci.yml` が出ること、
  `python3 -I -m unittest discover -s scripts/dev/tests -p "test_publish_folzio.py"` の既存の 3 件が通ることを確かめる（`rsync` がなければ入れる）。

## Phase 2: 基盤（テストの土台。US61・US62 の前に行う）

- [X] T003 `scripts/dev/tests/test_publish_folzio.py` に、workflow のテスト用の土台を足す。既存の `exercise_publish` は変えずに、
  一時ディレクトリに開発用リポジトリ（`.gitattributes`・`scripts/dev/publish.sh` は実物をコピー、検査スクリプトと `swift` は偽物）と公開先を作り、
  ファイルの追加・削除・コミット・`publish.sh` の実行を何度でも行えるヘルパー（クラス）を作る。既存のテストと同じく、`publish.sh` は
  `cwd` を開発用リポジトリにして `bash` で実行し、結果（終了コード・出力）を返す。

## Phase 3: User Story 61 - 開発用の CI を公開から除く (P1) 🎯 MVP

**Goal**: 開発用の `.github/workflows/` が、個別の指定なしに書き出しから除かれ、除外の不備は同期の前に止まる。

**Independent Test**: quickstart.md の 1 の「開発用 workflow の除外」「除外設定の不備」と、2 の `git archive` の確認。

- [X] T004 [US61] `scripts/dev/tests/test_publish_folzio.py` にテストを足す（この時点では失敗することを確かめる）。
  (a) 開発用リポジトリの `.github/workflows/` に `macos-swift-ci.yml` と新しい名前の `lint.yml` を置いて書き出すと、公開先に `.github/workflows/`
  の項目がなく、`README.md` は置かれる（US61-AS1、AS2）。
  (b) `.gitattributes` から `/.github/workflows export-ignore` の行を消すと、非ゼロ終了し、標準エラーに `.gitattributes` を含み、
  公開先の既存のファイル（`obsolete.txt`）が残る（US61-AS3）。
- [X] T005 [US61] `.gitattributes` に `/.github/workflows        export-ignore` を追加する（既存の `/.github/pull_request_template.md` の行の前後。
  桁は既存の行にそろえる）。コメントで「開発用の workflow。公開用の workflow は scripts/dev/oss-workflows/ に置く」ことを示す。（FR-289、R1）
- [X] T006 [US61] `scripts/dev/publish.sh` の混入検査の正規表現に `^\./\.github/workflows(/|$)` を加える。メッセージは既存のまま
  （「書き出しに開発用のファイルが含まれています（.gitattributes を確認してください）」）。（FR-293 の前半、contracts の「除外」）
- [X] T007 [US61] T004 のテストと既存のテストが通ることを確かめる。`git archive HEAD | tar -t | grep -E '^\.github/workflows/'` が
  何も出さないことを確かめる（SC-153）。

## Phase 4: User Story 62 - 公開用の workflow を開発用リポジトリで管理して書き出す (P1)

**Goal**: `scripts/dev/oss-workflows/` の定義が、書き出しで公開先の `.github/workflows/` に置かれ、繰り返しの書き出しで管理元と一致する。

**Independent Test**: quickstart.md の 1 の「公開用 workflow の配置」「変更と削除」「定義がない」「同じ名前」。

- [X] T008 [US62] `scripts/dev/tests/test_publish_folzio.py` にテストを足す（この時点では失敗することを確かめる）。
  (a) 管理元に `release.yml`・`check.yaml`・`README.md`・`sub/nested.yml` を置いて書き出すと、公開先の `.github/workflows/` には
  `release.yml` と `check.yaml` だけが同じ内容で置かれる（US62-AS1、EC-204、EC-205）。標準出力に `release.yml` が示される。
  (b) 続けて `release.yml` を変更してコミットし書き出すと、公開先が新しい内容になる（US62-AS2）。
  (c) 続けて `release.yml` を削除してコミットし書き出すと、公開先から消え、`check.yaml` は残る（US62-AS3）。
  (d) 管理元に定義がなく、公開先に直接置いた `.github/workflows/manual.yml` があるとき、書き出すと公開先に `.github/` がない（US62-AS4、EC-203）。
  標準出力に「公開用 workflow はありません」が示される。
  (e) 開発用の `.github/workflows/release.yml` と管理元の `release.yml` の内容が違うとき、公開先には管理元の内容が置かれる（US62-AS5）。
  (f) 管理元の `link.yml` がシンボリックリンク（モード `120000`）のとき、公開先に置かれない（data-model.md の条件 2）。
- [X] T009 [US62] `scripts/dev/oss-workflows/README.md` を作る。この場所が公開用 workflow の管理元であること、直下の `*.yml`・`*.yaml` だけが
  書き出しで公開用リポジトリの `.github/workflows/` に置かれること、開発用リポジトリでは動かないこと、このファイル自体は書き出されないこと、
  方針の正本が `docs_private/repository-and-release.md` の「GitHub Actions の workflow」であることを書く。（FR-290）
- [X] T010 [US62] `scripts/dev/publish.sh` に公開用 workflow の配置を足す（contracts の「配置」「順序」）。
  - `git ls-tree -z HEAD -- scripts/dev/oss-workflows/` の各項目のうち、「種類が blob で、モードが通常ファイル（`100644` または `100755`）」かつ
    「名前が `.yml` または `.yaml` で終わる」ものだけを、`git cat-file blob <id>` で `$tmp/.github/workflows/<名前>` に書く。
    `.github/workflows/` は定義が 1 つ以上あるときだけ作る。（FR-291、R3）
  - 配置の後、`$tmp/.github/workflows/` のファイルの名前の集合と内容が、管理元の定義と一致しなければ、理由を標準エラーに出して非ゼロ終了する。
    （FR-293 の後半、R4）この確認は配置の誤りに備えるもので、正しい実装では失敗しない。失敗させる手段がないため、テストは足さない
  - 配置した定義の名前（定義がなければ「公開用 workflow はありません」）を標準出力に示す。
  - `$HOME`・ユーザー名の検査を、配置の後に移す（R4）。
  - ファイルの先頭のコメントに、公開用 workflow を置くことを 1 行加える。
- [X] T011 [US62] T008 のテストと、既存・T004 のテストがすべて通ることを確かめる。

## Phase 5: User Story 63 - workflow の管理の方針を文書で確かめる (P2)

**Goal**: 運用手順だけで、開発用・公開用の workflow の置き場所、更新の手順、書き出しでの扱いが分かる。

**Independent Test**: quickstart.md にはない。spec.md の US63-AS1、AS2 の問いに、`docs_private/repository-and-release.md` だけで答えられるかを読み比べる（SC-155）。

- [X] T012 [P] [US63] `docs_private/repository-and-release.md` を更新する。（FR-295）
  - 「公開版から外すファイル」の表に `.github/workflows/`（開発用の workflow）を加える
  - 「公開の手順」の `publish.sh` が行うことの一覧に、混入検査の対象の追加と、公開用 workflow の配置（と確認）を、実際の順序で加える
  - 新しい節「GitHub Actions の workflow」を置く。開発用と公開用の表（管理元、公開先での配置、動く場所、書き出しでの扱い）、
    公開用 workflow を追加・変更・削除する手順（管理元を編集 → 開発用 master にマージ → 書き出し → 公開先で確認・コミット・push）、
    公開用リポジトリで直接編集すると次の書き出しで消えること（EC-203）、管理元の条件（直下・通常ファイル・`.yml`/`.yaml`）、
    公開用 workflow は開発用リポジトリでは実行できず、動作の確認は公開用リポジトリで行うこと（A-183）、本体は TAK-41 で作ること（A-182）
  - 「注意」の「公開用で直接コミットしない」に、workflow も同じであることを加える
- [X] T013 [P] [US63] `docs_private/cloud-agent-workflow.md` の「4 CI の確認」の冒頭の段落の後に、`macos-swift-ci.yml` は開発用で公開用リポジトリには
  書き出さないこと、開発用の workflow は `.github/workflows/`、公開用の workflow は `scripts/dev/oss-workflows/` に置くこと
  （詳細は `repository-and-release.md` の「GitHub Actions の workflow」）を 1〜2 文で加える。
- [X] T014 [P] [US63] `AGENTS.md` の「公開用リポジトリ【共通】」に 1 行加える: 開発用の workflow は `.github/workflows/`（書き出さない）、
  公開用リポジトリだけで動かす workflow は `scripts/dev/oss-workflows/`（書き出しで `.github/workflows/` に置く）。詳細は
  `docs_private/repository-and-release.md`。

## Phase 6: 仕上げ

- [ ] T015 Cloud の検証ゲート（quickstart.md の 3）をすべて実行し、結果を記録する。あわせて `test_publish_folzio.py` の全件を実行する。
- [ ] T016 作業ブランチに push し、保守者に設計・実装の確認と、PR の作成の要否を尋ねる（PR は依頼があったときだけ作る）。
- [ ] T017 `specs/product/` へ反映する（PR の最後の作業）。直前に `git fetch origin master` と `git merge origin/master` で取り込み、
  `scripts/dev/check-spec-ids.sh` と master の最大値を突き合わせて ID の衝突を確かめる（衝突したら、この feature の ID を振り直す）。
  `specs/product/overview.md` に、spec.md の「反映先」の項目を、決定後の本文で加える（US は「ユーザーストーリー」、FR は「機能要件」の新しい小見出し
  「開発用と公開用の workflow」、EC・SC・A はそれぞれの節）。`specs/product/contracts/scripts.md` に、contracts の「除外」「配置」の要点を加える。
  `specs/product/README.md` の領域の表の overview.md の件数を更新する。反映後に `scripts/dev/check-spec-ids.sh` を再度実行する。
  反映した項目と差分を保守者に示し、承認を得てからコミットする。
- [ ] T018 反映の後、spec.md の冒頭に移行済み・凍結の注記を入れる（TAK-30 の spec.md と同じ形式）。
- [ ] T019 CI（PR の作成時の `macOS Swift CI`）の成否を確かめる（SC-156）。性能テストの結果はログの末尾で確かめる。
- [ ] T020 保守者に、ローカルでの確認を依頼する（quickstart.md の 5: macOS での公開のテスト、一時ディレクトリへの実際の書き出し、起動スモーク）。
  結果を受け取るまで、このタスクは未チェックのままにする。

## Dependencies & Execution Order

- Phase 1 → Phase 2 → Phase 3（US61）→ Phase 4（US62）: 同じ 2 つのファイルを変えるので順に行う。US62 のテスト (d) は、US61 の除外がないと
  開発用 workflow が混入して失敗するため、US61 の後に行う
- Phase 5（US63）: Phase 4 の後（実装の動作を文書に書くため）。T012〜T014 は互いに並列にできる
- Phase 6: T015 → T016 →（保守者の確認）→ T017 → T018 → T019 → T020。T017 の反映は PR の最後の作業

## Parallel Example: User Story 63

```text
T012 docs_private/repository-and-release.md
T013 docs_private/cloud-agent-workflow.md
T014 AGENTS.md
```

## Implementation Strategy

1. MVP: Phase 1〜3（US61）。これだけで TAK-40 の直接の目的（開発用 CI を公開しない）を満たす
2. US62 で、TAK-41 の前提（公開用 workflow の管理元と書き出し）を整える
3. US63 で、方針を文書にする
4. 仕上げで、検証・反映・保守者の確認を行う
