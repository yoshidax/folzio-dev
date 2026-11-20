#!/bin/bash
# specs/product/ の ID の重複と、定義のない参照を検査する。
#
#   scripts/dev/check-spec-ids.sh           # 重複と参照を検査
#   scripts/dev/check-spec-ids.sh --next    # 種類ごとの次の ID を表示
set -euo pipefail

cd "$(dirname "$0")/../.."

if (($#)); then
    exec python3 scripts/dev/check-spec-references.py "$@"
fi

status=0
duplicates=$(grep -rhoE '^\s*- \*\*(FR|SC|EC|A)-[0-9]+\*\*' specs/product | sed -E 's/^\s*- //' | sort | uniq -d || true)

if [ -n "$duplicates" ]; then
    echo "Duplicated spec IDs under specs/product:" >&2
    echo "$duplicates" >&2
    status=1
else
    echo "No duplicated spec IDs."
fi

python3 scripts/dev/check-spec-references.py || exit "$?"
exit "$status"
