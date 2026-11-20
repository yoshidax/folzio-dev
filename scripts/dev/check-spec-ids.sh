#!/bin/bash
# specs/product/ の ID の重複と、定義のない参照を検査する。
#
#   scripts/dev/check-spec-ids.sh           # 重複と参照を検査
#   scripts/dev/check-spec-ids.sh --next    # 種類ごとの次の ID を表示
set -euo pipefail

cd "$(dirname "$0")/../.."

exec python3 scripts/dev/check-spec-references.py "$@"
