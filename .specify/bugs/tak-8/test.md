# Bug Verification: Replacing an ancestor of a transfer source

- **Slug**: tak-8 (from conversation context)
- **Tested**: 2026-11-03
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: pass

## Summary

Regression tests pass locally and in macOS CI. The maintainer ran the startup smoke and the original copy/move reproduction on macOS, and the replacement was rejected without moving the parent folder to the Trash.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| GUI reproduction and startup smoke | Maintainer on macOS | pass | Original reproduction no longer trashes the parent. |
| Swift build and tests | `swift build`, `swift test` (local); macOS CI | pass | `FileOperationServiceTests` 40 passed. A full local run showed 2 ThumbnailProviderTests cache failures that passed when run alone. |
| Network API check | `scripts/check-no-network.sh` | pass | No network API references. |
| README sync | `scripts/check-readme-sync.sh master` | pass | In sync. |
| English comments | `scripts/dev/check-english-comments.sh` | pass | English-only. |
| Skill sync | `scripts/dev/check-skill-sync.sh` | pass | In sync. |
| Push policy tests | `python3 -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'` | pass | 3 tests. |
| Diff whitespace | `git diff --check` | pass | No errors. |

## Residual Risks

- Filesystem races remain possible between checking and trashing; the guard targets the deterministic reported scenario.

## Recommendation

Ready to merge.
