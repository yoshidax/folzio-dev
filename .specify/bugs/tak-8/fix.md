# Bug Fix: Replacing an ancestor of a transfer source

- **Slug**: tak-8 (from conversation context)
- **Fixed**: 2026-11-01
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Before trashing a replacement target, reject it if it contains or is the same item as any source in the operation. The failure has a dedicated localized explanation.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioCore/Operations/FileOperationService.swift` | modified | Checks canonical containment and item identity before Trash. |
| `Sources/FolzioCore/Operations/OperationFailureReason.swift` | modified | Adds an actionable failure reason. |
| `Sources/FolzioLocalization/CoreText.swift`, `TextKey.swift`, and English/Japanese strings | modified | Displays the reason in both supported languages. |
| `Tests/FolzioCoreTests/FileOperationServiceTests.swift` | modified | Covers both transfer kinds, symlink paths, multiple sources, keep-both and prefix boundaries. |

## Tests Added or Updated

- `refusesReplacingSourceAncestor` checks copy and move, canonicalized paths, preserved contents and keep-both.
- `refusesReplacingAncestorOfAnotherSource` checks protection of another selected source.
- `allowsReplacingSimilarlyNamedSibling` checks path-component boundaries and ordinary replacement.

## Local Verification

Static checks passed: no-network, English comments, skill sync, git-push unit tests, `git diff --check`, and README sync against `origin/master`. README sync against `master` could not run because the local branch does not exist. Swift build/test and GUI checks were not run under Cloud repository rules.

## Deviations from Assessment

Added a dedicated failure reason and localization so the user sees why replacement was refused; this expands the listed files to the failure model and localization resources.

## Follow-ups

Run macOS CI and the maintainer GUI smoke and reproduction checks.
