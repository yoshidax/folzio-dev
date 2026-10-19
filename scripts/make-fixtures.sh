#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: scripts/make-fixtures.sh <output-directory>" >&2
    exit 2
fi

output="$1"
mkdir -p "$output"

cd "$(dirname "$0")/.."
swift run make-fixtures "$output"
