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

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git archive HEAD | tar -x -C "$tmp"

# 開発用リポジトリだけに置く README の注記（dev-repo-note の印の範囲）を、書き出しの README から除く。
# 印の対応が崩れていれば、公開先に触れる前に止まる
readmes=()
readme_count=0
for readme in README.md README.ja.md; do
    if [[ -f "$tmp/$readme" ]]; then
        readmes+=("$tmp/$readme")
        readme_count=$((readme_count + 1))
    fi
done
if ((readme_count > 0)); then
    scripts/dev/strip-readme-dev-note.sh "${readmes[@]}"
fi

# 開発用のファイルが混ざっていないか確かめる
if (cd "$tmp" && find . | grep -E '^\./(\.specify|\.claude|\.agents|\.kilo|\.codex|\.vscode|specs|docs_private|shared-skills)(/|$)|^\./AGENTS\.md$|^\./\.gitattributes$|^\./scripts/dev(/|$)|^\./\.github/workflows(/|$)'); then
    echo "書き出しに開発用のファイルが含まれています（.gitattributes を確認してください）" >&2
    exit 1
fi

# 公開用リポジトリだけで動かす workflow を、HEAD の管理元から書き出しの .github/workflows/ に置く。
# 管理元の直下の通常ファイルで、名前が .yml か .yaml で終わるものだけを置く
# （サブディレクトリ・シンボリックリンク・説明の文書は置かない）。開発用の .github/workflows/ は上で除いている
oss_workflows="scripts/dev/oss-workflows"
# 古い bash（macOS の 3.2）では set -u で空の配列を展開できないため、件数は配列から求めずに数える
workflow_names=()
workflow_ids=()
workflow_count=0
while IFS= read -r -d '' entry; do
    read -r mode type id <<<"${entry%%$'\t'*}"
    path="${entry#*$'\t'}"
    name="${path##*/}"
    if [[ "$type" == blob && ( "$mode" == 100644 || "$mode" == 100755 ) && ( "$name" == *.yml || "$name" == *.yaml ) ]]; then
        workflow_names+=("$name")
        workflow_ids+=("$id")
        workflow_count=$((workflow_count + 1))
    fi
done < <(git ls-tree -z HEAD -- "$oss_workflows/")

if ((workflow_count > 0)); then
    mkdir -p "$tmp/.github/workflows"
    for ((i = 0; i < workflow_count; i++)); do
        git cat-file blob "${workflow_ids[i]}" >"$tmp/.github/workflows/${workflow_names[i]}"
    done
fi

# 書き出しの .github/workflows/ が、管理元の workflow と名前・内容とも一致するか確かめる
placed=0
if [[ -d "$tmp/.github/workflows" ]]; then
    placed=$(find "$tmp/.github/workflows" -mindepth 1 | wc -l | tr -d ' ')
fi
if [[ "$placed" != "$workflow_count" ]]; then
    echo "書き出しの .github/workflows/ が $oss_workflows/ の workflow と一致しません（$placed 件、管理元は $workflow_count 件）" >&2
    exit 1
fi
for ((i = 0; i < workflow_count; i++)); do
    if ! git cat-file blob "${workflow_ids[i]}" | cmp -s - "$tmp/.github/workflows/${workflow_names[i]}"; then
        echo "書き出しの .github/workflows/${workflow_names[i]} が $oss_workflows/ の内容と一致しません" >&2
        exit 1
    fi
done
if ((workflow_count > 0)); then
    echo "公開用 workflow: ${workflow_names[*]}"
else
    echo "公開用 workflow はありません"
fi

# ローカルのパスとユーザー名が残っていないか確かめる
if grep -rnIF -e "$HOME" -e "$(id -un)" "$tmp"; then
    echo "書き出しにローカルのパスまたはユーザー名が含まれています" >&2
    exit 1
fi

# 公開版の Markdown から、書き出さないファイルへのリンクが張られていないか確かめる
if grep -rnIE --include='*.md' '(\]\(|href=")[^)"]*(specs/|\.specify/|docs_private/|shared-skills/|AGENTS\.md)' "$tmp"; then
    echo "書き出しに、公開しないファイルへのリンクが含まれています" >&2
    exit 1
fi

if [[ ! -d "$dest/.git" ]]; then
    mkdir -p "$dest"
    git -C "$dest" init -b main
fi

rsync -a --delete --exclude /.git --exclude /.build --exclude /.vscode "$tmp"/ "$dest"/

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
