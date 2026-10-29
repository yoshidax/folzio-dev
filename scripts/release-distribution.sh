#!/bin/bash
# Prepare a release from the public repository, or create an unpublished GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
usage() {
    echo "Usage: $0 prepare VERSION BUILD_NUMBER OWNER/REPO [PUBLIC_REPO]" >&2
    echo "       $0 draft VERSION OWNER/REPO NOTES_FILE [PUBLIC_REPO]" >&2
    exit 2
}
fail() { echo "release: $*" >&2; exit 1; }
[[ $# -ge 1 ]] || usage
operation="$1"
shift
case "$operation" in
    prepare) [[ $# -ge 3 && $# -le 4 ]] || usage; version="$1"; build_number="$2"; repo="$3"; public_repo="${4:-../folzio-oss}" ;;
    draft) [[ $# -ge 3 && $# -le 4 ]] || usage; version="$1"; repo="$2"; notes="$3"; public_repo="${4:-../folzio-oss}" ;;
    *) usage ;;
esac
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Version must be X.Y.Z"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "Repository must be OWNER/REPO"
tag="v$version"
asset="Folzio-$tag-macos-arm64.zip"
output="$root/.build/releases/$tag"
[[ -d "$public_repo/.git" ]] || fail "Public repository not found: $public_repo"
public_repo="$(cd "$public_repo" && pwd -P)"
[[ -z "$(git -C "$public_repo" status --porcelain)" ]] || fail "Public repository has uncommitted or untracked changes"
[[ "$(git -C "$public_repo" branch --show-current)" == main ]] || fail "Public repository must be on main"
commit="$(git -C "$public_repo" rev-parse HEAD^{commit})"
remote="$(git -C "$public_repo" remote get-url origin)"
case "$remote" in
    "https://github.com/$repo"|"https://github.com/$repo.git"|"git@github.com:$repo"|"git@github.com:$repo.git"|"ssh://git@github.com/$repo"|"ssh://git@github.com/$repo.git") ;;
    *) fail "origin does not match github.com/$repo" ;;
esac
remote_main="$(git -C "$public_repo" ls-remote --exit-code origin refs/heads/main | awk '{print $1}')" || fail "Cannot read remote main"
[[ "$remote_main" == "$commit" ]] || fail "Public HEAD does not match origin/main; commit and push first"
if [[ "$operation" == prepare ]]; then
    [[ "$build_number" =~ ^[0-9]+$ ]] || fail "Build number must contain digits only"
    [[ "$(uname -m)" == arm64 ]] || fail "Release builds require an Apple silicon Mac"
    [[ ! -e "$output" ]] || fail "Output already exists: $output"
    mkdir -p "$root/.build/releases"
    tmp="$(mktemp -d "$root/.build/releases/.prepare.XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT
    mkdir "$tmp/source" "$tmp/result"
    git -C "$public_repo" archive "$commit" | tar -xf - -C "$tmp/source"
    (cd "$tmp/source" && FOLZIO_VERSION="$version" FOLZIO_BUILD_NUMBER="$build_number" scripts/make-app.sh)
    app="$tmp/source/.build/Folzio.app"
    [[ "$(lipo -archs "$app/Contents/MacOS/Folzio")" == arm64 ]] || fail "App executable is not arm64-only"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]] || fail "App version mismatch"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$build_number" ]] || fail "App build number mismatch"
    codesign --verify --deep --strict "$app"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$tmp/result/$asset"
    mkdir "$tmp/unpacked"
    ditto -x -k "$tmp/result/$asset" "$tmp/unpacked"
    codesign --verify --deep --strict "$tmp/unpacked/Folzio.app"
    [[ "$(lipo -archs "$tmp/unpacked/Folzio.app/Contents/MacOS/Folzio")" == arm64 ]] || fail "Unpacked app is not arm64-only"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$tmp/unpacked/Folzio.app/Contents/Info.plist")" == "$version" ]] || fail "Unpacked app version mismatch"
    (cd "$tmp/result" && shasum -a 256 "$asset" > SHA256SUMS)
    printf '%s\n%s\n%s\n%s\n' "$commit" "$repo" "$version" "$build_number" > "$tmp/result/release-info.txt"
    mv "$tmp/result" "$output"
    echo "Prepared $output from $commit"
else
    [[ -f "$notes" ]] || fail "Release notes file not found: $notes"
    [[ -d "$output" && -f "$output/$asset" && -f "$output/SHA256SUMS" && -f "$output/release-info.txt" ]] || fail "Prepared release files are missing"
    info_commit="$(sed -n '1p' "$output/release-info.txt")"
    info_repo="$(sed -n '2p' "$output/release-info.txt")"
    info_version="$(sed -n '3p' "$output/release-info.txt")"
    info_build="$(sed -n '4p' "$output/release-info.txt")"
    [[ "$info_commit" == "$commit" && "$info_repo" == "$repo" && "$info_version" == "$version" && "$info_build" =~ ^[0-9]+$ ]] || fail "Release metadata does not match public HEAD and repository"
    [[ "$(wc -l < "$output/SHA256SUMS" | tr -d ' ')" == 1 ]] || fail "Invalid checksum file"
    expected="$(cd "$output" && shasum -a 256 "$asset")"
    [[ "$(cat "$output/SHA256SUMS")" == "$expected" ]] || fail "Checksum does not match ZIP"
    refs="$(git -C "$public_repo" ls-remote --exit-code origin "refs/tags/$tag" "refs/tags/$tag^{}")" || fail "Remote tag is missing"
    tag_commit="$(printf '%s\n' "$refs" | awk -v ref="refs/tags/$tag^{}" '$2 == ref {print $1}')"
    [[ -n "$tag_commit" ]] || tag_commit="$(printf '%s\n' "$refs" | awk -v ref="refs/tags/$tag" '$2 == ref {print $1}')"
    [[ "$tag_commit" == "$commit" ]] || fail "Remote tag does not point to public HEAD"
    tmp="$(mktemp -d "$root/.build/releases/.verify.XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT
    ditto -x -k "$output/$asset" "$tmp"
    app="$tmp/Folzio.app"
    [[ "$(lipo -archs "$app/Contents/MacOS/Folzio")" == arm64 ]] || fail "ZIP executable is not arm64-only"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]] || fail "ZIP app version mismatch"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$info_build" ]] || fail "ZIP build number mismatch"
    codesign --verify --deep --strict "$app"
    gh release create "$tag" "$output/$asset" "$output/SHA256SUMS" --repo "github.com/$repo" --verify-tag --draft --title "Folzio $tag" --notes-file "$notes"
    echo "Draft created for $repo $tag; review it before publishing."
fi
