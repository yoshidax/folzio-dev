#!/bin/bash
# spec-kit ワークフロー（sdd-increment）の通知。macOS の通知とターミナルのベルを出し、進捗ログにも残す。
# 通知に失敗してもワークフローを止めないよう、常に 0 で終わる
#
#   scripts/sdd-notify.sh <メッセージ> [タイトル]
set -uo pipefail

message="${1:-}"
title="${2:-SDD workflow}"

if [[ -n "${SDD_PROGRESS_LOG:-}" ]]; then
    printf '%s [通知] %s: %s\n' "$(date +%H:%M:%S)" "$title" "$message" >> "$SDD_PROGRESS_LOG" 2>/dev/null
fi

# AppleScript の文字列に埋め込むため、\ と " をエスケープする
escape() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' <<< "$1"; }
osascript -e "display notification \"$(escape "$message")\" with title \"$(escape "$title")\" sound name \"Glass\"" \
    >/dev/null 2>&1

{ printf '\a' > /dev/tty; } 2>/dev/null
exit 0
