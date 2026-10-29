# Folzio — Agent Notes

このリポジトリ固有のルールです。全体の原則はグローバルの `AGENTS.md` に従います。
仕様の正本は `specs/product/`（領域別の Living spec）、仕様の運用ルールは `.specify/memory/constitution.md` の「仕様の管理」です。
`specs/001-three-pane-media-viewer/` は凍結した実装の記録です。

## プロジェクト概要

- macOS 15 以降 / Swift 6 / AppKit のみ / 外部パッケージ依存なし / Swift Package 構成
- `FolzioCore` は AppKit を import しない。判断ロジックは Core、描画と入力は `FolzioApp` に置く
- デコード・ディレクトリ列挙・ファイル操作を UI スレッドで行わない
- `URLSession` / `Network` / `NWConnection` などのネットワーク API を使わない
- 新しい要件は新しい feature ディレクトリ（`specs/NNN-xxx/`）で扱い、実装と検証が終わってから変更点を `specs/product/` へ反映する
  （手順と ID の付け方は `specs/product/README.md`）
- 実装中に更新する仕様文書は、作業中の feature の `tasks.md` のチェックと、タスクで明示された追記（例: T077 の quickstart）だけにする
- 進捗は作業中の feature の `tasks.md` を正とする

## Issue 管理

- やりたいことやバグは Linear の [Folzio プロジェクト](https://linear.app/takyoshida/project/folzio-968b9d447da8)（チーム TAK）で管理する
- Linear Issue を指定して Spec Kit の feature またはバグ修正に着手するとき、対象を確認して `In Progress` に更新する。
  Issue の URL または ID を作成時の feature 仕様書またはバグの assessment に記録し、作業ブランチとともにユーザーに知らせる
- 詳細な実装タスクと進捗は引き続き feature の `tasks.md` を正とし、Linear に全タスクを複製しない
- ユーザーが master へのマージ後に完了更新を依頼したら、Issue の対象となる変更が開発用 master に含まれることを確認してから
  Issue を `Done` に更新する。マージや Linear の更新を確認できない場合は完了にせず、状況を報告する
- Linear に接続できない場合は失敗を報告し、状態を更新できたと扱わない。ユーザーの明示的な指示でない限り、
  `Done`、`Canceled`、`Duplicate` の Issue を自動的に再着手しない

## コードコメント（英語）

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

## Phase の検証ゲート

まとまった変更・Phase の終わりに、次をこの順で行います。

1. `swift build`
2. `swift test`
3. `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、
   `scripts/check-english-comments.sh`
4. 起動スモーク（3ペインが表示されること）
   - `scripts/make-app.sh`
   - `open .build/Folzio.app`
   - GUI の起動はユーザーに依頼する。依頼時は実行コマンドと確認ポイントを具体的に示す
5. 問題がなければ Phase 単位でコミットする

起動スモークを省略して「テストが通ったから完了」にしないこと。

## バグ修正

bug 拡張の `/speckit-bug-assess` → `/speckit-bug-fix` → `/speckit-bug-test` で直す（Kilo では `/speckit.bug.*`、Codex CLI では `$speckit-bug-*`）。
記録は `.specify/bugs/<slug>/` に残る。

1. クリーンな master から `bugfix/<slug>` ブランチを切る
2. assess: `assessment.md` の「Symptom」の後に「## 仕様との照合」を置き、該当する `specs/product/` の ID と、次のどちらかの判定を書く
   - 実装が仕様に反している: fix へ進む
   - 仕様が誤っている、または定めていない: fix へ進まず、仕様の変更として sdd-increment（小さければ `clarify_mode=skip`）で扱う
3. assess の判定と診断をユーザーに確認してもらってから fix へ進む
4. fix: 再現を固定する回帰テストを足す（Core のロジックは `Tests/FolzioCoreTests`）
5. test: 「Phase の検証ゲート」の 1〜4 を行う。GUI で再現を確かめていなければ判定は `partial` にする
6. ソースの変更と `.specify/bugs/<slug>/` を1つのコミットにする（例: `fix: <内容> (bug: <slug>)`）

## 起動しないときの初動（AppKit / macOS）

クラッシュレポートがなく、終了コードが 0 でも、AppKit が Objective-C 例外を握りつぶしていることがあります。
推測でコードを直す前に、まず lldb で例外を止めてください。GUI を起動するため、実行前にユーザーへ依頼します。

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

## AppKit UI の不変条件

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

## 並列実装（worktree 標準）

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

## Codex / Spec Kit

- Codex の Spec Kit スキルは `.agents/skills/`。CLI では `$speckit-specify`、`$speckit-plan`、
  `$speckit-tasks`、`$speckit-analyze`、`$speckit-implement`、`$speckit-converge` などで呼び出す
- 標準・git・bug スキルは Spec Kit が生成する。共通のプロジェクト規約はこのファイルで管理する
- Codex の自動実行は `scripts/sdd-run-codex.sh` を使う。run／resume／status と更新手順は
  `docs_private/codex-speckit.md` を参照する。既定の integration は Claude のままとする
- `.codex/config.toml` と `.codex/rules/` は Codex 用。Claude／Kilo の permissions 設定は Codex に適用されない
- `git push`、`git reset --hard`、`git clean` は行わない。sandbox・承認・ルールを無効化して作業を継続しない
- 開発用 master へのマージと push はユーザーが `scripts/merge-to-master.sh` で行う。
  AI エージェントはこのスクリプトを直接・間接に実行せず、master に直接マージしない
- GUI の起動はユーザーに依頼する。非対話実行中は GUI タスクを未チェックのまま残す
- Codex の初期ワークフローは順次実装する。内部 subagent による同じ作業ディレクトリでの並列編集は行わない。
  並列実装を明示的に行う場合も、上の worktree 規約に従って独立したセッションを使う

## テスト

- Swift Testing を使う（`Tests/FolzioCoreTests`、`Tests/FolzioPerformanceTests`）
- Core のロジックと異常系にはテストを付ける
- フィクスチャは `FixtureKit` で一時ディレクトリに生成し、テスト後に削除する
- 性能テストの基準値は `specs/001-three-pane-media-viewer/quickstart.md` の「性能の検証」に従う
- テストの失敗を3回直しても解決しない場合は、作業を止めて状況を報告する

## 検証用コマンド

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

## 公開用リポジトリ

- このリポジトリは非公開の開発用。公開用は `scripts/publish.sh` で `../folzio-oss` へ書き出し、1回の公開を1コミットにする
- `docs/` は公開用のユーザーガイド・開発ガイド、`docs_private/` は非公開の運用手順・開発記録に使う
- Spec Kit・AI エージェント・開発記録のファイルは `.gitattributes` の `export-ignore` で書き出しから外す。
  開発専用のファイルやディレクトリを足したら、`.gitattributes` にも追加する
- 公開版の README・ガイド・ソースのコメントから `specs/`・`.specify/`・`docs_private/`・`AGENTS.md` へのリンクを張らない
- 公開用リポジトリへのコミットと push はユーザーが行う
- 構成と公開の手順の詳細: `docs_private/repository-and-release.md`

## README の英語版と日本語版

- `README.md`（英語）と `README.ja.md`（日本語）は同じ内容の2言語版。片方だけを更新しない
  - 一方を変えたら、同じコミットでもう一方にも同じ変更を入れる。タスクや指示が `README.md` だけを挙げていても両方を直す
  - 見出し・箇条書き（入れ子の深さを含む）・表の行・コードブロックを1対1で対応させる。コードブロックは `#` 以降のコメントだけを訳す
  - 英語版では、アプリの UI の文言を英訳し、探しやすくするために必要なところへ日本語の表示名を括弧で添える
- `scripts/check-readme-sync.sh [base]` で確かめる（Phase の検証ゲート 3）。base（既定は HEAD）との merge-base 以降の変更（未コミット・未追跡を含む）で
  片方だけが変わっていないかと、2つの構造（見出し・箇条書き・表の行・コードブロック）が一致するかを調べる
  - 訳の中身が一致しているかまでは調べない。差分を読み、両方に同じ内容が入っていることを確かめる
- `scripts/publish.sh` も書き出しの前に同じ確認を行う

## 参照

- 起動不具合の詳細な振り返り: `docs_private/retrospective/2026-10-19-startup-debugging.md`
- リポジトリの構成と公開の手順: `docs_private/repository-and-release.md`
- 使い方・手動確認: `README.md`（日本語版は `README.ja.md`）
- 検証手順: `specs/001-three-pane-media-viewer/quickstart.md`
