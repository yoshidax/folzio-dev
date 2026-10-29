# リポジトリの構成と公開の手順

このリポジトリは非公開の開発用で、GitHub で公開するのは書き出した別のリポジトリだけにしている。
Spec Kit・AI エージェントの設定・仕様書・開発記録は公開しない。このドキュメントも公開版には含めない。

## 2つのリポジトリ

| | 開発用 | 公開用 |
|---|---|---|
| 場所 | `~/projects/folzio` | `~/projects/folzio-oss` |
| remote | なし | GitHub（push はユーザーが行う） |
| 管理対象 | すべてのファイル | アプリのソース・テスト・ビルド用スクリプト・README（英語の `README.md` と日本語の `README.ja.md`）・公開用ガイド（`docs/`）・LICENSE |
| 履歴 | 開発の履歴をそのまま残す | 1回の公開を1コミットにする |
| ブランチ | master と feature・bugfix などの作業ブランチ | main |

日々の開発・Spec Kit・worktree での並列実装は、すべて開発用で行う。公開用は手で編集しない。
内容を変えるときは開発用で直してから書き出す。

## ドキュメントの配置

- `docs/`: 公開用のユーザーガイド・開発ガイド。README からリンクし、公開用リポジトリにも書き出す
- `docs_private/`: 非公開の運用手順・用語集・開発記録。このファイルを含み、公開用リポジトリには書き出さない

## 公開版から外すファイル

`.gitattributes` の `export-ignore` で指定する。`git archive` がこの指定を読み、書き出しから外す。

| 対象 | 内容 |
|---|---|
| `.specify/` | Spec Kit 本体、憲章、拡張、workflow、バグ修正の記録（`.specify/bugs/`） |
| `.claude/` `.agents/` `.kilo/` `.codex/` | 各 AI エージェントの設定・スキル・コマンド |
| `specs/` | 仕様（`specs/product/`）と各 feature の記録 |
| `docs_private/` | 開発用のドキュメント（このファイルを含む） |
| `AGENTS.md` | エージェント向けのプロジェクト規約 |
| `scripts/sdd-*` `scripts/spec-restructure/` `scripts/tests/` | Spec Kit の自動実行とその検証 |
| `scripts/publish.sh` | 書き出しのスクリプト |
| `.vscode/` | エディタの個人設定 |
| `.gitattributes` | この指定そのもの |

開発専用のファイルやディレクトリを足したときは、`.gitattributes` にも追加する。
ルート直下以外の場所に置く開発専用のファイルは、個別に指定が要る。

公開版に出るファイルには、外したファイルへのリンクや参照を書かない（README・`.gitignore` を含む）。
Spec Kit の実行時ファイルの ignore 指定は、公開版の `.gitignore` ではなく `.specify/.gitignore` に置く。
ソースのコメントにある仕様の ID（`FR-xxx` など）や quickstart への言及は、公開版でも残している。

## 公開の手順

1. 開発用の master で、公開する変更をマージし終えておく。未コミットの変更があると書き出しは止まる
2. 書き出す

   ```bash
   cd ~/projects/folzio
   scripts/publish.sh
   ```

   `scripts/publish.sh` は次の順に行い、どれかが失敗するとそこで止まる。

   1. `scripts/check-readme-sync.sh` で、`README.md` と `README.ja.md` の構造がそろっているか確かめる
   2. `git archive HEAD` で、`export-ignore` を除いたファイルを一時ディレクトリへ取り出す
   3. 外したはずのファイルが混ざっていないか確かめる
   4. `$HOME` のパスとユーザー名が含まれていないか確かめる
   5. `../folzio-oss` へ同期する（`.git`、`.build`、`.vscode` を保護し、それ以外は書き出し内容に合わせる）。
      書き出し先がなければ `git init -b main` で作る
   6. 書き出し先で `swift build`、Core のテスト、性能テスト、`scripts/check-no-network.sh` を行う。
      テストは2つを順に流す（同時に流すと、Core の待ち時間のあるテストが CPU 不足で落ちることがある）
   7. `git add -A` で変更をステージし、`git status` を表示する

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

## 公開用リポジトリの方針

- 作者は `yoshidax <takehiko.yoshida.z@gmail.com>`（global の git 設定）
- ライセンスは MIT（`LICENSE`）
- 他の人の Issue は受け付けない。Fork・コードの利用・アプリの配布は MIT のもとで許可する
- 開発の履歴（作者情報・ローカルのパス・作業ブランチ）は公開しない。公開版には書き出した結果だけが残る

## 注意

- 公開用で直接コミットしない。次の書き出しで開発用の内容に置き換わる
- `.app` はアドホック署名（`codesign --sign -`）。配布物は Gatekeeper でブロックされるため、配布するなら
  Developer ID の署名と公証を行うか、開き方を README で案内する
- 公開版に出るファイルに `$HOME` の絶対パスを書かない。`scripts/publish.sh` の確認で止まる
- 公開前の全履歴は `~/projects/my_img_viewer-backup.bundle` にある（作者情報を書き換える前の状態）
