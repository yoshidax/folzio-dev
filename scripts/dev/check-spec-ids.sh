#!/bin/bash
# 製品仕様の ID の重複を検査する。
set -euo pipefail

cd "$(dirname "$0")/../.."

exec python3 scripts/dev/check-spec-ids.py
