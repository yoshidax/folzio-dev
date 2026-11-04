---
name: folzio-agents-md-audit
description: AGENTS.md の各行を監査し、削除・移動・ツール化・残すに分類して保守者に確認し、上限の行数に収まる改訂案を作る。承認まで編集しない。AGENTS.md の見直し・肥大化への対応、scripts/dev/check-agents-md.sh の警告や失敗に使う。Use when asked to audit, slim down, or review AGENTS.md. AGENTS.md に規則を1つ足すだけのときは使わない。
---

# AGENTS.md の監査

`AGENTS.md` の各行が今も必要かを保守者と確かめ、上限の行数に収まる改訂案を作る。開始前に `shared-skills/folzio-agents-md-audit.md` を読み、共通手順を実行する。指示が競合するときは上位の指示と `AGENTS.md` を優先する。

## Codex / Kilo Code での注意

- Codex の `.codex/rules/` と Kilo の `.kilo/kilo.jsonc` を変えるツール化は、改訂案に変更内容を示し、承認の後に編集する。
- Linear の MCP に接続できないときは、Issue の経緯を保守者に尋ねる。接続できたものとして扱わない。
