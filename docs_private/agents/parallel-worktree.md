# 並列実装（worktree 標準）

AGENTS.md から参照する、ローカルで実装を並列化するときの規約。
Cloud では、別の Issue を別のセッションが並行して担当し、サブエージェントによるタスク分割の並列実装は行わない。
経緯は [2026-10-19 の振り返り](../retrospective/2026-10-19-startup-debugging.md) にある
（同じ作業ツリーで並列エージェントを動かし、統合をコンパイルだけで確かめたため、起動時の例外を見逃した）。

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
- Codex の初期ワークフローは順次実装する。内部 subagent による同じ作業ディレクトリでの並列編集は行わない。
  並列実装を明示的に行う場合も、この規約に従って独立したセッションを使う
