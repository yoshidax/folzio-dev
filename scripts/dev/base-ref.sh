#!/bin/bash
# Prints the ref that checks compare the working tree against.
#
#   scripts/dev/base-ref.sh
#
# Prints origin/master when it exists, otherwise master. Prints nothing and exits with 1 when neither exists
# (for example, outside a git repository). origin/master is only as new as the last fetch.
set -uo pipefail

for ref in origin/master master; do
    if git rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
        echo "$ref"
        exit 0
    fi
done
exit 1
