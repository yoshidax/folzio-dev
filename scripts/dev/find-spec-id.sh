#!/bin/bash
# specs/product/ で ID（FR・SC・EC・A・USn-ASm）を定義している場所への Markdown リンクを出力する。
#
#   scripts/dev/find-spec-id.sh [--absolute] FR-080 US16-AS1 …
#
# エージェントがメッセージで ID を挙げるとき、出力をそのまま貼るために使う（AGENTS.md の「書くときの規則」）。
# 出力は `[FR-080](specs/product/search.md#L8)` の形で、パスはリポジトリのルートからの相対パス。
# --absolute を付けると、リポジトリのルートの絶対パスから始める（Codex Cloud は相対パスのリンクを開けないため）。
# 定義は、行頭の箇条書き（`- **FR-080**`）か番号付きリスト（`2. **US30-AS2**`）の太字の ID とし、本文中の言及は数えない。
# 見つからない ID は標準エラーに出して、ほかの ID を出力した後に 1 で終わる。
# 引数に ID がないか、ID の形でない引数や知らないオプションがあれば 2 で終わる。
# 環境ごとに開けるリンクの形式: docs_private/agents/id-links.md
set -euo pipefail

cd "$(dirname "$0")/../.."

usage() {
    echo "usage: scripts/dev/find-spec-id.sh [--absolute] <ID>…（例: FR-080 US16-AS1）" >&2
    exit 2
}

prefix=""
ids=()
for arg in "$@"; do
    if [ "$arg" = "--absolute" ]; then
        prefix="$(pwd -P)/"
    elif [[ "$arg" =~ ^((FR|SC|EC|A)-[0-9]+|US[0-9]+-AS[0-9]+)$ ]]; then
        ids+=("$arg")
    else
        echo "ID の形でも、知っているオプションでもありません: $arg" >&2
        usage
    fi
done
((${#ids[@]} != 0)) || usage

status=0
for id in "${ids[@]}"; do
    # grep -rn の出力は `path:line:本文`。本文を捨てて `path:line` だけにする
    matches=$(grep -rnE --include='*.md' "^[[:space:]]*(-|[0-9]+\.) \*\*${id}\*\*" specs/product | cut -d: -f1,2 | sort || true)
    if [ -z "$matches" ]; then
        echo "見つかりません: $id" >&2
        status=1
        continue
    fi
    while IFS=: read -r path line; do
        target="${prefix}${path}#L${line}"
        # 空白を含むパスは、Markdown のリンク先として <> で囲まないと途中で切れる
        if [[ "$target" == *" "* ]]; then
            target="<${target}>"
        fi
        echo "[${id}](${target})"
    done <<< "$matches"
done

exit "$status"
