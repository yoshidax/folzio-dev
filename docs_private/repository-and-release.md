# リポジトリの構成と公開の手順

このリポジトリは非公開の開発用で、GitHub で公開するのは書き出した別のリポジトリだけにしている。
Spec Kit・AI エージェントの設定・仕様書・開発記録は公開しない。このドキュメントも公開版には含めない。

## 2つのリポジトリ

| | 開発用 | 公開用 |
|---|---|---|
| 場所 | `~/projects/folzio` | `~/projects/folzio-oss` |
| remote | GitHub の private リポジトリ `yoshidax/folzio-dev` | GitHub（push はユーザーが行う） |
| 管理対象 | すべてのファイル | アプリのソース・テスト・ビルド用スクリプト・README（英語の `README.md` と日本語の `README.ja.md`）・公開用ガイド（`docs/`）・LICENSE |
| 履歴 | 開発の履歴をそのまま残す | 1回の公開を1コミットにする |
| ブランチ | master と feature・bugfix などの作業ブランチ | main |

日々の開発・Spec Kit・worktree での並列実装は、すべて開発用で行う。公開用は手で編集しない。
内容を変えるときは開発用で直してから書き出す。

## 開発用 master へのマージとバックアップ

検証と確認を終えた作業ブランチは、ユーザーが開発用 master に切り替えてから次を実行する。
スクリプトは `origin/master` を取得して分岐を確認し、マージ後に private リポジトリへ push する。
AI エージェントはこのスクリプトを実行せず、master に直接マージしない。

```bash
cd ~/projects/folzio
git switch master
scripts/dev/merge-to-master.sh <作業ブランチ名>
```

競合した場合は解消して変更をステージし、`scripts/dev/merge-to-master.sh --continue` を実行する。
マージを取り消す場合は `git merge --abort` を使う。マージ後に push が失敗した場合は、
認証・ネットワーク・remote の状態を確認し、`scripts/dev/merge-to-master.sh --push-only` で再試行する。
remote が先に進んだ場合や履歴が分岐した場合は自動では統合せず、状態を確認してから対処する。
push が成功するまで GitHub へのバックアップは未完了である。

Linear Issue に対応する変更をマージした後は、Issue の URL または ID と作業ブランチを添えて
エージェントに完了更新を依頼する。エージェントは変更が開発用 master に含まれることを確認してから
Issue を `Done` にする。これはマージや push に連動する自動更新ではない。

この規則は同じ OS ユーザーで動く Agent を技術的に識別するアクセス制御ではない。
スクリプトを通らない直接の master 更新も自動的には push されない。

## ドキュメントの配置

- `docs/`: 公開用のユーザーガイド・開発ガイド。README からリンクし、公開用リポジトリにも書き出す
- `docs_private/`: 非公開の運用手順・用語集・開発記録。このファイルを含み、公開用リポジトリには書き出さない
- `shared-skills/`: Codex・Claude Code・Kilo Code で共有するスキルの手順本文。各ツールの `SKILL.md` から参照し、公開用リポジトリには書き出さない

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
   4. 外したはずのファイルが混ざっていないか確かめる
   5. `$HOME` のパスとユーザー名が含まれていないか確かめる
   6. `../folzio-oss` へ同期する（`.git`、`.build`、`.vscode` を保護し、それ以外は書き出し内容に合わせる）。
      書き出し先がなければ `git init -b main` で作る
   7. 書き出し先で `swift build`、Core のテスト、性能テスト、`scripts/check-no-network.sh` を行う。
      テストは2つを順に流す（同時に流すと、Core の待ち時間のあるテストが CPU 不足で落ちることがある）
   8. `git add -A` で変更をステージし、`git status` を表示する

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

## 公開用リポジトリの方針

- 作者は `yoshidax <takehiko.yoshida.z@gmail.com>`（global の git 設定）
- ライセンスは MIT（`LICENSE`）
- 他の人の Issue は受け付けない。Fork・コードの利用・アプリの配布は MIT のもとで許可する
- 開発の履歴（作者情報・ローカルのパス・作業ブランチ）は公開しない。公開版には書き出した結果だけが残る

## 注意

- 公開用で直接コミットしない。次の書き出しで開発用の内容に置き換わる
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
