#!/bin/bash
# Checks that AGENTS.md stays short and that the paths it references exist.
#
#   scripts/dev/check-agents-md.sh
#
# AGENTS.md is read on every agent turn, so it has a hard line limit. Fails when it has more than
# MAX_LINES lines, and warns (without failing) when it has more than WARN_LINES lines.
# Every token inside backticks that contains a slash is treated as a repository path and must exist,
# except globs and placeholders (`*`, `<...>`, `{...}`, `$...`), URLs, and build output under `.build/`.
# Where new rules belong and how to record why a rule was added: docs_private/agents/README.md.
set -euo pipefail

cd "$(dirname "$0")/../.."

MAX_LINES=50
WARN_LINES=45
GUIDE=docs_private/agents/README.md
file=AGENTS.md
status=0

lines=$(wc -l <"$file" | tr -d ' ')
if ((lines > MAX_LINES)); then
    echo "$file has $lines lines (limit: $MAX_LINES)." >&2
    echo "Move task-specific material out and leave a pointer, or turn the rule into a check (see $GUIDE)." >&2
    status=1
elif ((lines > WARN_LINES)); then
    echo "warning: $file has $lines lines (limit: $MAX_LINES). Review it before adding rules (see $GUIDE)." >&2
fi

missing=$(
    grep -o '`[^`]*`' "$file" | tr -d '`' | tr ' ' '\n' |
        grep '/' | grep -v -e '[*<>{}$]' -e '://' -e '^\.build/' | sort -u |
        while IFS= read -r path; do
            [[ -e "$path" ]] || echo "$path"
        done || true
)
if [[ -n "$missing" ]]; then
    echo "$file references paths that do not exist:" >&2
    echo "$missing" | sed 's/^/  /' >&2
    status=1
fi

if ((status == 0)); then
    echo "$file has $lines lines and all referenced paths exist"
fi
exit "$status"
