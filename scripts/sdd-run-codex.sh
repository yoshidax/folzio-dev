#!/bin/bash
# scripts/sdd-run-codex.sh run "<追加要件>" [-i key=value ...]
# scripts/sdd-run-codex.sh resume <run_id>
# scripts/sdd-run-codex.sh status [<run_id>]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$root/scripts/sdd-codex.py" "$@"
