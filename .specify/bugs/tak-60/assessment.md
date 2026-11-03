# Bug Assessment: Public workflow placement in publish.sh misses listing failures and name collisions

- **Slug**: tak-60
- **Created**: 2026-11-03
- **Source**: [TAK-60](https://linear.app/takyoshida/issue/TAK-60) (host: linear.app; allowlisted; read through the Linear connector)
- **Verdict**: valid (items 1, 2, 5 reproduced in this session; items 3 and 4 confirmed by inspection)
- **Severity**: medium — when the listing fails, publish exits 0 after deleting every public workflow in the target.
  The deletion is staged, not committed, and the maintainer reviews `git status` before committing, so it is recoverable.
  The trigger (a failing `git ls-tree`, such as a corrupt object) is rare.

## Report (summarized)

A code review of the public workflow placement in `scripts/dev/publish.sh` (lines 36–81, added by TAK-40 / #45) found five issues:

1. The `git ls-tree` listing of `scripts/dev/oss-workflows/` is read through process substitution, so its failure is not caught
   by `set -e` / `pipefail`. Publish continues as if there were no workflows and `rsync --delete` removes the public workflows.
2. The test fixture differs from the real repository. In the real repository `git archive HEAD` emits an empty `.github/`,
   because `.github/pull_request_template.md` and `.github/workflows` are both `export-ignore`. The assertions that `.github`
   does not exist only pass because the fixture has no `pull_request_template.md`.
3. The content check (lines 71–76) reads the same blob a second time and compares it with the file written from that blob.
   It cannot fail on its own.
4. On a case-insensitive file system (default APFS), `Release.yml` and `release.yml` overwrite each other in the temporary directory.
   Publish stops at the count check, but the message does not say that a name collision is the cause.
5. The extension match is case-sensitive, so `Release.YML` is silently ignored.

## Symptom

If listing the managed workflows fails, publish prints "公開用 workflow はありません", deletes the public workflows from the target,
and exits 0 with the deletion staged. Expected: stop with a non-zero status before syncing to the target.

## 仕様との照合

| 指摘 | 該当 ID | 判定 |
|---|---|---|
| 1 | FR-292、FR-293、`specs/product/contracts/scripts.md`（置いた workflow の名前の集合と内容が管理元と一致しなければ同期の前に非ゼロ終了） | 実装が仕様に反している。管理元を読めないまま「定義がない」と扱い、管理元と一致しない公開先へ同期する。fix へ進む |
| 3 | FR-293、契約の同じ項 | 実装が仕様に反してはいないが、内容の確認が実質的に働いていない。fix で、内容の確認の意味を保ったまま照合を整理する |
| 4 | FR-293 | 実装は仕様どおりに止まる。fix で、原因（名前の衝突）を示して書き出しの前に止まるようにする |
| 2 | FR-291、FR-294 | テストが実際の構成を確かめていない（FR-294 の回帰検証の不備）。fix でフィクスチャを実際の構成にそろえる。空の `.github/` を公開先に残すことは仕様が定めておらず、保守者の判断（2026-11-03）で許容し、動作と仕様は変えない |
| 5 | FR-291、契約の同じ項 | 仕様どおり（「`.yml` または `.yaml` で終わる」）。保守者の判断（2026-11-03）で今回は扱わない |

## Reproduction

Reproduced on Linux in this session with the `PublishFixture` of `scripts/dev/tests/test_publish_folzio.py`, with `rsync` installed
and `swift` stubbed. Each run places `.github/workflows/release.yml` in the target before publishing.

1. Item 1: commit `scripts/dev/oss-workflows/release.yml`, put a `git` wrapper on `PATH` that fails only for `ls-tree`, and publish.
   Result: exit code 0, "公開用 workflow はありません", and the target's `.github/workflows/release.yml` is deleted.
2. Item 2: commit `.github/pull_request_template.md` (excluded by the real `.gitattributes`) and publish.
   Result: an empty `.github/` remains in the target. `git archive HEAD | tar -t | grep '^\.github'` in the real repository prints `.github/`.
3. Item 5: commit only `scripts/dev/oss-workflows/Release.YML` and publish.
   Result: exit code 0, "公開用 workflow はありません", and the target's workflow is deleted.
4. Item 4 needs a case-insensitive file system and was not run here (Linux is case-sensitive). By inspection, line 58 writes both
   names to the same file on APFS, and line 67 reports "1 件、管理元は 2 件" without naming the collision.

## Suspected Code Paths

- `scripts/dev/publish.sh:53` — `done < <(git ls-tree -z HEAD -- "$oss_workflows/")`: the exit status of the process substitution
  is discarded, so a failed listing looks the same as an empty one.
- `scripts/dev/publish.sh:55-60` — writes each blob to `$tmp/.github/workflows/<name>` without checking for names that differ only in case.
- `scripts/dev/publish.sh:63-76` — the count check catches an overwritten name only by count, and the content check re-reads the
  blob that was just written.
- `scripts/dev/tests/test_publish_folzio.py:84-147` (`PublishFixture`) — has no `.github/pull_request_template.md`.
- `scripts/dev/tests/test_publish_folzio.py:171`, `:218` — assert that `.github` does not exist.

## Root Cause Hypothesis

Confidence: high. Bash does not propagate the exit status of a process substitution, and `set -e` / `pipefail` do not cover it,
so the loop sees end of input and leaves `workflow_count` at 0. The later count check compares 0 with 0 and passes.
The collision and content issues come from the placement and verification being written as separate passes over the same data,
with no check that the names are distinct on the target file system.

## Proposed Remediation

**Preferred**:

- Write the `git ls-tree -z` output to a temporary file outside the export directory as a plain command, so `set -e` stops publish
  on failure with an explicit message, then read the loop from that file. The temporary file is removed by the `EXIT` trap.
  A missing `scripts/dev/oss-workflows/` still lists nothing with exit code 0 and keeps meaning "no workflows".
- While collecting the names, compare each lowercased name (with `tr`, since macOS bash 3.2 has no `${name,,}`) with the earlier
  ones, and stop before writing any file with a message that names both colliding names.
- Keep the count check for extra or missing files, and replace the second `git cat-file` with
  `git hash-object --no-filters` on each placed file compared with the blob ID from the listing. This keeps the name and content
  check of FR-293, reads each blob once, and checks the written file independently of how it was written.

**Alternatives**:

- Capture the listing with `listing="$(git ls-tree ...)"`: bash variables cannot hold the NUL separators of `-z`, so this would
  require dropping `-z` and handling quoted path names. Rejected.
- Check `wait $!` after the loop: process substitution PIDs are only waitable on bash 4.4 and later, not on macOS bash 3.2. Rejected.

**Files likely to change**:

- `scripts/dev/publish.sh`
- `scripts/dev/tests/test_publish_folzio.py`

**Tests to add or update**:

- Listing failure: a `git` wrapper that fails `ls-tree` makes publish exit non-zero before syncing; the target's existing
  `.github/workflows/release.yml` and `obsolete.txt` remain and `README.md` is not synced.
- Name collision: `Release.yml` and `release.yml` in the managed directory make publish exit non-zero before syncing,
  with both names in stderr. This runs the same way on case-sensitive and case-insensitive file systems.
- `PublishFixture` commits `.github/pull_request_template.md` like the real repository, and the two assertions at lines 171 and 218
  check that `.github` in the target contains no files instead of checking that it does not exist.

## Risks & Considerations

- `publish.sh` must keep working with macOS bash 3.2 (no `${var,,}`, no `wait` on process substitutions, empty arrays under `set -u`).
- The listing file must not be placed inside the export directory, or it would be synced to the public repository.
- `scripts/dev/tests` publish tests assume macOS and `rsync`; in Cloud they run only after installing `rsync`.
  The maintainer runs them locally as part of the verification gate.
- The behavior of item 5 and the empty `.github/` of item 2 are left unchanged by decision; the tests document the empty directory.

## Open Questions

- None. Items 2 and 5 were decided by the maintainer on 2026-11-03 (see 仕様との照合).
