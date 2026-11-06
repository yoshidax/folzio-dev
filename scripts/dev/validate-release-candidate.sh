#!/bin/bash
# 同じ公開候補を検証し、性能の結果を残して確認用 ZIP を生成する。
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: validate-release-candidate.sh SOURCE_DIR OUTPUT_DIR' >&2; exit 2; }
source_dir="$(cd "$1" && pwd -P)"
output="$2"
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
[[ ! -e "$output" ]] || { echo 'Output already exists' >&2; exit 1; }
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd -P)/$(basename "$output")"
request="$(python3 "$root/scripts/release.py" request "$source_dir")"
version="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["version"])' "$request")"
build="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["build_number"])' "$request")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$source_dir" "$tmp/source"
cd "$tmp/source"
# Python のタイムアウトで macOS の追加依存を使わず、停止したテストも終了させる。
limited() {
    python3 - "$@" <<'PY'
import os, signal, subprocess, sys
process = subprocess.Popen(sys.argv[1:], start_new_session=True)
try:
    sys.exit(process.wait(timeout=600))
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGKILL)
    process.wait()
    sys.exit(124)
PY
}
swift build
limited swift test --no-parallel --skip FolzioPerformanceTests
performance=success
if limited swift test --filter FolzioPerformanceTests > "$tmp/performance.log" 2>&1; then
    cat "$tmp/performance.log"
else
    code=$?
    cat "$tmp/performance.log"
    performance=failure
    [[ "$code" != 124 ]] || performance=timed_out
    echo "Performance measurement: $performance (non-blocking)" >&2
fi
bash scripts/check-no-network.sh
bash "$root/scripts/package-release.sh" "$version" "$build" "$tmp/source" "$output"
cp "$tmp/performance.log" "$output/performance.log"
python3 - "$output/checks.json" "$performance" <<'PY'
import json, sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps(dict(
    required_checks={key:'success' for key in ['static','build','normal','network','package']},
    performance=sys.argv[2])))
PY
