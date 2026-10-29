#!/bin/bash
# 公開用リポジトリへ HEAD の内容を書き出す。.gitattributes で export-ignore にしたファイルは含めない。
# 書き出し先でビルド・テスト・ネットワーク非依存の確認を行い、変更をステージするところまで進める。
# コミットと push は内容を確認してから手で行う
#
#   scripts/publish.sh [書き出し先]   （既定: ../my_img_viewer-oss）
set -euo pipefail

cd "$(dirname "$0")/.."

dest="${1:-../my_img_viewer-oss}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "未コミットの変更があります。コミットしてから書き出してください" >&2
    exit 1
fi

# README の英語版と日本語版の構造がそろっているか確かめる
scripts/check-readme-sync.sh

# ソースコードのコメントに日本語が残っていないか確かめる
scripts/check-english-comments.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git archive HEAD | tar -x -C "$tmp"

# 開発用のファイルが混ざっていないか確かめる
if (cd "$tmp" && find . | grep -E '^\./(\.specify|\.claude|\.agents|\.kilo|\.codex|\.vscode|specs|docs_private)(/|$)|^\./AGENTS\.md$|^\./\.gitattributes$|^\./scripts/(sdd-|spec-restructure|tests|publish\.sh)'); then
    echo "書き出しに開発用のファイルが含まれています（.gitattributes を確認してください）" >&2
    exit 1
fi

# ローカルのパスとユーザー名が残っていないか確かめる
if grep -rnIF -e "$HOME" -e "$(id -un)" "$tmp"; then
    echo "書き出しにローカルのパスまたはユーザー名が含まれています" >&2
    exit 1
fi

if [[ ! -d "$dest/.git" ]]; then
    mkdir -p "$dest"
    git -C "$dest" init -b main
fi

rsync -a --delete --exclude /.git --exclude /.build "$tmp"/ "$dest"/

cd "$dest"
swift build
# 性能テストと同時に走らせると、Core の待ち時間のあるテストが CPU 不足で落ちるため、順に実行する
swift test --filter MediaViewerCoreTests
swift test --filter MediaViewerPerformanceTests
scripts/check-no-network.sh

git add -A
echo
echo "書き出し先: $(pwd)"
git status --short
echo
echo "内容を確認してから、書き出し先で git commit を行ってください"
