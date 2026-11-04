---
name: folzio-session-misalignment-review
description: AI エージェント・セッションの会話を分析し、ユーザーとエージェントの取り違え・見落とし・前提のズレを、原文の引用と最小限のポインタで報告する。必要に応じてセッション当時のコード状態も確認する。会話のすれ違いの振り返りに使う。Use when asked to review a session or conversation for misunderstandings, missed instructions, or misalignment. コードレビュー、バグ診断、会話の要約には使わない。
---

# セッションのすれ違いレビュー

1つの AI エージェント・セッションを読み、ユーザーとエージェントの間の取り違え・見落とし・前提のズレを報告する。開始前に `AGENTS.md` と `shared-skills/folzio-session-misalignment-review.md` を読み、共通手順を実行する。指示が競合するときは上位の指示と `AGENTS.md` を優先する。

## セッションの取得（Claude Code）

- 現在のセッションはコンテキストを使う。
- 過去のセッションは `~/.claude/projects/<project-dir>/<session-id>.jsonl` を読む。`<project-dir>` は作業ディレクトリの絶対パスの `/` を `-` に置き換えた名前（例: `-Users-igachan-projects-folzio`）。候補は `ls ~/.claude/projects` で確認する。
- 各行は JSON で、`type`、`message`、`uuid`、`timestamp`、`sessionId` を持つ。`type` が `user` または `assistant` の行を会話として扱う。
- `isSidechain` が true の行はサブエージェントの会話として分ける。`attachment`、`system`、`api-request` などは根拠にだけ使う。

## コード状態の特定（Claude Code）

- 各行の `cwd` と `gitBranch` を使う。ブランチ名はあるがコミット SHA はない場合があるため、`git log` で当時のコミットを特定する。特定できなければ分析前の確認を行う。
- `cwd` はターンごとに変わり得る。worktree や複数リポジトリがある場合は、パスごとにリポジトリを解決する。
