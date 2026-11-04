#!/bin/bash
# Checks that AGENTS.md stays short and that the repository paths it references exist.
#
#   scripts/dev/check-agents-md.sh
#
# AGENTS.md is read on every agent turn, so it has a hard line limit. Fails when it has more than
# MAX_LINES lines. Warns (without failing) when it has more than WARN_LINES lines and more lines than
# on the base ref (scripts/dev/base-ref.sh), or when there is no base ref to compare against.
#
# References are read from inline code spans, fenced code blocks, Markdown link targets, and reference-style
# link definitions. A code span that names an existing path as a whole (even with spaces) is accepted.
# Otherwise each word is checked after removing quotes, a trailing `:line`, and a trailing `#anchor`:
# - a word with a slash is a repository path when its first component exists now or at the root of the base
#   ref (so renaming a whole top-level directory is detected), or when its last component has a file
#   extension (so a misspelled first directory such as doc_private/x.md is detected)
# - a word without a slash is a repository path when it exists at the root of the base ref (so deleting or
#   renaming a root file such as README.ja.md is detected), or when it has a file extension and is within
#   two edits of a root entry (so README.md misspelled as READMEE.md is detected, and tasks.md is not)
# Other words (branches such as origin/master, slash commands, owner/repo), absolute and home paths, globs
# and placeholders (*, <...>, {...}, $...), URLs, and build output under .build/ are not checked.
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
base_names=
if [[ -n "$base_ref" ]]; then
    base_names=$(git ls-tree --name-only "$base_ref" 2>/dev/null) || base_names=
    if git cat-file -e "$base_ref:$file" 2>/dev/null; then
        base_lines=$(git show "$base_ref:$file" | count_lines)
    fi
fi
# Entries at the repository root now and on the base ref, one per line.
root_names=$(
    {
        ls -A
        printf '%s\n' "$base_names"
    } | grep -v -x -e '' -e '.git' | sort -u
)

if ((lines > MAX_LINES)); then
    echo "$file has $lines lines (limit: $MAX_LINES)." >&2
    echo "Move task-specific material out and leave a pointer, or turn the rule into a check (see $GUIDE)." >&2
    status=1
elif ((lines > WARN_LINES)) && [[ -z "$base_lines" || "$lines" -gt "$base_lines" ]]; then
    if [[ "$base_ref" == origin/* ]]; then
        echo "warning: $file has $lines lines ($base_lines on $base_ref as of the last fetch, limit: $MAX_LINES)." >&2
    elif [[ -n "$base_lines" ]]; then
        echo "warning: $file has $lines lines ($base_lines on $base_ref, limit: $MAX_LINES)." >&2
    else
        echo "warning: $file has $lines lines (no base ref to compare against, limit: $MAX_LINES)." >&2
    fi
    echo "Review it before adding rules (see $GUIDE)." >&2
fi

# Prints, one per line, the contents of inline code spans, every line inside fenced code blocks,
# and the targets of Markdown links and reference-style link definitions (except URLs and in-page anchors).
references() {
    awk '
        function target_out(target) {
            if (target !~ /^(#|[A-Za-z][A-Za-z0-9+.-]*:)/) print target
        }
        /^[[:space:]]*```/ { fence = !fence; next }
        fence { print; next }
        /^[[:space:]]*\[[^]]+\]:[[:space:]]*[^[:space:]]/ {
            definition = $0
            sub(/^[[:space:]]*\[[^]]+\]:[[:space:]]*/, "", definition)
            sub(/[[:space:]].*$/, "", definition)
            gsub(/^<|>$/, "", definition)
            target_out(definition)
        }
        {
            line = $0
            while (match(line, /`[^`]*`/)) {
                print substr(line, RSTART + 1, RLENGTH - 2)
                line = substr(line, RSTART + RLENGTH)
            }
            line = $0
            while (match(line, /\]\([^)]*\)/)) {
                target_out(substr(line, RSTART + 2, RLENGTH - 3))
                line = substr(line, RSTART + RLENGTH)
            }
        }
    ' "$1"
}

in_base() {
    [[ -n "$base_names" ]] && printf '%s\n' "$base_names" | grep -Fxq -- "$1"
}

# Whether the last path component has a file extension (README.md, check-all.sh).
has_extension() {
    local name=${1##*/}
    [[ "$name" == ?*.[A-Za-z0-9]* ]]
}

# Whether the word is within two edits (Levenshtein distance) of an entry at the repository root.
near_root() {
    printf '%s\n' "$root_names" | awk -v word="$1" '
        function distance(s, t,    m, n, i, j, cost, best, d) {
            m = length(s); n = length(t)
            for (i = 0; i <= m; i++) d[i, 0] = i
            for (j = 0; j <= n; j++) d[0, j] = j
            for (i = 1; i <= m; i++) {
                for (j = 1; j <= n; j++) {
                    cost = (substr(s, i, 1) == substr(t, j, 1)) ? 0 : 1
                    best = d[i - 1, j] + 1
                    if (d[i, j - 1] + 1 < best) best = d[i, j - 1] + 1
                    if (d[i - 1, j - 1] + cost < best) best = d[i - 1, j - 1] + cost
                    d[i, j] = best
                }
            }
            return d[m, n]
        }
        distance(word, $0) <= 2 { found = 1; exit }
        END { exit !found }
    '
}

# Prints the word when it is a repository path that does not exist.
check_word() {
    local word=$1 first
    word=${word//\"/}
    word=${word//\'/}
    word=${word%%#*}
    word=${word%%:[0-9]*}
    [[ -n "$word" ]] || return 0
    case "$word" in
        *[*\<\>{}\$]* | *://* | .build/* | /* | '~'*) return 0 ;;
    esac
    if [[ "$word" == */* ]]; then
        first=${word%%/*}
        [[ -e "$first" ]] || in_base "$first" || has_extension "$word" || return 0
    else
        in_base "$word" || { has_extension "$word" && near_root "$word"; } || return 0
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
