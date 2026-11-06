#!/bin/bash
# 公開用リポジトリへ書き出す README から、開発用リポジトリの注記を除く。
#
#   scripts/dev/strip-readme-dev-note.sh <file>...
#
# 注記は、行の全体が "<!-- dev-repo-note:start -->" の行から "<!-- dev-repo-note:end -->" の行まで（両方を含む）。
# 終了の印の直後の空行 1 行も除くので、結果は注記を置く前の README と同じになる。末尾の改行の有無は変えない。
# 印のないファイルは変えない。
#
# どのファイルも、書き換える前にすべて確かめる。ファイルがない、印の対応が崩れている（入れ子、2 つ以上を含む）、
# 印の行の改行が CRLF、除いた後に印の文字列が残る、のどれかに当たれば、どのファイルも変えずに終了コード 1 で終わる。
set -euo pipefail

if (($# == 0)); then
    echo "Usage: scripts/dev/strip-readme-dev-note.sh <file>..." >&2
    exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

failed=0
index=0
for file in "$@"; do
    index=$((index + 1))
    if [[ ! -f "$file" ]]; then
        echo "$file: file not found" >&2
        failed=1
        continue
    fi
    output="$tmp/$index"
    # awk は各行の後に改行を出すので、元のファイルの末尾に改行がなければ、最後の行の後に出さない
    final_newline=1
    if [[ -n "$(tail -c 1 "$file")" ]]; then
        final_newline=0
    fi
    # ファイル名は環境変数で、内容は標準入力で渡す。awk -v は名前のエスケープを解釈し、
    # 引数に渡すと "=" を含む名前を変数の代入と見なすため
    if ! STRIP_FILE="$file" STRIP_FINAL_NEWLINE="$final_newline" awk '
        function fail(message) {
            print ENVIRON["STRIP_FILE"] ":" NR ": " message > "/dev/stderr"
            error = 1
            exit 1
        }
        function emit(line) {
            printf "%s%s", separator, line
            separator = "\n"
            printed = 1
        }
        {
            line = $0
            sub(/\r$/, "", line)
            if (line != $0 && (line == "<!-- dev-repo-note:start -->" || line == "<!-- dev-repo-note:end -->")) {
                fail("marker line ends with CR (CRLF line endings); convert the file to LF")
            }
        }
        $0 == "<!-- dev-repo-note:start -->" {
            if (inside) fail("nested start marker")
            if (ranges > 0) fail("more than one note range")
            inside = 1
            next
        }
        $0 == "<!-- dev-repo-note:end -->" {
            if (!inside) fail("end marker without a start marker")
            inside = 0
            ranges++
            skip_blank = 1
            next
        }
        inside { next }
        {
            if (skip_blank && $0 == "") {
                skip_blank = 0
                next
            }
            skip_blank = 0
            emit($0)
        }
        END {
            if (error) exit 1
            if (inside) {
                print ENVIRON["STRIP_FILE"] ": start marker without an end marker" > "/dev/stderr"
                exit 1
            }
            if (printed && ENVIRON["STRIP_FINAL_NEWLINE"] == "1") printf "\n"
        }
    ' <"$file" >"$output"; then
        failed=1
        continue
    fi
    if grep -n "dev-repo-note:" "$output" >/dev/null; then
        echo "$file: marker text remains outside a whole marker line" >&2
        failed=1
    elif ! grep -qxF -e "<!-- dev-repo-note:start -->" -e "<!-- dev-repo-note:end -->" "$file"; then
        # 印のないファイルは、バイト単位でそのまま残す
        cp "$file" "$output"
    fi
done

if ((failed)); then
    exit 1
fi

index=0
for file in "$@"; do
    index=$((index + 1))
    cat "$tmp/$index" >"$file"
done
