# Bug Fix: Public workflow placement in publish.sh misses listing failures and name collisions

- **Slug**: tak-60
- **Fixed**: 2026-11-03
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

`scripts/dev/publish.sh` now writes the `git ls-tree` listing of `scripts/dev/oss-workflows/` to a temporary file and stops
before syncing when the listing fails, instead of reading it through process substitution and treating a failure as "no workflows".
It also stops before placing files when two managed workflow names differ only in case, and checks each placed file by its
object ID instead of reading the blob a second time. The test fixture now matches the real repository's `.github/`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `scripts/dev/publish.sh` | modified | Listing written to `$listing` (outside the export directory, removed by the `EXIT` trap); explicit error when `git ls-tree` fails |
| `scripts/dev/publish.sh` | modified | Case-insensitive name collision check with `tr` (bash 3.2 has no `${name,,}`); the message names both workflows |
| `scripts/dev/publish.sh` | modified | Content check compares `git hash-object --no-filters` of each placed file with the blob ID from the listing; the count check is kept |
| `scripts/dev/tests/test_publish_folzio.py` | modified | `PublishFixture` commits `.github/pull_request_template.md`; helpers `fail_git`, `stage_index_only`, `published_github_files`; `commit(stage=False)` |
| `scripts/dev/tests/test_publish_folzio.py` | added tests | Listing failure and case-only name collision |

## Diff Highlights

```bash
if ! git ls-tree -z HEAD -- "$oss_workflows/" >"$listing"; then
    echo "$oss_workflows/ の一覧を取得できません" >&2
    exit 1
fi
...
done <"$listing"
```

```bash
placed_file="$tmp/.github/workflows/${workflow_names[i]}"
if [[ ! -f "$placed_file" || "$(git hash-object --no-filters -- "$placed_file")" != "${workflow_ids[i]}" ]]; then
```

## Tests Added or Updated

- `test_publish_folzio.py::WorkflowPublishTests::test_publish_stops_before_sync_when_managed_workflows_cannot_be_listed` —
  with a `git` wrapper that fails only `ls-tree`, publish exits non-zero with the managed directory in stderr; the target keeps its
  published `release.yml` and the previous `README.md`.
- `test_publish_folzio.py::WorkflowPublishTests::test_publish_rejects_workflow_names_differing_only_in_case_before_sync` —
  `Release.yml` and `release.yml` (staged in the index with `skip-worktree`, so the test also runs on case-insensitive file systems)
  make publish exit non-zero with both names in stderr before syncing.
- `test_publish_folzio.py::WorkflowPublishTests::test_publish_excludes_development_workflows` and
  `::test_publish_removes_workflows_when_none_are_managed` — with the template in the fixture, they check that `.github/` in the target
  contains no files instead of checking that it does not exist (the empty `.github/` is accepted, as decided in the assessment).

## Local Verification

- `python3 -I -m unittest discover -s scripts/dev/tests -p "test_publish_folzio.py"` before the fix → the two new tests failed
  (`0 == 0 : 公開用 workflow はありません` and `0 == 0 : 公開用 workflow: Release.yml release.yml`); the other 9 passed.
- The same command after the fix → `Ran 11 tests ... OK` (Linux, Cloud, with `rsync` installed by `apt-get` for this session and `swift` stubbed).
- Content check: a modified copy of the fixed script that appends to the placed `release.yml` before the check exits 1 with
  "書き出しの .github/workflows/release.yml が scripts/dev/oss-workflows/ の内容と一致しません" and does not sync.
- `scripts/check-no-network.sh`, `scripts/check-readme-sync.sh master`, `scripts/dev/check-english-comments.sh`,
  `scripts/dev/check-skill-sync.sh`, `scripts/dev/check-spec-ids.sh` → exit 0.
  `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` → OK.
- Not run in Cloud: macOS bash 3.2, a case-insensitive file system, `swift build` / `swift test` (CI), and the other publish and
  distribution tests in `scripts/dev/tests` (maintainer's local machine).

## Deviations from Assessment

None.

## Follow-ups

- Run `scripts/dev/tests` on macOS (bash 3.2, APFS) as part of the maintainer's verification gate.
- Items 2 (empty `.github/` in the target) and 5 (uppercase extensions) are left as specified, per the maintainer's decision.
