#!/bin/bash
# 指定コミットの書き出し規則を使い、公開先を変更せず候補を生成する。
set -euo pipefail
[[ $# == 2 && "$1" =~ ^[0-9a-f]{40}$ ]] || { echo 'Usage: export-public.sh SOURCE_SHA OUTPUT_DIR' >&2; exit 2; }
mode="$(git ls-tree "$1" -- scripts/dev/export-public.py)"
[[ "$mode" == 100644* || "$mode" == 100755* ]] || { echo 'Exporter must be a committed regular file' >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git show "$1:scripts/dev/export-public.py" > "$tmp/export-public.py"
python3 "$tmp/export-public.py" "$@"
