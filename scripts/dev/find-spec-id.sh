#!/bin/bash
# specs/product/ で ID（FR・SC・EC・A・USn-ASm）を定義している場所を `ID path:line` の形で出力する。
#
#   scripts/dev/find-spec-id.sh FR-080 US16-AS1 …
#
# エージェントがメッセージで ID を挙げるとき、定義の位置を添えるために使う（AGENTS.md の「書くときの規則」）。
# パスはリポジトリのルートからの相対パスで出力する。定義は、行頭の箇条書き（`- **FR-080**`）か
# 番号付きリスト（`2. **US30-AS2**`）の太字の ID とし、本文中の言及は数えない。
# 見つからない ID は標準エラーに出して、ほかの ID を出力した後に 1 で終わる。引数がないか、ID の形でない引数があれば 2 で終わる。
# 環境ごとに開けるリンクの形式: docs_private/agents/id-links.md
set -euo pipefail

cd "$(dirname "$0")/../.."

if (($# == 0)); then
    echo "usage: scripts/dev/find-spec-id.sh <ID>…（例: FR-080 US16-AS1）" >&2
    exit 2
fi

for id in "$@"; do
    if [[ ! "$id" =~ ^((FR|SC|EC|A)-[0-9]+|US[0-9]+-AS[0-9]+)$ ]]; then
        echo "ID の形ではありません: $id" >&2
        exit 2
    fi
done

status=0
for id in "$@"; do
    # grep -rn の出力は `path:line:本文`。本文を捨てて `path:line` だけにする
    matches=$(grep -rnE --include='*.md' "^[[:space:]]*(-|[0-9]+\.) \*\*${id}\*\*" specs/product | cut -d: -f1,2 | sort || true)
    if [ -z "$matches" ]; then
        echo "見つかりません: $id" >&2
        status=1
        continue
    fi
    while IFS= read -r location; do
        echo "$id $location"
    done <<< "$matches"
done

exit "$status"
