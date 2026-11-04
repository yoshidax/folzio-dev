# Research: 開発用と公開用の workflow の管理

調査の基準: `origin/master` の `be9d576`（2026-11-03）。確認に使ったコマンドと結果は各項目に書く。

## R1 開発用 workflow を書き出しから除く方法

- **Decision**: `.gitattributes` に `/.github/workflows export-ignore` を追加し、ディレクトリごと除く。
- **Rationale**: FR-289 は「個別の除外設定なしに」除くことを求める。`/scripts/dev` と同じディレクトリ単位の指定にすれば、
  TAK-35 などで追加する開発用 workflow も自動で除かれる。一時リポジトリで `.github/workflows/ci.yml` と `new.yml` を置き、
  `git archive HEAD | tar -t` の出力が `.gitattributes` と `README.md` だけになることを確かめた（2026-11-03）。
- **Alternatives considered**:
  - `/.github/workflows/macos-swift-ci.yml export-ignore` のようにファイルごとに指定する: workflow を足すたびに指定が要り、
    漏れると公開される（FR-289 に反する）。
  - `/.github export-ignore` で `.github/` 全体を除く: PR テンプレート以外の `.github/` のファイル（将来の公開用の Issue テンプレートなど）
    の扱いまで変わる。この feature の範囲外（EC-206）。

## R2 公開用 workflow の管理元

- **Decision**: `scripts/dev/oss-workflows/` に置く。中身は公開用 workflow の定義（`*.yml`、`*.yaml`）と、管理元の説明の `README.md`。
- **Rationale**: 保守者の決定（spec.md の Clarifications）。`scripts/dev/` は既に `export-ignore` なので、管理元そのものは書き出されない（FR-177）。
  GitHub Actions は `.github/workflows/` 直下の定義だけを読むため、ここに置いた定義は開発用リポジトリでは動かない（FR-290）。
- **Alternatives considered**: 開発用の `.github/workflows/` に同居させてリポジトリ名の条件で止める案、公開用リポジトリで直接管理する案
  （spec.md の Clarifications に、採らない理由がある）。最上位の新しいディレクトリ（例: `oss/`）は、除外の指定を 1 行増やし、
  「開発専用のファイルは `scripts/dev/` に置く」という既存の規則（`docs_private/repository-and-release.md`）から外れるため採らない。

## R3 管理元から書き出しへ置く方法

- **Decision**: `publish.sh` が、`git archive` で取り出した後に、`git ls-tree -z HEAD -- scripts/dev/oss-workflows/` で管理元の直下の項目を列挙する。
  種類が `blob`、モードが通常ファイル（`100644`・`100755`）、名前が `.yml` または `.yaml` で終わるものだけを、
  `git cat-file blob <id>` で一時ディレクトリの `.github/workflows/<名前>` に書き出す。
- **Rationale**:
  - 書き出しの他の部分と同じく、作業ツリーではなく `HEAD` の内容を使う。`publish.sh` は未コミットの変更があると止まるが、
    `.gitignore` で無視されたファイルは `git status --porcelain` に出ないため、作業ツリーからコピーすると、無視されたファイルが混ざり得る。
  - `ls-tree` は直下の項目だけを返し、サブディレクトリは `tree` として区別できる（EC-205）。一時リポジトリで、`release.yml`（blob）、
    `README.md`（blob）、`sub`（tree）が区別されることを確かめた。
  - シンボリックリンク（モード `120000`）は、リンク先の内容ではなくパスの文字列が blob になるため、置かない。
  - `-z` で、名前に空白などがあっても区切りを誤らない。
- **Alternatives considered**:
  - `git archive HEAD scripts/dev/oss-workflows`: パスを指定しても `export-ignore` が効き、何も取り出せない（`scripts/dev` を除外しているため）。
  - 作業ツリーから `cp`: 上の無視されたファイルの問題がある。

## R4 混入検査と配置の確認

- **Decision**:
  1. 既存の混入検査（`find | grep -E`）の対象に `^\./\.github/workflows(/|$)` を加える。`git archive` の直後、配置の前に行うので、
     ここで見つかるものは開発用 workflow の混入である（FR-293 の前半）。
  2. 配置の後に、一時ディレクトリの `.github/workflows/` のファイルの名前の一覧と内容が、管理元の定義と一致することを確かめる（FR-293 の後半）。
  3. 既存の `$HOME`・ユーザー名の検査は、配置の後に行うように順序を変える。公開用 workflow も同じ検査の対象にする。
- **Rationale**: 既存の検査（FR-178）と同じ場所・同じ形で失敗させ、公開先の初期化・同期・ステージの前に止まる（`contracts/scripts.md`）。
- **Alternatives considered**: 公開先へ同期した後に確かめる: 同期の後では公開先が変わってしまう。

## R5 公開先での削除と上書き

- **Decision**: `rsync -a --delete` の除外（`/.git`、`/.build`、`/.vscode`）は変えない。
- **Rationale**: 公開先の `.github/workflows/` を保護しないので、管理元から消した workflow と、公開先に直接加えた workflow は、
  次の書き出しで消える（FR-292、EC-203）。管理元に定義がないときは、書き出しに `.github/` ができず、`--delete` で公開先の `.github/` も消える
  （US62-AS4）。消えたファイルは、`publish.sh` の最後の `git status --short` に削除（`D`）として表示される。
- **Alternatives considered**: 公開先の `.github/workflows/` を `--exclude` で保護する: 管理元からの削除が反映されず、管理元が 2 か所になる。

## R6 検証の方法

- **Decision**: `scripts/dev/tests/test_publish_folzio.py` に回帰テストを足す（FR-294）。既存のテストと同じく、一時ディレクトリに開発用リポジトリと
  公開先を作り、`swift` を偽物に置き換えて `publish.sh` を実行する。2 回の書き出し（管理元の変更・削除）は、間にコミットを挟んで確かめる。
- **Rationale**: 既存の FR-180 の検証と同じ枠組みで、Cloud（`rsync` を入れた Linux）でも、保守者のローカルでも動く。
  2026-11-03 の Cloud のセッションでは、`apt-get install rsync` の後に既存の 3 件が通った（A-186 の「実行できない場合がある」はこのため）。
- **Alternatives considered**: シェルの検査スクリプトを新しく作る: 既存の Python のテストで足りる（憲章 V）。

## R7 文書の更新先

- **Decision**:
  - `docs_private/repository-and-release.md`: 方針の正本。「GitHub Actions の workflow」の節を新設し、表（公開版から外すファイル）と
    公開の手順（`publish.sh` が行うこと）を更新する（FR-295）
  - `scripts/dev/oss-workflows/README.md`: 管理元の説明と、上の文書への参照
  - `docs_private/cloud-agent-workflow.md`: 4 章の CI の説明に、開発用 CI は書き出さないことと、workflow を足す場所を 1 文で加える
  - `AGENTS.md`: 「公開用リポジトリ」の節に 1 行加える（workflow の置き場所。詳細は上の文書）
  - `specs/product/contracts/scripts.md`: 書き出しの契約に、workflow の除外と配置を加える（反映の作業で行う）
- **Rationale**: 運用の詳細は `docs_private/` に置き、`AGENTS.md` には参照だけを置くという既存の分担に従う。

## R8 公開用の文書と README への影響

- **Decision**: `README.md`・`README.ja.md`・`docs/` は変えない。
- **Rationale**: 公開版の利用者向けの文書は、開発用 CI に触れていない（2026-11-03 に `grep -rniE "workflow|github actions|macos-swift" README.md README.ja.md docs/` が 0 件だったことを確かめた）。
  公開版の文書から `scripts/dev/` へのリンクも張らない（AGENTS.md の「公開用リポジトリ」）。
