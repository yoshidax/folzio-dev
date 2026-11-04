# Folzio — Agent Notes

見出しの【】は適用範囲: 【共通】はローカルと Cloud、【ローカル】は保守者の macOS、【Cloud】はリモート実行環境（Cloud が作業ブランチを指定している）。
仕様の正本は `specs/product/`、運用は `.specify/memory/constitution.md` の「仕様の管理」。完了した feature ディレクトリ（`specs/NNN-*`・`specs/TAK-*`）は凍結した記録で、更新しない。

## 設計の制約【共通】
- 判断ロジックは `FolzioCore`（AppKit を import しない）、描画と入力は `FolzioApp` に置く
- デコード・ディレクトリ列挙・ファイル操作を UI スレッドで行わない。ネットワーク API を使わない（オフライン動作）

## 仕様と進捗【共通】
- 新しい要件は新しい feature ディレクトリで扱い、実装と検証の後に `specs/product/` へ反映する（手順と ID: `specs/product/README.md`）
- 実装中に更新する仕様文書は、今の feature の `tasks.md` のチェックと、タスクが明示した追記だけ。進捗は `tasks.md` を正とする
- `specs/product/` の書き方の要点（詳細と検査は `specs/product/README.md` の「書き方のルール」「形式の検査」）
  - 1つの箇条書きに1つの要件・条件・例外を書き、条件と例外は子項目に分ける
  - 表のセルは短い要約にし、詳細は表の直後の「表の詳細」に書いて、セルには `下記` と書く
  - インラインコード・引用・英語の語句・表の行を、途中で改行しない
- `specs/product/` を変えたら `python3 scripts/dev/check-spec-format.py` を、反映の前と後に `scripts/dev/check-spec-ids.sh` を実行する。ID が衝突したら `docs_private/cloud-agent-workflow.md` の 7 章に従う

## Git と GitHub【共通】
- push は default ブランチ（`master`）以外の作業ブランチへだけ行う。強制 push・リモートブランチの削除・履歴の書き換えはしない
- PR は保守者の依頼があったときだけ作る。PR のマージと `master` への統合（`scripts/dev/merge-to-master.sh`）は保守者が行う
- CI の起動・再実行（`workflow_dispatch`、rerun）は、毎回、理由と対象ブランチを示して保守者の許可を得る（macOS の使用時間を消費する）
- Linear の Issue に着手するとき、PR を作った後、完了を更新するときは `docs_private/agents/linear.md` に従う

## AppKit UI の不変条件【共通】（起動不能の事故から）
- `NSSplitViewController` で `splitView(_:constrainMinCoordinate:ofSubviewAt:)`・`splitView(_:constrainMaxCoordinate:ofSubviewAt:)`・`splitView(_:shouldCollapseSubview:forDoubleClickOnDividerAt:)` を override しない（Auto Layout と両立せず、起動時に例外になる）
- ペインの最小幅は `NSSplitViewItem.minimumThickness` で守る。`canCollapse` は通常 `false`、隠すペインだけ `true` にしてから `isCollapsed` を設定する
- 制約は、対象ビューを `addSubview` した後に有効化する。異なる view hierarchy のアンカー同士を制約しない
- ウインドウの表示と `contentViewController` の設定は MainActor で行う

## Phase の検証ゲート【ローカル】
まとまった変更・Phase の終わりに、1 `swift build`、2 `swift test`、3 `scripts/dev/check-all.sh`、4 起動スモーク（`scripts/make-app.sh` → `open .build/Folzio.app` で 3 ペインが表示される）をこの順で行い、5 問題がなければ Phase 単位でコミットする。Cloud 版は `docs_private/cloud-agent-workflow.md` の 5 章。

## 完了の条件【共通】
- テストや CI が通っただけで完了にしない。起動スモークまで行う。GUI の起動は保守者に依頼して実行するコマンドと確認する点を示し、確認されるまで GUI のタスクは未チェックで残す（Cloud では build と test も CI で確かめる）
- 同じ原因の失敗を 3 回直しても解決しなければ、作業を止めて状況を報告する
- 依存ツール（`brew install` など）は、ユーザーに確認してから導入する

## 書くときの規則【共通】
- ソースのコメントは英語で書く。書式と用語は `docs_private/comment-translation-glossary.md`
- `README.md` と `README.ja.md` は同じ内容の 2 言語版。同じコミットで両方を同じ内容に変える（訳の一致はスクリプトで検査されない）
- `docs/`・README・ソースのコメントは公開される。`specs/`・`.specify/`・`docs_private/`・`shared-skills/`・`AGENTS.md` へリンクしない（公開の手順: `docs_private/repository-and-release.md`）

## 作業別の手順（該当するときに読む）
- 【Cloud】作業を始める前に `docs_private/cloud-agent-workflow.md`（feature の始め方、PR、CI、検証ゲート、並行する作業）
- 【共通】バグを直す: `docs_private/agents/bugfix.md`
- 【ローカル】アプリが起動しない・ウインドウが出ない、設定の保存先を調べる: `docs_private/agents/launch-debugging.md`
- 【ローカル】実装を並列化する: `docs_private/agents/parallel-worktree.md`（【Cloud】は Issue 単位で並行し、サブエージェントで実装を分けない）
- 【共通】スキル・Codex・Spec Kit の構成を変える、Codex を自動実行する: `docs_private/agents/skills-and-codex.md`
- 【共通】性能テストの基準値を変える・調べる: `specs/001-three-pane-media-viewer/quickstart.md` の「性能の検証」
