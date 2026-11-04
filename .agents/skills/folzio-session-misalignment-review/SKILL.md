---
name: folzio-session-misalignment-review
description: AI エージェント・セッションの会話を分析し、ユーザーとエージェントの取り違え・見落とし・前提のズレを、原文の引用と最小限のポインタで報告する。必要に応じてセッション当時のコード状態も確認する。会話のすれ違いの振り返りに使う。Use when asked to review a session or conversation for misunderstandings, missed instructions, or misalignment. コードレビュー、バグ診断、会話の要約には使わない。
---

# セッションのすれ違いレビュー

1つの AI エージェント・セッションを読み、ユーザーとエージェントの間の取り違え・見落とし・前提のズレを報告する。開始前に `AGENTS.md` と `shared-skills/folzio-session-misalignment-review.md` を読み、共通手順を実行する。指示が競合するときは上位の指示と `AGENTS.md` を優先する。

## セッションの取得（Codex / Kilo Code）

- Kilo Code: 現在のセッションはコンテキストを使う。他のセッションは `kilo export <session-id> --sanitize` で JSON を取得する。過去セッションの検索には `kilo_local_recall` を使える。
- Codex: 現在のセッションはコンテキストを使う。過去のセッションは `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl.zst` を `zstd -dc` で展開して読む（`.jsonl` ならそのまま読む）。各レコードは `type`、`timestamp`、`ordinal` を持ち、会話は `payload` に入る。
- 会話の順序は `timestamp` または `ordinal` で決める。`session_meta` は対象の確認にだけ使う。

## コード状態の特定（Codex / Kilo Code）

- Kilo Code: `kilo export` の `info.directory` と、ツール呼び出しに残る `git` コマンドの出力から、ブランチとコミットを特定する。`--sanitize` では `info.directory` が伏字になるため、対象ディレクトリは `sqlite3 "$(kilo db path)" "select directory from session where id='<session-id>';"` で確認する。export にブランチ情報はないため、特定できなければ現在のブランチを当時の状態とみなさない。特定できない場合は、分析前の確認を必ず行う。
- Codex: `session_meta.payload.cwd` と `session_meta.payload.git`（`branch`、`commit_hash`）を使う。`turn_context.payload.cwd` はターンごとの作業ディレクトリとして確認する。`branch` または `commit_hash` が欠けている場合は分析前の確認を行う。
