#!/bin/bash
# Merge a branch into master and back it up to the private development repository.
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() { echo "Error: $*" >&2; exit 1; }
usage() { echo "Usage: scripts/dev/merge-to-master.sh <branch> | --continue | --push-only" >&2; exit 2; }
[[ $# == 1 ]] || usage
mode=$1
[[ $(git branch --show-current) == master ]] || fail "Switch to master first."

# Check both endpoints, including multiple push URLs, before any network operation.
fetch_url=$(git remote get-url origin) || fail "origin is not configured."
push_urls=$(git remote get-url --push --all origin) || fail "origin has no push URL."
case "$fetch_url" in
    https://github.com/yoshidax/folzio-dev.git|https://github.com/yoshidax/folzio-dev|git@github.com:yoshidax/folzio-dev.git|git@github.com:yoshidax/folzio-dev) ;;
    *) fail "Unexpected origin fetch URL: $fetch_url" ;;
esac
case "$push_urls" in
    https://github.com/yoshidax/folzio-dev.git|https://github.com/yoshidax/folzio-dev|git@github.com:yoshidax/folzio-dev.git|git@github.com:yoshidax/folzio-dev) ;;
    *) fail "Unexpected origin push URL(s): $push_urls" ;;
esac

merge_head=$(git rev-parse --git-path MERGE_HEAD)
case "$mode" in
    --continue)
        [[ -f "$merge_head" ]] || fail "No merge is in progress."
        git diff --quiet || fail "Resolve and stage all changes before continuing."
        [[ -z $(git ls-files --others --exclude-standard) ]] || fail "Untracked files are present."
        ;;
    --push-only)
        [[ ! -f "$merge_head" ]] || fail "A merge is in progress; resolve it first."
        [[ -z $(git status --porcelain) ]] || fail "The working tree is not clean."
        ;;
    -*) usage ;;
    *)
        [[ ! -f "$merge_head" ]] || fail "A merge is in progress; resolve it first."
        [[ -z $(git status --porcelain) ]] || fail "The working tree is not clean."
        git show-ref --verify --quiet "refs/heads/$mode" || fail "Local branch not found: $mode"
        [[ "$mode" != master ]] || fail "Choose a branch other than master."
        ;;
esac

git fetch --no-tags origin refs/heads/master:refs/remotes/origin/master || fail "Could not fetch origin/master; nothing was pushed."
git merge-base --is-ancestor refs/remotes/origin/master HEAD || fail "origin/master is ahead or diverged; reconcile it before proceeding."

case "$mode" in
    --continue)
        if ! GIT_EDITOR=true git merge --continue; then
            fail "Merge is incomplete; resolve the problem and run --continue."
        fi
        ;;
    --push-only) ;;
    *)
        if ! git merge --no-edit -- "$mode"; then
            fail "Merge did not complete. Resolve conflicts and run --continue, or abort the merge."
        fi
        ;;
esac

commit=$(git rev-parse HEAD)
if ! git push origin "$commit:refs/heads/master"; then
    fail "Local master is at $commit, but push failed. After fixing the cause, run scripts/dev/merge-to-master.sh --push-only."
fi
[[ $(git rev-parse refs/heads/master) == "$commit" ]] || fail "master changed during push; inspect its state and retry --push-only."
echo "master backed up to origin/master: $commit"
