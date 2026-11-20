#!/bin/bash
# 仕様の ID（FR・SC・EC・A・USn-ASm）を定義している場所への Markdown リンクを出力する。
#
#   scripts/dev/find-spec-id.sh [--absolute] FR-080 US16-AS1 …
#
# エージェントがメッセージで ID を挙げるとき、出力をそのまま貼るために使う（AGENTS.md の「書くときの規則」）。
# 出力は `[FR-080](specs/product/search.md#L8)` の形で、パスはリポジトリのルートからの相対パス。
# --absolute を付けると、リポジトリのルートの絶対パスから始める（Codex Cloud は相対パスのリンクを開けないため）。
#
# 探す場所:
# - 作業中の feature の spec.md。作業中の feature は、specs/ の下の feature のディレクトリのうち、
#   比べる基準（scripts/dev/base-ref.sh の origin/master、なければ master）にまだないもの
#   - ここで見つかった ID は、specs/product/ に同じ ID があっても、作業中の feature の定義だけを出力する
#   - 基準がないとき（git のリポジトリの外など）は、作業中の feature を判定できないので探さない
# - specs/product/ の下のすべての Markdown
# 定義は、コードフェンスの外にある箇条書き（`- **FR-080**`）か番号付きリスト（`2. **US30-AS2**`）の先頭の太字の ID。
# 見つからない ID は標準エラーに出して、ほかの ID を出力した後に 1 で終わる。
# 引数が不正か、仕様ファイルの読み取りに失敗したときは 2 で終わる。
# 環境ごとに開けるリンクの形式: docs_private/agents/id-links.md
set -euo pipefail

exec python3 -I "$(dirname "$0")/find-spec-id.py" "$@"
