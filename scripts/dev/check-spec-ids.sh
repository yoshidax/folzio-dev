#!/bin/bash
# 使い方: scripts/dev/check-spec-ids.sh
# 対象の ID と終了コードは check-spec-ids.py の docstring を参照。
set -euo pipefail

exec python3 -I "$(dirname "$0")/check-spec-ids.py"
