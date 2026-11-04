# Bug Assessment: Replacing an ancestor of a transfer source

- **Slug**: tak-8
- **Created**: 2026-11-01
- **Source**: [TAK-8](https://linear.app/takyoshida/issue/TAK-8/コピー移動の置換先が転送yuanの祖先の場合にyuanフォルダがゴミ箱へ移る) (host: linear.app; allowlisted)
- **Verdict**: likely valid, needs reproduction
- **Severity**: high — a confirmed transfer can move an unselected parent and its contents out of their original location. Trash offers recovery, but the unexpected change can affect more than the selected item.

## Report (summarized)

Copying or moving `/root/album/album` to `/root` and choosing replace for `/root/album` can trash the source's parent before the transfer fails. The expected behavior is to reject the unsafe replacement without trashing the parent.

## Symptom

The replacement target can contain the source. Replacing it moves the target to Trash before the source is transferred, removing the source from its original path as well.

## 仕様との照合

実装が仕様に反している: `specs/product/file-operations.md` FR-018 covers folder transfers, FR-024 requires copies not to modify their source, FR-026 requires reporting failures, and SC-075 requires no unintended changes in conflict scenarios. The reported replacement can move an unselected ancestor and the source before failing. Proceed to a fix after review of this diagnosis.

## Reproduction

1. Create `/root/album/album` with identifiable contents.
2. Copy or move the inner `album` to `/root` and choose replace for the existing `/root/album`.
3. Observe whether the outer folder is moved to Trash and the transfer fails. This has not been reproduced in the GUI or through an actual file operation in this session.

## Suspected Code Paths

- `Sources/FolzioCore/Operations/FileOperationService.swift:113` checks whether the destination is the source or its descendant; the reverse containment relationship is not checked.
- `Sources/FolzioCore/Operations/FileOperationService.swift:123` guards replacement of the copy source itself, including aliases and hard links.
- `Sources/FolzioCore/Operations/FileOperationService.swift:214` moves an existing replacement target to Trash before performing the transfer.
- `Sources/FolzioCore/Operations/InternalDropValidation.swift` checks source/destination containment but does not know the chosen conflict resolution.

## Root Cause Hypothesis

Confidence: high from static inspection. For the reported paths, the destination is outside the source and the target is not the same item as the source, so both guards pass. The replace branch trashes the target, which contains the source, before `copyItem` or `moveItem` uses the original source path. Actual behavior remains unverified on macOS.

## Proposed Remediation

**Preferred**: Before any replacement is moved to Trash, reject a target that contains a transfer source, using canonical paths and path-component boundaries. Preserve existing same-item protection and allow safe `keepBoth` and `abort` behavior. Evaluate all sources in a multi-item operation before destructive replacement as well, so replacing a target cannot remove a different selected source. Return an appropriate per-item failure through the existing result mechanism.

**Files likely to change**:
- `Sources/FolzioCore/Operations/FileOperationService.swift`
- `Tests/FolzioCoreTests/FileOperationServiceTests.swift`

**Tests to add or update**:
- Copy and move with an ancestor replacement target fail without changing the parent, source, or contents.
- Canonical/symlink paths and component boundaries are handled correctly; `keepBoth` and ordinary replacement remain usable.
- A replacement target containing another selected source does not remove it.

## Risks & Considerations

- Checks must happen before Trash, and account for aliases without confusing similarly prefixed sibling names.
- Filesystem state can change between validation and mutation; tests should focus on the deterministic reported scenario.
- macOS CI and a maintainer GUI smoke test are needed; this environment cannot validate AppKit behavior.

## Open Questions

- None required for the proposed safety guard. Confirm observed behavior on macOS during verification.
