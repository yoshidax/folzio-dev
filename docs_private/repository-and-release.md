# リポジトリの構成と公開の手順

**適用範囲**: 【共通】（公開の手順は保守者が行う）

このリポジトリは開発用で、GitHub で公開している（`yoshidax/folzio-dev`。2026-11-06 に公開、TAK-80）。
アプリを配布する公開用リポジトリ（`yoshidax/folzio`）には、ここから書き出した、Spec Kit に縛られないプレーンな内容だけを置く。
Spec Kit・AI エージェントの設定・仕様書・開発記録は、公開用リポジトリへ書き出さない。このドキュメントも書き出さない。

## 2つのリポジトリ

| | 開発用 | 公開用 |
|---|---|---|
| 場所 | `~/projects/folzio` | `~/projects/folzio-oss` |
| remote | GitHub の公開リポジトリ `yoshidax/folzio-dev` | GitHub の公開リポジトリ `yoshidax/folzio`（push はユーザーが行う） |
| 管理対象 | すべてのファイル | アプリのソース・テスト・ビルド用スクリプト・README（英語の `README.md` と日本語の `README.ja.md`）・公開用ガイド（`docs/`）・LICENSE |
| 履歴 | 開発の履歴をそのまま残す | 1回の公開を1コミットにする |
| ブランチ | master と feature・bugfix などの作業ブランチ | main |

日々の開発・Spec Kit・worktree での並列実装は、すべて開発用で行う。公開用は手で編集しない。
内容を変えるときは開発用で直してから書き出す。

## 開発用 master へのマージ

`master` への統合は、ローカルの作業も含めて、すべて PR で行う（TAK-80）。ローカルでマージした `master` を直接 push する手順は使わない。
`master` のブランチ保護で拒否される（「開発用リポジトリの公開とブランチ保護」）。

1. 作業ブランチを開発用リポジトリへ push し、PR を作る。AI エージェントは、保守者の依頼があったときだけ PR を作る
2. PR の最新の head で CI（macOS Swift CI）が成功し、保守者がローカルで確認（起動スモークなど）してから、保守者が GitHub でスカッシュマージする。
   AI エージェントは PR をマージしない
3. ローカルの `master` は、`git switch master` と `git pull --ff-only` で更新する

Linear Issue に対応する変更をマージした後は、Issue の URL または ID と作業ブランチを添えて
エージェントに完了更新を依頼する。エージェントは変更が開発用 master に含まれることを確認してから
Issue を `Done` にする。これはマージや push に連動する自動更新ではない。

AI エージェントの `master` への push とマージは、`AGENTS.md`、権限設定、push の検査フック（`scripts/dev/check-git-push.py`）、
`master` のブランチ保護で止める。

## ドキュメントの配置

- `docs/`: 公開用のユーザーガイド・開発ガイド。README からリンクし、公開用リポジトリにも書き出す
- `docs_private/`: 運用手順・用語集・開発記録。このファイルを含み、公開用リポジトリには書き出さない（開発用リポジトリでは公開されている。
  名前の `private` は、公開用リポジトリへ書き出さないという意味）
- `shared-skills/`: Codex・Claude Code・Kilo Code で共有するスキルの手順本文。各ツールの `SKILL.md` から参照し、公開用リポジトリには書き出さない

## README の英語版と日本語版

`README.md`（英語）と `README.ja.md`（日本語）は同じ内容の2言語版。片方だけを更新しない。

- 一方を変えたら、同じコミットでもう一方にも同じ変更を入れる。タスクや指示が `README.md` だけを挙げていても両方を直す
- 見出し・箇条書き（入れ子の深さを含む）・表の行・コードブロックを1対1で対応させる。コードブロックは `#` 以降のコメントだけを訳す
- 英語版では、アプリの UI の文言を英訳し、探しやすくするために必要なところへ日本語の表示名を括弧で添える
- `scripts/check-readme-sync.sh [base]` で確かめる。base（既定は HEAD）との merge-base 以降の変更（未コミット・未追跡を含む）で、
  片方だけが変わっていないかと、2つの構造（見出し・箇条書き・表の行・コードブロック）が一致するかを調べる
  - 訳の中身が一致しているかまでは調べない。差分を読み、両方に同じ内容が入っていることを確かめる
- `scripts/dev/publish.sh` も書き出しの前に同じ確認を行う

## README の開発用リポジトリの注記

開発用リポジトリの `README.md` と `README.ja.md` には、言語の切り替えの行の後に、開発用リポジトリであることと公開用リポジトリへの
案内を書いた注記（`> [!NOTE]`）を置く。注記は、行の全体が `<!-- dev-repo-note:start -->` の行と `<!-- dev-repo-note:end -->`
の行で囲む。

- `scripts/dev/publish.sh` は、`scripts/dev/strip-readme-dev-note.sh` で、印の範囲と、終了の印の直後の空行 1 行を書き出しから除く。
  公開用リポジトリの README は、注記を置く前と同じ内容になる
- 印の対応が崩れている（開始だけ、終了だけ、逆順、入れ子、2 つ以上）か、印の文字列が行の一部に残ると、公開先へ同期する前に止まる
- 英語版と日本語版に、同じ形で注記を置く。引用と HTML コメントの行は `scripts/check-readme-sync.sh` の構造の比較の対象外なので、
  訳が一致しているかは差分を読んで確かめる
- 注記には、書き出さないファイル（`specs/` など）へのリンクを書かない

## 公開版から外すファイル

`.gitattributes` の `export-ignore` で指定する。`git archive` がこの指定を読み、書き出しから外す。

| 対象 | 内容 |
|---|---|
| `.specify/` | Spec Kit 本体、憲章、拡張、workflow、バグ修正の記録（`.specify/bugs/`） |
| `.claude/` `.agents/` `.kilo/` `.codex/` | 各 AI エージェントの設定・スキル・コマンド |
| `specs/` | 仕様（`specs/product/`）と各 feature の記録 |
| `docs_private/` | 開発用のドキュメント（このファイルを含む） |
| `shared-skills/` | 各 AI エージェントで共有するスキルの手順本文 |
| `AGENTS.md` | エージェント向けのプロジェクト規約 |
| `scripts/dev/` | 開発専用のスクリプト・補助ファイル・検証 |
| `.vscode/` | エディタの個人設定 |
| `.github/workflows/` | 開発用の GitHub Actions の workflow（「GitHub Actions の workflow」） |
| `.gitattributes` | この指定そのもの |

開発専用スクリプトとその補助ファイルは `scripts/dev/` に置く。その他の開発専用ファイルは `.gitattributes` で除外する。

公開版に出るファイルには、外したファイルへのリンクや参照を書かない（README・`.gitignore` を含む）。
Spec Kit の実行時ファイルの ignore 指定は、公開版の `.gitignore` ではなく `.specify/.gitignore` に置く。
ソースのコメントにある仕様の ID（`FR-xxx` など）や quickstart への言及は、公開版でも残している。

## 公開の手順

1. 開発用の master で、公開する変更をマージし終えておく。未コミットの変更があると書き出しは止まる
2. 書き出す

   ```bash
   cd ~/projects/folzio
   scripts/dev/publish.sh
   ```

   `scripts/dev/publish.sh` は次の順に行い、どれかが失敗するとそこで止まる。

   1. `scripts/check-readme-sync.sh` で、`README.md` と `README.ja.md` の構造がそろっているか確かめる
   2. `scripts/dev/check-english-comments.sh` で公開対象のソースコメントを検査する
   3. `git archive HEAD` で、`export-ignore` を除いたファイルを一時ディレクトリへ取り出す
   4. 一時ディレクトリの `README.md` と `README.ja.md` から、開発用リポジトリの注記を除く（「README の開発用リポジトリの注記」）
   5. 外したはずのファイル（開発用の `.github/workflows/` を含む）が混ざっていないか確かめる
   6. 公開用の workflow を `scripts/dev/oss-workflows/` から一時ディレクトリの `.github/workflows/` に置き、
      管理元と名前・内容が一致することを確かめる。置いた workflow の名前（なければ「公開用 workflow はありません」）を表示する
   7. `$HOME` のパスとユーザー名が含まれていないか確かめる（公開用の workflow も対象）
   8. `../folzio-oss` へ同期する（`.git`、`.build`、`.vscode` を保護し、それ以外は書き出し内容に合わせる）。
      書き出し先がなければ `git init -b main` で作る
   9. 書き出し先で `swift build`、Core と App を含む通常テスト、性能テスト、`scripts/check-no-network.sh` を順に行う。
      通常テストは非並列で実行し、性能テストは分けて流す（同時に流すと、Core の待ち時間のあるテストが CPU 不足で落ちることがある）。
      テストが失敗すると後続の検査とステージングを行わず終了する。同期はすでに行われているため、公開先には同期済みの未検証の変更が残る。確認せずにコミットしない。
      共有ランナーの負荷により性能テストの失敗を許容する CI と異なり、公開時は性能テストの失敗でも停止する
   10. `git add -A` で変更をステージし、`git status` を表示する

3. 書き出し先で起動スモークを行う（3ペインが表示されること）

   ```bash
   cd ~/projects/folzio-oss
   scripts/make-app.sh
   open .build/Folzio.app
   ```

4. ステージされた内容を確認してコミットし、push する

   ```bash
   cd ~/projects/folzio-oss
   git diff --cached --stat
   git commit -m "Release vX.Y"
   git push
   ```

   ソースだけの変更でも、必要に応じてこの手順で公開用リポジトリを更新する。アプリの配布物に
   影響しない変更（README やガイドのみの変更など）では、アプリのバージョンを上げず、
   GitHub Release の作成や配布物の再アップロードも行わない。

## GitHub Actions の workflow

開発用リポジトリと公開用リポジトリでは、動かす workflow が違う。どちらの元のファイルも開発用リポジトリで管理し、
公開用リポジトリでは workflow を直接編集しない（TAK-40）。

| | 開発用の workflow | 公開用の workflow |
|---|---|---|
| 元のファイル（管理元） | 開発用の `.github/workflows/` | 開発用の `scripts/dev/oss-workflows/`（直下の `*.yml`・`*.yaml`） |
| 動く場所 | 開発用リポジトリ（`yoshidax/folzio-dev`）だけ | 公開用リポジトリだけ |
| 書き出しでの扱い | 書き出さない（`.gitattributes` の `/.github/workflows export-ignore`） | 公開用リポジトリの `.github/workflows/` に、同じ名前・内容で置く |
| 例 | `macos-swift-ci.yml`（PR の作成時などのビルドとテスト） | TAK-41 のアプリのビルドと Release への添付（まだない） |

- 開発用の workflow を足すときは、開発用の `.github/workflows/` に置くだけでよい。ディレクトリごと除外しているので、除外の指定は要らない
- 公開用の workflow として置くのは、管理元の**直下**にある、名前が `.yml` または `.yaml` で終わる通常ファイルだけ。
  サブディレクトリの中、シンボリックリンク、説明の文書（管理元の `README.md`）は置かない
- 置くのはコミット済みの内容（`HEAD`）。管理元に workflow がなければ、公開用リポジトリに `.github/workflows/` を作らない
- 公開用の workflow は開発用リポジトリでは動かない（GitHub Actions は `.github/workflows/` の直下だけを読む）。動作は公開用リポジトリで確かめる
- 開発用と公開用で同じファイル名を使ってもよい。開発用の workflow は書き出さないので、公開用リポジトリでは衝突しない

公開用の workflow の追加・変更・削除の手順:

1. 開発用の作業ブランチで、`scripts/dev/oss-workflows/` の workflow を追加・変更・削除する
2. 開発用 master にマージする（「開発用 master へのマージとバックアップ」）
3. 「公開の手順」で書き出す。`publish.sh` の出力に、置いた workflow の名前が出る
4. 書き出し先の `git status` で `.github/workflows/` の変更（追加・変更・削除）を確かめてから、「公開の手順」の 4 でコミットする
5. 公開用リポジトリの Actions で、workflow が意図どおり動くことを確かめる

公開用リポジトリで `.github/workflows/` を直接編集した場合、その変更は次の書き出しで管理元の内容に置き換わる（`rsync --delete` は
`.github/workflows/` を保護しない）。公開用リポジトリでコミット済みのファイルは `git status` に削除（`D`）として出るが、
コミットしていないファイルは表示されずに消える。

## 開発用リポジトリの公開とブランチ保護

開発用リポジトリは 2026-11-06 に公開した（TAK-80）。公開前の点検（秘密情報・個人の情報・非公開のつもりだった運用情報）は
TAK-80 の Issue に記録した。コミット作者のメールアドレスと履歴は、そのまま公開している（履歴は書き換えない）。

公開リポジトリでは、macOS を含む GitHub の標準ランナーの使用は無料になる。そのため、CI は PR への push のたびに動かし、
その結果を `master` の必須チェックにする。

### `master` のブランチ保護（保守者が設定する）

PR の CI が 1 回動いた後に、Settings → Rules → Rulesets → New ruleset → New branch ruleset で、次の ruleset を作る。

| 項目 | 設定 |
|---|---|
| Ruleset name | `master` |
| Enforcement status | Active |
| Bypass list | なし（保守者を含めて適用する） |
| Target branches | Include default branch |
| Restrict deletions | 有効 |
| Block force pushes | 有効 |
| Require a pull request before merging | 有効。Required approvals は 0 |
| Require status checks to pass | 有効。`Build and test (macOS 15 / arm64)` を加える |

- 必須チェックは、名前を手で入力せず、「Add checks」の候補から、GitHub Actions のものを選ぶ。
  候補は最近動いたチェックから出るので、先に PR で CI を 1 回動かしておく
- 「Require branches to be up to date before merging」は使わない。`master` が進むたびに取り込みと CI の待ちが要るほどの並行はない。
  必要になれば有効にする
- 承認レビューを必須にしない。保守者は 1 人で、自分の PR を承認できない
- 例外（bypass）を置かないので、保守者もローカルから `master` へ直接 push できない。統合は PR で行う（「開発用 master へのマージ」）

設定した後に、次を確かめる。

1. CI が成功していない PR では、マージのボタンが使えない
2. CI が成功した自分の PR を、承認レビューなしでマージできる
3. ruleset の画面で、上の項目が有効で、bypass の対象がない

GitHub Free の公開リポジトリで rulesets が使えない場合は、Settings → Branches → Add branch protection rule（classic）で、
`master` に同じ項目（Require a pull request before merging、Require status checks to pass before merging、
Allow force pushes と Allow deletions は無効）を設定し、「Do not allow bypassing the above settings」を有効にする。
classic の保護は、既定では管理者に適用されない。

### 必須チェックを保つための注意

- 開発用の CI の workflow には、変更されたファイルなどによる実行の条件（`paths` など）を付けない。workflow 全体がスキップされると、
  必須チェックが Pending のまま残り、マージできなくなる
- 必須チェックにしているジョブの名前（`.github/workflows/macos-swift-ci.yml` の `Build and test (macOS 15 / arm64)`）を変える PR では、
  マージの前に、ruleset の必須チェックを新しい名前に替える。替えないと、保護が古い名前の結果を待ち続ける
- workflow のトークンは、読み取りの権限だけにする（`permissions: contents: read`）

### fork からの PR の workflow（保守者が設定する）

README の運用方針のとおり、外部からの貢献は受け付けていない。fork からの PR で workflow が勝手に動かないように、
Settings → Actions → General の「Approval for running fork pull request workflows from contributors」で、
「Require approval for all external contributors」を選ぶ（既定は、初めての貢献者だけ承認が要る）。

## 公開用リポジトリの方針

- 作者は `yoshidax <takehiko.yoshida.z@gmail.com>`（global の git 設定）
- ライセンスは MIT（`LICENSE`）
- 他の人の Issue は受け付けない。Fork・コードの利用・アプリの配布は MIT のもとで許可する
- 公開用リポジトリには、開発の履歴（作者情報・ローカルのパス・作業ブランチ）を含めない。書き出した結果だけが残る。
  開発の履歴は、開発用リポジトリで公開している

## 注意

- 公開用で直接コミットしない。次の書き出しで開発用の内容に置き換わる。GitHub Actions の workflow も同じ（「GitHub Actions の workflow」）
- `.app` はアドホック署名（`codesign --sign -`）。配布物は Gatekeeper でブロックされるため、配布するなら
  Developer ID の署名と公証を行うか、開き方を README で案内する
- 公開版に出るファイルに `$HOME` の絶対パスを書かない。`scripts/dev/publish.sh` の確認で止まる
- 公開前の全履歴は `~/projects/my_img_viewer-backup.bundle` にある（作者情報を書き換える前の状態）

## GitHub Releases の配布物

複数の feature を開発用 master にマージしてから一度だけ書き出し、1つの公開コミットと Release にまとめられる。
配布対象は macOS 15 以降の Apple silicon（arm64）のみ。Intel Mac は対象外。配布物は ad hoc 署名で、
Developer ID 署名と Apple 公証は行わない。

新しい配布物が必要な変更のときだけ、以下の手順でバージョンを更新して Release を作る。
ソースのみの更新では、既存の Release とそのタグ・配布物を維持する。

前提: Apple silicon Mac、Xcode の Swift ツールチェーン、Git、GitHub CLI と GitHub 認証。
`folzio-oss` の `origin` は公開先 GitHub リポジトリを指し、`main` のクリーンな HEAD を push 済みとする。
バージョンは `X.Y.Z`、ビルド番号は数字で指定する。

1. 上記の書き出しと公開用コミット・push をユーザーが行う。新たに開発した配布機能は、公開するソースに含める。
2. 開発用リポジトリから公開済みコミットを確認し、隔離ビルドと ZIP の検証を行う。

   ```bash
   cd ~/projects/folzio
   scripts/dev/release-distribution.sh prepare 1.2.3 12 OWNER/REPO
   ```

   必要に応じて最後に公開用リポジトリのパスを指定できる。出力は `.build/releases/v1.2.3/` にある。
   同じバージョンの出力が残っていると上書きせず停止する。失敗時の一時ファイルは削除される。
3. ZIP を展開し、ユーザーが Apple silicon Mac で起動して3ペインと日英表示を確認する。
   実際にダウンロードしたファイルで Gatekeeper の挙動を確認する場合は、その結果も記録する。
4. ユーザーが公開用コミットにタグを作成・push する。既存タグは再利用・上書きしない。

   ```bash
   cd ~/projects/folzio-oss
   git tag -a v1.2.3 -m "Folzio v1.2.3"
   git push origin v1.2.3
   ```

5. リリースノートをファイルに用意し、開発用リポジトリからドラフトを作る。

   ```bash
   cd ~/projects/folzio
   scripts/dev/release-distribution.sh draft 1.2.3 OWNER/REPO /path/to/release-notes.md
   ```

   ZIP と `SHA256SUMS` を添付する。公開済みタグとコミット、ZIP のチェックサム・アーキテクチャ・
   バージョン・署名を再確認する。ユーザーが GitHub でドラフトを確認してから公開する。
   失敗時はエラーと GitHub のドラフト状態を確認する。途中でドラフトが作られた場合は、GitHub 上で
   状態を確認して修復または削除してから再実行する。同名の Release を自動上書きしない。
