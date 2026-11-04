#!/bin/bash
# Checks that AGENTS.md stays short and that the repository paths it references exist.
#
#   scripts/dev/check-agents-md.sh
#
# AGENTS.md is read on every agent turn, so it has a hard line limit. Fails when it has more than
# MAX_LINES lines. Warns (without failing) when it has more than WARN_LINES lines and more lines than
# on the base ref (scripts/dev/base-ref.sh), or when there is no base ref to compare against.
#
# References are read from inline code spans, fenced code blocks, and Markdown link targets.
# A code span that names an existing path as a whole (even with spaces) is accepted. Otherwise each word
# is checked after removing quotes, a trailing `:line`, and a trailing `#anchor`:
# - a word with a slash is a repository path when its first component exists now or on the base ref,
#   so renaming a whole top-level directory is still detected
# - a word without a slash is a repository path only when it exists at the root of the base ref,
#   so deleting or renaming a root file such as README.ja.md is detected, and words like tasks.md are not
# Other words with a slash (branches such as origin/master, slash commands, owner/repo), globs and
# placeholders (*, <...>, {...}, $...), URLs, and build output under .build/ are not checked.
# Where new rules belong: docs_private/agents/README.md.
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

base_ref=$(scripts/dev/base-ref.sh) || base_ref=
base_lines=
if [[ -n "$base_ref" ]] && git cat-file -e "$base_ref:$file" 2>/dev/null; then
    base_lines=$(git show "$base_ref:$file" | count_lines)
fi

if ((lines > MAX_LINES)); then
    echo "$file has $lines lines (limit: $MAX_LINES)." >&2
    echo "Move task-specific material out and leave a pointer, or turn the rule into a check (see $GUIDE)." >&2
    status=1
elif ((lines > WARN_LINES)) && [[ -z "$base_lines" || "$lines" -gt "$base_lines" ]]; then
    if [[ -n "$base_lines" ]]; then
        echo "warning: $file has $lines lines ($base_lines on $base_ref as of the last fetch, limit: $MAX_LINES)." >&2
    else
        echo "warning: $file has $lines lines (no base ref to compare against, limit: $MAX_LINES)." >&2
    fi
    echo "Review it before adding rules (see $GUIDE)." >&2
fi

# Prints, one per line, the contents of inline code spans, every line inside fenced code blocks,
# and the targets of Markdown links (except URLs and in-page anchors).
references() {
    awk '
        /^[[:space:]]*```/ { fence = !fence; next }
        fence { print; next }
        {
            line = $0
            while (match(line, /`[^`]*`/)) {
                print substr(line, RSTART + 1, RLENGTH - 2)
                line = substr(line, RSTART + RLENGTH)
            }
            line = $0
            while (match(line, /\]\([^)]*\)/)) {
                target = substr(line, RSTART + 2, RLENGTH - 3)
                if (target !~ /^(#|[A-Za-z][A-Za-z0-9+.-]*:)/) print target
                line = substr(line, RSTART + RLENGTH)
            }
        }
    ' "$1"
}

in_base() {
    [[ -n "$base_ref" ]] && git cat-file -e "$base_ref:$1" 2>/dev/null
}

# Prints the word when it is a repository path that does not exist.
check_word() {
    local word=$1 first
    word=${word//\"/}
    word=${word//\'/}
    word=$(printf '%s' "$word" | sed -e 's/:[0-9][0-9]*.*$//' -e 's/#.*$//')
    [[ -n "$word" ]] || return 0
    case "$word" in
        *[*\<\>{}\$]* | *://* | .build/*) return 0 ;;
    esac
    if [[ "$word" == */* ]]; then
        first=${word%%/*}
        [[ -n "$first" ]] || return 0
        [[ -e "$first" ]] || in_base "$first" || return 0
    else
        in_base "$word" || return 0
    fi
    [[ -e "$word" ]] || echo "$word"
}

missing=$(
    references "$file" | while IFS= read -r span; do
        [[ -n "$span" && ! -e "$span" ]] || continue
        read -r -a words <<<"$span" || true
        for word in ${words[@]+"${words[@]}"}; do
            check_word "$word"
        done
    done | sort -u
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
