# MediaViewer — Agent Notes

このリポジトリ固有のルールです。全体の原則はグローバルの `AGENTS.md` に従います。
仕様の正本は `specs/product/`（領域別の Living spec）、仕様の運用ルールは `.specify/memory/constitution.md` の「仕様の管理」です。
`specs/001-three-pane-media-viewer/` は凍結した実装の記録です。

## プロジェクト概要

- macOS 15 以降 / Swift 6 / AppKit のみ / 外部パッケージ依存なし / Swift Package 構成
- `MediaViewerCore` は AppKit を import しない。判断ロジックは Core、描画と入力は `MediaViewerApp` に置く
- デコード・ディレクトリ列挙・ファイル操作を UI スレッドで行わない
- `URLSession` / `Network` / `NWConnection` などのネットワーク API を使わない
- 新しい要件は新しい feature ディレクトリ（`specs/NNN-xxx/`）で扱い、実装と検証が終わってから変更点を `specs/product/` へ反映する
  （手順と ID の付け方は `specs/product/README.md`）
- 実装中に更新する仕様文書は、作業中の feature の `tasks.md` のチェックと、タスクで明示された追記（例: T077 の quickstart）だけにする
- 進捗は作業中の feature の `tasks.md` を正とする

## Phase の検証ゲート

まとまった変更・Phase の終わりに、次をこの順で行います。

1. `swift build`
2. `swift test`
3. `scripts/check-no-network.sh`
4. 起動スモーク（3ペインが表示されること）
   - `scripts/make-app.sh`
   - `open .build/MediaViewer.app`
   - GUI の起動はユーザーに依頼する。依頼時は実行コマンドと確認ポイントを具体的に示す
5. 問題がなければ Phase 単位でコミットする

起動スモークを省略して「テストが通ったから完了」にしないこと。

## 起動しないときの初動（AppKit / macOS）

クラッシュレポートがなく、終了コードが 0 でも、AppKit が Objective-C 例外を握りつぶしていることがあります。
推測でコードを直す前に、まず lldb で例外を止めてください。GUI を起動するため、実行前にユーザーへ依頼します。

```bash
cd /Users/igachan/projects/my_img_viewer
lldb -b \
  -o 'breakpoint set -E objc' \
  -o 'run' \
  -o 'bt 30' \
  -o 'po $x0' \
  -o 'quit' \
  -- .build/MediaViewer.app/Contents/MacOS/MediaViewer
```

- 例外を1つ直したら、ユーザーに GUI 確認を戻さず、もう一度 lldb を実行して次の例外を確認する
- 例外がなくなり、ウインドウが表示されてから、ユーザーに視覚確認を依頼する
- 古いプロセスが残っていないか `pgrep -fl MediaViewer` で確認する
- ターミナルから直接実行すると、起動時の出力を確認できる
  （`.build/MediaViewer.app/Contents/MacOS/MediaViewer`）

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

## テスト

- Swift Testing を使う（`Tests/MediaViewerCoreTests`、`Tests/MediaViewerPerformanceTests`）
- Core のロジックと異常系にはテストを付ける
- フィクスチャは `FixtureKit` で一時ディレクトリに生成し、テスト後に削除する
- 性能テストの基準値は `specs/001-three-pane-media-viewer/quickstart.md` の「性能の検証」に従う
- テストの失敗を3回直しても解決しない場合は、作業を止めて状況を報告する

## 検証用コマンド

```bash
swift build
swift test
swift test --filter MediaViewerCoreTests
swift test --filter MediaViewerPerformanceTests
scripts/check-no-network.sh
scripts/make-fixtures.sh ~/MediaViewerFixtures
scripts/make-app.sh
open .build/MediaViewer.app
```

- `scripts/make-fixtures.sh` は WebP 生成に `cwebp` / `img2webp` を使う。導入はユーザーに確認する
- `.app` と `swift run` では UserDefaults のドメインが異なる
  - `.app`: `local.my-img-viewer.MediaViewer`
  - `swift run`: `MediaViewerApp`

## 参照

- 起動不具合の詳細な振り返り: `docs/retrospective/2026-10-19-startup-debugging.md`
- 使い方・手動確認: `README.md`
- 検証手順: `specs/001-three-pane-media-viewer/quickstart.md`
