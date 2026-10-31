# Bug Verification: Replacing an ancestor of a transfer source

- **Slug**: tak-8 (from conversation context)
- **Tested**: 2026-11-01
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial

## Summary

Regression tests were added but could not be executed in this Cloud environment. The original GUI reproduction has not been performed; the fix is not yet verified end-to-end.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| GUI reproduction and startup smoke | Maintainer on macOS | not-run | GUI unavailable. |
| Swift build and tests | macOS CI | not-run | Cloud repository rules require CI. |
| Network API check | `scripts/check-no-network.sh` | pass | No network API references. |
| README sync | `scripts/check-readme-sync.sh origin/master` | pass | Local `master` ref is absent. |
| English comments | `scripts/dev/check-english-comments.sh` | pass | English-only. |
| Skill sync | `scripts/dev/check-skill-sync.sh` | pass | In sync. |
| Push policy tests | `python3 -m unittest discover -s scripts/dev/tests -p 'test_check_git_push.py'` | pass | 3 tests. |
| Diff whitespace | `git diff --check` | pass | No errors. |

## Residual Risks

- Swift compilation and behavioral tests have not been run; filesystem races remain possible between checking and trashing.
- Original GUI reproduction and startup smoke require macOS.

## Recommendation

Run macOS CI and have the maintainer check startup and the original copy/move reproduction before considering the fix verified.
