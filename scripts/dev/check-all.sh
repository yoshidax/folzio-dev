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
# Prefer origin/master: the local master branch can be stale or missing in a Cloud clone.
readme_base=$(scripts/dev/base-ref.sh) || readme_base=master
run scripts/check-readme-sync.sh "$readme_base"
run scripts/dev/check-english-comments.sh
run scripts/dev/check-skill-sync.sh
run scripts/dev/check-spec-ids.sh
run scripts/dev/check-agents-md.sh
run python3 -I -m unittest discover -s scripts/dev/tests -p 'test_check_*.py'

if ((${#failed[@]} != 0)); then
    echo "failed checks:" >&2
    printf '  %s\n' "${failed[@]}" >&2
    exit 1
fi

echo "all checks passed"
