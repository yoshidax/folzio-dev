#!/bin/bash
# 公開用リポジトリへ HEAD の内容を書き出す。.gitattributes で export-ignore にしたファイルは含めない。
# README の開発用リポジトリの注記は、scripts/dev/strip-readme-dev-note.sh で除く。
# 公開用リポジトリだけで動かす workflow は、scripts/dev/oss-workflows/ から書き出しの .github/workflows/ に置く。
# 書き出し先でビルド・テスト・ネットワーク非依存の確認を行い、変更をステージするところまで進める。
# コミットと push は内容を確認してから手で行う
#
#   scripts/dev/publish.sh [書き出し先]   （既定: ../folzio-oss）
set -euo pipefail

cd "$(dirname "$0")/../.."

dest="${1:-../folzio-oss}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "未コミットの変更があります。コミットしてから書き出してください" >&2
    exit 1
fi

# README の英語版と日本語版の構造がそろっているか確かめる
scripts/check-readme-sync.sh

# ソースコードのコメントに日本語が残っていないか確かめる
scripts/dev/check-english-comments.sh

# 通常の公開は GitHub Actions。ローカル復旧でも同じ exporter を使う。
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
scripts/dev/export-public.sh "$(git rev-parse HEAD)" "$tmp/source"
tmp_source="$tmp/source"

if [[ ! -d "$dest/.git" ]]; then
    mkdir -p "$dest"
    git -C "$dest" init -b main
fi

rsync -a --delete --exclude /.git --exclude /.build --exclude /.vscode "$tmp_source"/ "$dest"/

dest="$(cd "$dest" && pwd)"
trap 'echo "公開先には同期済みの未検証の変更が残っています。確認せずにコミットしないでください: $dest" >&2' ERR
cd "$dest"
swift build
# 性能テストと同時に走らせると、Core の待ち時間のあるテストが CPU 不足で落ちるため、順に実行する
swift test --no-parallel --skip FolzioPerformanceTests
swift test --filter FolzioPerformanceTests
scripts/check-no-network.sh
trap - ERR

git add -A
echo
echo "書き出し先: $(pwd)"
git status --short
echo
echo "内容を確認してから、書き出し先で git commit を行ってください"
