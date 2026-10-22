#!/bin/bash
# Claude Code のフック（.claude/sdd-workflow-settings.json）から呼ばれ、ワークフロー中の claude -p の動きを
# 1行ずつ SDD_PROGRESS_LOG に追記する。ログ先がなければ何もしない。フックの失敗で作業を止めないよう、常に 0 で終わる
set -uo pipefail

[[ -n "${SDD_PROGRESS_LOG:-}" ]] || exit 0

line=$(jq -r '
  def short: tostring | gsub("\n"; " ") | if length > 120 then .[0:117] + "..." else . end;
  if .hook_event_name == "PostToolUse" then
    "[" + .tool_name + "] "
      + ((.tool_input.file_path // .tool_input.command // .tool_input.description
          // .tool_input.skill // .tool_input.pattern // "") | short)
  elif .hook_event_name == "SubagentStart" then
    "[Agent開始] " + ((.agent_type // .description // .agent_id // "") | short)
  elif .hook_event_name == "SubagentStop" then
    "[Agent終了] " + ((.agent_type // .description // .agent_id // "") | short)
  else
    "[" + (.hook_event_name // "?") + "]"
  end
' 2>/dev/null) || exit 0

# ワークツリーの中の絶対パスは、リポジトリからの相対パスにして短くする
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
printf '%s %s\n' "$(date +%H:%M:%S)" "${line//$root\//}" >> "$SDD_PROGRESS_LOG" 2>/dev/null
exit 0
