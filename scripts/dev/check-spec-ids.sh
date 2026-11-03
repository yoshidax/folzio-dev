#!/bin/bash
# Check that no FR/SC/EC/A label is defined more than once under specs/product.
#
#   scripts/dev/check-spec-ids.sh
#
# Each label must be defined in exactly one area file (specs/product/README.md). Prints the
# duplicated labels and exits with 1 when any exists.
set -euo pipefail

cd "$(dirname "$0")/../.."

duplicates=$(grep -rhoE '^\s*- \*\*(FR|SC|EC|A)-[0-9]+\*\*' specs/product | sed -E 's/^\s*- //' | sort | uniq -d || true)

if [ -n "$duplicates" ]; then
    echo "Duplicated spec IDs under specs/product:" >&2
    echo "$duplicates" >&2
    exit 1
fi
echo "No duplicated spec IDs."
