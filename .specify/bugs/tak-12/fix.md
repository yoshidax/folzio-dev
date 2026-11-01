# Bug Fix: 表示中のフォルダ自体・祖先の外部改名・削除が一覧に反映されない

- **Slug**: tak-12（会話の診断から継承）
- **Fixed**: 2026-11-01
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

通常閲覧で、現在のフォルダ自体か祖先が通知されたら、現在のフォルダの存在をメインスレッド外で確かめ、消えていれば存在する最も近い祖先へ移る。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioCore/Model/FolderNavigation.swift` | modified | `containsFolderOrAncestor(of:in:)` と `nearestExistingAncestor(of:isFolder:)` を追加 |
| `Sources/FolzioCore/Browser/BrowserModel.swift` | modified | `handleFileSystemEvent` が祖先の通知でも存在を確かめ、最も近い祖先へ移る。stat を `Task.detached` に移す |
| `Tests/FolzioCoreTests/BrowserModelFolderTests.swift` | modified | 回帰テスト5件 |
| `Tests/FolzioCoreTests/BrowserModelArchiveTests.swift` | modified | zip を含むフォルダの改名の回帰テスト |
| `Tests/FolzioCoreTests/FolderNavigationTests.swift` | modified | 追加した純粋関数のテスト4件 |

## Tests Added or Updated

- `BrowserModelFolderTests.renamingDisplayedFolderReportedAsParentChange` — 親だけの通知で、改名された表示中のフォルダから親へ移る（A）。
- `BrowserModelFolderTests.deletingAncestorMovesToNearestExistingFolder` — 祖先の削除で最も近い祖先へ移る（B、保守者の再現）。
- `BrowserModelFolderTests.deletingAncestorWithContentsSkipsVanishedParents` — `rm -rf` 相当で消えた親を飛ばす。
- `BrowserModelFolderTests.ancestorChangeKeepsExistingFolder` — 祖先の変更だけでは場所・選択・プレビューを保つ。
- `BrowserModelFolderTests.siblingWithSharedPrefixIsIgnored` — 前方一致だけの兄弟を祖先と誤認しない。
- `BrowserModelArchiveTests.renamedContainingFolderLeavesArchive` — zip を含むフォルダの改名で zip から出る（C）。
- `FolderNavigationTests` — 祖先の判定（path components、`/private`）と最も近い祖先の探索。

## Local Verification

- Cloud の静的チェックは `test.md` を参照。Swift のビルド・テストは macOS CI、GUI は保守者の確認が必要。

## Deviations from Assessment

- なし。

## Follow-ups

- E（外部ボリュームの取り外し中に表示しているとき）は別の Issue で扱う。
