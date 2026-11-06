#!/bin/bash
# 指定コミットから公開用の候補だけを生成する。公開先のリポジトリは変更しない。
set -euo pipefail
exec python3 "$(dirname "$0")/export-public.py" "$@"
