# Folzio — Agent Notes

このリポジトリ固有のルールです。全体の原則はグローバルの `AGENTS.md` に従います。
仕様の正本は `specs/product/`（領域別の Living spec）、仕様の運用ルールは `.specify/memory/constitution.md` の「仕様の管理」です。
`specs/001-three-pane-media-viewer/` は凍結した実装の記録です。

## プロジェクト概要【共通】

- macOS 15 以降 / Swift 6 / AppKit のみ / 外部パッケージ依存なし / Swift Package 構成
- `FolzioCore` は AppKit を import しない。判断ロジックは Core、描画と入力は `FolzioApp` に置く
- デコード・ディレクトリ列挙・ファイル操作を UI スレッドで行わない
- `URLSession` / `Network` / `NWConnection` などのネットワーク API を使わない
- 新しい要件は新しい feature ディレクトリ（`specs/NNN-xxx/`）で扱い、実装と検証が終わってから変更点を `specs/product/` へ反映する
  （手順と ID の付け方は `specs/product/README.md`）
- 実装中に更新する仕様文書は、作業中の feature の `tasks.md` のチェックと、タスクで明示された追記（例: T077 の quickstart）だけにする
- 進捗は作業中の feature の `tasks.md` を正とする

## 運用の区分

このファイルの規則は、作業のしかたによって適用される範囲が違います。各節の見出しの【】が、その節の適用範囲を示します。

- 【共通】: ローカルでも Cloud でも適用する
- 【ローカル】: 保守者のローカル（macOS）でのセッションにだけ適用する。Cloud では適用しない
- 【Cloud】: Cloud 環境（リモート実行環境）でのセッションにだけ適用する。ローカルでは適用しない

Cloud のセッションかどうかは、セッションの指示（Cloud が作業ブランチを指定している、リモート実行環境である旨）で判断します。
Cloud Agent の手順の詳細は [docs_private/cloud-agent-workflow.md](docs_private/cloud-agent-workflow.md) にあります。

| 節 | 区分 | 補足 |
|---|---|---|
| プロジェクト概要 | 共通 | |
| Issue 管理 | 共通 | PR を作った後の Linear の更新は「Cloud Agent の作業」 |
| Git の規則 | 共通 | `git push`、master へのマージ、GUI の起動の依頼 |
| コードコメント（英語） | 共通 | |
| Phase の検証ゲート | ローカル | Cloud 版は「Cloud Agent の作業」の「検証ゲート」 |
| バグ修正 | 共通 | 手順 1 と 5 は、ローカルと Cloud で違う（注記あり） |
| 起動しないときの初動（AppKit / macOS） | ローカル | Cloud では保守者に依頼する |
| AppKit UI の不変条件 | 共通 | |
| 並列実装（worktree 標準） | ローカル | Cloud は Issue 単位で別のセッションが並行する |
| Codex / Spec Kit | 共通 | スキルの場所と設定 |
| Codex の自動実行 | ローカル | `scripts/dev/sdd-run-codex.sh` による実行 |
| Cloud Agent の作業 | Cloud | feature の始め方、Linear、PR、CI、検証ゲート、並行する作業 |
| テスト | 共通 | Cloud ではテストを CI で実行する |
| 検証用コマンド | 共通 | Cloud では `swift` を使うコマンドを実行できない |
| 公開用リポジトリ | 共通 | |
| README の英語版と日本語版 | 共通 | |
| 参照 | 共通 | |

## Issue 管理【共通】

- やりたいことやバグは Linear の [Folzio プロジェクト](https://linear.app/takyoshida/project/folzio-968b9d447da8)（チーム TAK）で管理する
- Linear Issue を指定して Spec Kit の feature またはバグ修正に着手するとき、対象を確認して `In Progress` に更新する。
  Issue の URL または ID を作成時の feature 仕様書またはバグの assessment に記録し、作業ブランチとともにユーザーに知らせる
- 詳細な実装タスクと進捗は引き続き feature の `tasks.md` を正とし、Linear に全タスクを複製しない
- ユーザーが master へのマージ後に完了更新を依頼したら、Issue の対象となる変更が開発用 master に含まれることを確認してから
  Issue を `Done` に更新する。マージや Linear の更新を確認できない場合は完了にせず、状況を報告する
- Linear に接続できない場合は失敗を報告し、状態を更新できたと扱わない。ユーザーの明示的な指示でない限り、
  `Done`、`Canceled`、`Duplicate` の Issue を自動的に再着手しない

## Git の規則【共通】

- `git push` は作業ブランチ（`claude/*`、`ci/*`、`chore/*`、`docs/*`、`feature/*`、`bugfix/*`、`agent/*`）への
  push だけを行う。`master` / `main` への push、強制 push（`--force`、`-f`、`+` 付きの refspec）、
  リモートブランチの削除は行わない。PR のマージはユーザーだけが行い、GitHub MCP ツールでも行わない
- `git reset --hard`、`git clean` は行わない。sandbox・承認・ルールを無効化して作業を継続しない
- 開発用 master へのマージと push はユーザーが `scripts/dev/merge-to-master.sh` で行う。
  AI エージェントはこのスクリプトを直接・間接に実行せず、master に直接マージしない
- GUI の起動はユーザーに依頼する。非対話実行中は GUI タスクを未チェックのまま残す

## コードコメント（英語）【共通】

OSS として配布するため、ソースコードのコメントは英語で書きます。日本語のコメントが残っているファイルは、
コード・識別子・文字列リテラルを変えずにコメントだけを翻訳します。

- doc comment（`///`）は Apple の API ドキュメントの慣例に合わせ、三人称単数・現在形で書く
  （例: `Inflates ... and returns ...`）。同じコメント内で命令形と三人称を混ぜない
- Boolean の値・プロパティの説明は `Whether ...` で始める
- コメントは1行100〜120文字程度で折り返す。長い文は文単位で改行してよい
- 用語は次に揃える
  - 展開 / 圧縮: inflate / deflate（`zip` は小文字、`ZIP64` は大文字）
  - zip の項目: entry
  - 圧縮データ: compressed data
  - スレッド安全でない: not thread-safe
  - 先頭から展開し直す: inflate again from the beginning
- 型名・関数名・引数名・`FR-*` や `research.md` の R 番号などの ID は翻訳しない
- 翻訳後もコメントのみの変更でも `swift build` と `swift test` を実行する
- 基準とする書式の例: `Sources/FolzioCore/Archive/InflateCursor.swift`

## Phase の検証ゲート【ローカル】

まとまった変更・Phase の終わりに、次をこの順で行います。Cloud 版は「Cloud Agent の作業」の「検証ゲート」を参照します。

1. `swift build`
2. `swift test`
3. `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、
   `scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`
4. 起動スモーク（3ペインが表示されること）
   - `scripts/make-app.sh`
   - `open .build/Folzio.app`
   - GUI の起動はユーザーに依頼する。依頼時は実行コマンドと確認ポイントを具体的に示す
5. 問題がなければ Phase 単位でコミットする

起動スモークを省略して「テストが通ったから完了」にしないこと。

## バグ修正【共通】

bug 拡張の `/speckit-bug-assess` → `/speckit-bug-fix` → `/speckit-bug-test` で直す（Kilo では `/speckit.bug.*`、Codex CLI では `$speckit-bug-*`）。
記録は `.specify/bugs/<slug>/` に残る。

1. クリーンな master から `bugfix/<slug>` ブランチを切る（ローカル。Cloud では Cloud が指定した作業ブランチをそのまま使う）
2. assess: `assessment.md` の「Symptom」の後に「## 仕様との照合」を置き、該当する `specs/product/` の ID と、次のどちらかの判定を書く
   - 実装が仕様に反している: fix へ進む
   - 仕様が誤っている、または定めていない: fix へ進まず、仕様の変更として sdd-increment（小さければ `clarify_mode=skip`）で扱う
3. assess の判定と診断をユーザーに確認してもらってから fix へ進む
4. fix: 再現を固定する回帰テストを足す（Core のロジックは `Tests/FolzioCoreTests`）
5. test: 「Phase の検証ゲート」の 1〜4 を行う（Cloud では、ビルドとテストを CI で確認し、起動スモークを保守者に依頼する。
   「Cloud Agent の作業」の「検証ゲート」）。GUI で再現を確かめていなければ判定は `partial` にする
6. ソースの変更と `.specify/bugs/<slug>/` を1つのコミットにする（例: `fix: <内容> (bug: <slug>)`）

## 起動しないときの初動（AppKit / macOS）【ローカル】

クラッシュレポートがなく、終了コードが 0 でも、AppKit が Objective-C 例外を握りつぶしていることがあります。
推測でコードを直す前に、まず lldb で例外を止めてください。GUI を起動するため、実行前にユーザーへ依頼します。
Cloud では GUI を起動できないため、実行する内容と確認する点を示して、保守者に依頼します。

```bash
cd /Users/igachan/projects/folzio
lldb -b \
  -o 'breakpoint set -E objc' \
  -o 'run' \
  -o 'bt 30' \
  -o 'po $x0' \
  -o 'quit' \
  -- .build/Folzio.app/Contents/MacOS/Folzio
```

- 例外を1つ直したら、ユーザーに GUI 確認を戻さず、もう一度 lldb を実行して次の例外を確認する
- 例外がなくなり、ウインドウが表示されてから、ユーザーに視覚確認を依頼する
- 古いプロセスが残っていないか `pgrep -fl Folzio` で確認する
- ターミナルから直接実行すると、起動時の出力を確認できる
  （`.build/Folzio.app/Contents/MacOS/Folzio`）

## AppKit UI の不変条件【共通】

- `NSSplitViewController` では、次の `NSSplitViewDelegate` メソッドを override しない
  - `splitView(_:constrainMinCoordinate:ofSubviewAt:)`
  - `splitView(_:constrainMaxCoordinate:ofSubviewAt:)`
  - `splitView(_:shouldCollapseSubview:forDoubleClickOnDividerAt:)`
  - Auto Layout 使用時は起動時に例外になる
- ペインの最小幅は `NSSplitViewItem.minimumThickness`（160 / 240 / 320pt）で守る
- 通常時は `canCollapse = false`。フルスクリーンとペインの表示切り替えで隠すペインだけ `canCollapse = true` にしてから `isCollapsed` を設定する
- 制約は必ず対象ビューを `addSubview` した後に有効化する
- 異なる view hierarchy に属するアンカー同士を制約しない
- ウインドウの表示・contentViewController の設定は MainActor で行う

## 並列実装（worktree 標準）【ローカル】

この規約はローカル用です。Cloud では、別の Issue を別のセッションが並行して担当し、サブエージェントによるタスク分割の並列実装は行いません。

- 実装の並列化は、Agent Manager の worktree セッション、またはタスク専用の `git worktree` で行う
- ベースは現在の Phase ブランチ（例: `001-three-pane-media-viewer`）。未コミット変更は先にコミットまたは stash する
- ブランチ名は `agent/<task-id>-<slug>`（例: `agent/T043-video-preview`）
- エージェントは自分の worktree 内だけを編集し、小さなコミットを残して SHA を報告する。ベースへマージしない
- 同じファイルを触るタスクは worktree でも並列化せず、依存順に直列化する
- インテグレータが Phase ブランチへ `git merge --no-ff`（または cherry-pick）で統合し、各マージ後に
  `swift build` / `swift test` を実行する
- UI の起動スモークは同時に複数 worktree で行わない。統合後に1つずつ確認する
- 内部の `task` サブエージェントは調査・レビュー向け。実装の並列化には使わない
- マージ後に `git worktree remove` と作業ブランチの削除を行う

## Codex / Spec Kit【共通】

- Codex の Spec Kit スキルは `.agents/skills/`。CLI では `$speckit-specify`、`$speckit-plan`、
  `$speckit-tasks`、`$speckit-analyze`、`$speckit-implement`、`$speckit-converge` などで呼び出す
- 標準・git・bug スキルは Spec Kit が生成する。共通のプロジェクト規約はこのファイルで管理する
- 手書きの `folzio-*` スキルは、手順の本文を `docs_private/<スキル名>.md` に置く。`.agents/skills/` と `.claude/skills/` の
  `SKILL.md` には、`name`、`description`（両方で同じ内容）、本文を読む指示、各ツール固有の注意だけを書く。
  一致は `scripts/dev/check-skill-sync.sh` で確かめる
- `.codex/config.toml` と `.codex/rules/` は Codex 用。Claude／Kilo の permissions 設定は Codex に適用されない

## Codex の自動実行【ローカル】

- Codex の自動実行は `scripts/dev/sdd-run-codex.sh` を使う。run／resume／status と更新手順は
  `docs_private/codex-speckit.md` を参照する。既定の integration は Claude のままとする
- Codex の初期ワークフローは順次実装する。内部 subagent による同じ作業ディレクトリでの並列編集は行わない。
  並列実装を明示的に行う場合も、上の worktree 規約に従って独立したセッションを使う

## Cloud Agent の作業【Cloud】

Cloud 環境で Agent が作業するときの規則です。手順の詳細は [docs_private/cloud-agent-workflow.md](docs_private/cloud-agent-workflow.md)
（括弧内の番号は、その章）にあります。ローカルで作業するときは適用しません。

### feature の始め方（手順書 1）

- Cloud が指定した作業ブランチ上で作業する。git 拡張の `before_specify` フック（`speckit.git.feature`）は実行せず、feature 用のブランチを新しく作らない
- feature ディレクトリは `specs/TAK-<nn>-<slug>`（`<nn>` は Linear の Issue 番号）。`SPECIFY_FEATURE_DIRECTORY` で明示する。ブランチ名とは独立している
- 作業の前に `git fetch origin master` し、最新の master を取り込む（ローカルの `master` ブランチは古いことがある）

### Linear（手順書 2）

- 着手時に `In Progress` へ更新し、Issue の URL を仕様書に記録する（「Issue 管理」）
- Linear の GitHub 連携は PR を検知しない。PR を作った後は、Agent が Issue に PR のリンクを追加して `In Review` に更新する
- `Done` は、保守者がマージ後に依頼したときだけ、マージを確認して更新する

### PR とマージ、ブランチ（手順書 3、6）

- PR は、保守者が依頼したときだけ作る。作業が終わっても、依頼なしには作らず、作成できる状態であることを報告する
- マージは保守者だけが行う。マージ済みの作業ブランチは再利用せず、最新の master から新しい `claude/` のブランチを作る
  （Cloud が指定した名前と別の名前は、保守者の許可を得る）
- 作業の途中で master が先に進んだら、`git merge origin/master` で取り込む。履歴を書き換えない
- 権限の設定（`.claude/settings.json`）はセッションの起動時に読み込まれる。途中の変更は、新しいセッションまで反映されない

### CI の確認（手順書 4）

- Cloud には Swift がないため、ビルドとテストは macOS の CI で確認する。CI は PR の作成時と Ready にしたときだけ自動で動く
- 結果とログは GitHub MCP で読む。実行中のジョブのログは取得できない。修正は、ログを読んでまとめてから push する
- 置き換える API は、使う前にヘッダーや文書で存在を確認する。同じ原因の失敗を 3 回直しても解決しない場合は、作業を止めて報告する
- 追加の push の後は、`workflow_dispatch` で再確認する（Agent が起動できなければ、保守者に実行を頼む）

### 検証ゲート（手順書 5）

- Cloud で行う: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、
  `scripts/dev/check-skill-sync.sh`、`test_check_git_push.py`
- CI で行う: `swift build`、`swift test`
- 保守者がローカルで行う: 起動スモーク、ローカルの最新の Swift でのビルド、`scripts/dev/tests` の公開・配布のテスト
- 起動スモークを省略して「CI が通ったから完了」にしない。マージ前のゲート（自動テストの通過）は、CI の成功と保守者のローカルでの確認で満たす

### 並行する作業と `specs/product/` の反映（手順書 7）

- 並列の単位は Issue。サブエージェントによるタスク分割の並列実装は行わない
- `specs/product/` への反映は PR の最後の作業にする。反映の直前に master を取り込み、同じ領域ファイルの競合は解消する
- `specs/product/` の ID が別の feature と衝突したら、まだマージされていない側が自分の feature の ID を振り直してから反映する。
  マージ済みの ID は振り直さない

## テスト【共通】

- Swift Testing を使う（`Tests/FolzioCoreTests`、`Tests/FolzioPerformanceTests`）
- Core のロジックと異常系にはテストを付ける
- フィクスチャは `FixtureKit` で一時ディレクトリに生成し、テスト後に削除する
- 性能テストの基準値は `specs/001-three-pane-media-viewer/quickstart.md` の「性能の検証」に従う
- テストの失敗を3回直しても解決しない場合は、作業を止めて状況を報告する
- Cloud では `swift test` を実行できないため、CI で実行する（「Cloud Agent の作業」の「CI の確認」）

## 検証用コマンド【共通】

```bash
swift build
swift test
swift test --filter FolzioCoreTests
swift test --filter FolzioPerformanceTests
scripts/check-no-network.sh
scripts/check-readme-sync.sh master
scripts/make-fixtures.sh ~/FolzioFixtures
scripts/make-app.sh
open .build/Folzio.app
```

- `scripts/make-fixtures.sh` は WebP 生成に `cwebp` / `img2webp` を使う。導入はユーザーに確認する
- `.app` と `swift run` では UserDefaults のドメインが異なる
  - `.app`: `local.folzio.Folzio`
  - `swift run`: `FolzioApp`
- Cloud では、`swift` を使うコマンドと `scripts/make-app.sh`、`open` を実行できない。ビルドとテストは CI で確認し、GUI は保守者に依頼する

## 公開用リポジトリ【共通】

- このリポジトリは非公開の開発用。公開用は `scripts/dev/publish.sh` で `../folzio-oss` へ書き出し、1回の公開を1コミットにする
- `docs/` は公開用のユーザーガイド・開発ガイド、`docs_private/` は非公開の運用手順・開発記録に使う
- Spec Kit・AI エージェント・開発記録のファイルは `.gitattributes` の `export-ignore` で書き出しから外す。
  開発専用スクリプトと補助ファイルは `scripts/dev/` に置く。その他の開発専用ファイルは `.gitattributes` で除外する
- 公開版の README・ガイド・ソースのコメントから `specs/`・`.specify/`・`docs_private/`・`AGENTS.md` へのリンクを張らない
- 公開用リポジトリへのコミットと push はユーザーが行う
- 構成と公開の手順の詳細: `docs_private/repository-and-release.md`

## README の英語版と日本語版【共通】

- `README.md`（英語）と `README.ja.md`（日本語）は同じ内容の2言語版。片方だけを更新しない
  - 一方を変えたら、同じコミットでもう一方にも同じ変更を入れる。タスクや指示が `README.md` だけを挙げていても両方を直す
  - 見出し・箇条書き（入れ子の深さを含む）・表の行・コードブロックを1対1で対応させる。コードブロックは `#` 以降のコメントだけを訳す
  - 英語版では、アプリの UI の文言を英訳し、探しやすくするために必要なところへ日本語の表示名を括弧で添える
- `scripts/check-readme-sync.sh [base]` で確かめる（Phase の検証ゲート 3）。base（既定は HEAD）との merge-base 以降の変更（未コミット・未追跡を含む）で
  片方だけが変わっていないかと、2つの構造（見出し・箇条書き・表の行・コードブロック）が一致するかを調べる
  - 訳の中身が一致しているかまでは調べない。差分を読み、両方に同じ内容が入っていることを確かめる
- `scripts/dev/publish.sh` も書き出しの前に同じ確認を行う

## 参照【共通】

- 起動不具合の詳細な振り返り: `docs_private/retrospective/2026-10-19-startup-debugging.md`
- リポジトリの構成と公開の手順: `docs_private/repository-and-release.md`
- 使い方・手動確認: `README.md`（日本語版は `README.ja.md`）
- 検証手順: `specs/001-three-pane-media-viewer/quickstart.md`
- Cloud Agent の作業手順: `docs_private/cloud-agent-workflow.md`
