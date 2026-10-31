---
name: folzio-register-issue
description: Folzio の機能・改善・バグをコードベースに照らして整理し、Linear の Folzio プロジェクトに新規登録または既存 Issue を更新する。実装や正式なバグ診断には使用しない。
---

# Folzio の Issue を登録する

Folzio の機能・改善・バグを現在の会話で整理し、Linear に登録または更新する。開始前に `AGENTS.md` と `docs_private/folzio-register-issue.md` を読み、共通手順を実行する。指示が競合するときは上位の指示と `AGENTS.md` を優先する。

Claude Code では Linear MCP として `mcp__linear-server__*` を使う。未読み込みなら `ToolSearch` で読み込む。`save_issue` の `description` はテンプレート本文を置き換えるので、`get_template` の見出しに沿った本文全体を渡す。既存 Issue の更新では、`labels` は全置換なので `addLabels` を使い、本文は `patch` で追記する。
