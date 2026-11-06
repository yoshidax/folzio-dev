#!/bin/bash
# Remove the development repository note from README files before they are published.
#
#   scripts/dev/strip-readme-dev-note.sh <file>...
#
# The note is the range from a line that is exactly "<!-- dev-repo-note:start -->" to a line that is
# exactly "<!-- dev-repo-note:end -->", both included. A blank line right after the end marker is
# removed too, so the result matches the README without the note. A file without markers is left as is.
#
# Every file is checked before any file is changed. If a file is missing, has unbalanced, nested,
# or repeated markers, or still contains the marker text after the removal, no file is changed
# and the script exits with status 1.
set -euo pipefail

if (($# == 0)); then
    echo "Usage: scripts/dev/strip-readme-dev-note.sh <file>..." >&2
    exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

failed=0
index=0
for file in "$@"; do
    index=$((index + 1))
    if [[ ! -f "$file" ]]; then
        echo "$file: file not found" >&2
        failed=1
        continue
    fi
    output="$tmp/$index"
    if ! awk -v file="$file" '
        function fail(message) {
            print file ":" NR ": " message > "/dev/stderr"
            error = 1
            exit 1
        }
        $0 == "<!-- dev-repo-note:start -->" {
            if (inside) fail("nested start marker")
            if (ranges > 0) fail("more than one note range")
            inside = 1
            next
        }
        $0 == "<!-- dev-repo-note:end -->" {
            if (!inside) fail("end marker without a start marker")
            inside = 0
            ranges++
            skip_blank = 1
            next
        }
        inside { next }
        {
            if (skip_blank && $0 == "") {
                skip_blank = 0
                next
            }
            skip_blank = 0
            print
        }
        END {
            if (error) exit 1
            if (inside) {
                print file ": start marker without an end marker" > "/dev/stderr"
                exit 1
            }
        }
    ' "$file" >"$output"; then
        failed=1
        continue
    fi
    if grep -n "dev-repo-note:" "$output" >/dev/null; then
        echo "$file: marker text remains outside a whole marker line" >&2
        failed=1
    elif ! grep -qxF -e "<!-- dev-repo-note:start -->" -e "<!-- dev-repo-note:end -->" "$file"; then
        # Keep a file without markers byte for byte (awk would add a missing final newline).
        cp "$file" "$output"
    fi
done

if ((failed)); then
    exit 1
fi

index=0
for file in "$@"; do
    index=$((index + 1))
    cat "$tmp/$index" >"$file"
done
