#!/bin/bash
# Runs the rule checks that do not need Swift, in one place.
#
#   scripts/dev/check-all.sh
#
# Used by the Phase verification gate (local) and by Cloud agents. Runs every check even when an earlier one
# fails, then exits with 1 when any of them failed. `swift build` and `swift test` are not included.
set -uo pipefail

cd "$(dirname "$0")/../.."

failed=()

run() {
    echo "==> $*"
    if ! "$@"; then
        failed+=("$*")
    fi
}

run scripts/check-no-network.sh
run scripts/check-no-archive-writes.sh
run scripts/check-readme-sync.sh master
run scripts/dev/check-english-comments.sh
run scripts/dev/check-skill-sync.sh
run scripts/dev/check-spec-ids.sh
run python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'

if ((${#failed[@]} != 0)); then
    echo "failed checks:" >&2
    printf '  %s\n' "${failed[@]}" >&2
    exit 1
fi

echo "all checks passed"
