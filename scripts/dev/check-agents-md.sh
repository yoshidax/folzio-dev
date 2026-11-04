#!/bin/bash
# Checks that AGENTS.md stays short and that the repository paths it references exist.
#
#   scripts/dev/check-agents-md.sh
#
# AGENTS.md is read on every agent turn, so it has a hard line limit. Fails when it has more than
# MAX_LINES lines. Warns (without failing) when it has more than WARN_LINES lines and more lines than
# on origin/master (or master), so the warning appears when a change makes it longer, not on every run.
# Words inside backticks and inside fenced code blocks that contain a slash are treated as repository
# paths when their first component exists at the repository root, and must then exist. Other words
# with a slash (branches such as `origin/master`, slash commands, `owner/repo`), globs and placeholders
# (`*`, `<...>`, `{...}`, `$...`), URLs, and build output under `.build/` are not checked.
# A trailing `:line` is ignored. Where new rules belong: docs_private/agents/README.md.
set -euo pipefail

cd "$(dirname "$0")/../.."

MAX_LINES=50
WARN_LINES=45
GUIDE=docs_private/agents/README.md
file=AGENTS.md
status=0

# Counts the last line even when the file does not end with a newline (`wc -l` would not).
count_lines() {
    awk 'END { print NR }'
}

lines=$(count_lines <"$file")

base_ref=
base_lines=
for ref in origin/master master; do
    if git rev-parse --verify --quiet "$ref:$file" >/dev/null 2>&1; then
        base_ref=$ref
        base_lines=$(git show "$ref:$file" | count_lines)
        break
    fi
done

if ((lines > MAX_LINES)); then
    echo "$file has $lines lines (limit: $MAX_LINES)." >&2
    echo "Move task-specific material out and leave a pointer, or turn the rule into a check (see $GUIDE)." >&2
    status=1
elif ((lines > WARN_LINES)) && [[ -z "$base_lines" || "$lines" -gt "$base_lines" ]]; then
    if [[ -n "$base_ref" ]]; then
        echo "warning: $file has $lines lines ($base_lines on $base_ref, limit: $MAX_LINES)." >&2
    else
        echo "warning: $file has $lines lines (limit: $MAX_LINES)." >&2
    fi
    echo "Review it before adding rules (see $GUIDE)." >&2
fi

# Prints the contents of inline code spans and every line inside fenced code blocks.
code_text() {
    awk '
        /^[[:space:]]*```/ { fence = !fence; next }
        fence { print; next }
        {
            line = $0
            while (match(line, /`[^`]*`/)) {
                print substr(line, RSTART + 1, RLENGTH - 2)
                line = substr(line, RSTART + RLENGTH)
            }
        }
    ' "$1"
}

missing=$(
    code_text "$file" | tr -s ' \t' '\n\n' | tr -d "\"'" | sed 's/:[0-9][0-9]*.*$//' |
        grep '/' | grep -v -e '[*<>{}$]' -e '://' -e '^\.build/' | sort -u |
        while IFS= read -r path; do
            first="${path%%/*}"
            [[ -n "$first" && -e "$first" ]] || continue
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
