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
| `Sources/FolzioCore/Model/FolderNavigation.swift` | modified | `containsFolderOrAncestor(of:in:)`、`nearestExistingAncestor(of:isFolder:)`、`staysInsideRoot(from:to:roots:)` を追加 |
| `Sources/FolzioCore/Browser/BrowserModel.swift` | modified | `handleFileSystemEvent` が祖先の通知でも存在を確かめ、最も近い祖先へ移る。stat を `Task.detached` に移す。根の外へは移らず「見つかりません」にする（`knownRoots`）。`handleVolumesChanged()` を追加 |
| `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` | modified | ボリュームの変更で、検索中に限らず `handleVolumesChanged()` を呼ぶ |
| `Tests/FolzioCoreTests/BrowserModelFolderTests.swift` | modified | 回帰テスト9件 |
| `Tests/FolzioCoreTests/BrowserModelArchiveTests.swift` | modified | zip を含むフォルダの改名、zip の中でのボリュームの取り外しの回帰テスト |
| `Tests/FolzioCoreTests/FolderNavigationTests.swift` | modified | 追加した純粋関数のテスト5件 |

## Tests Added or Updated

- `BrowserModelFolderTests.renamingDisplayedFolderReportedAsParentChange` — 親だけの通知で、改名された表示中のフォルダから親へ移る（A）。
- `BrowserModelFolderTests.deletingAncestorMovesToNearestExistingFolder` — 祖先の削除で最も近い祖先へ移る（B、保守者の再現）。
- `BrowserModelFolderTests.deletingAncestorWithContentsSkipsVanishedParents` — `rm -rf` 相当で消えた親を飛ばす。
- `BrowserModelFolderTests.ancestorChangeKeepsExistingFolder` — 祖先の変更だけでは場所・選択・プレビューを保つ。
- `BrowserModelFolderTests.siblingWithSharedPrefixIsIgnored` — 前方一致だけの兄弟を祖先と誤認しない。
- `BrowserModelFolderTests.vanishedVolumeRootShowsNotFound` — 根（ボリューム）ごと消えたとき、根の外（`/Volumes` 相当）へ移らず「見つかりません」にする（E4 の退行）。
- `BrowserModelFolderTests.ancestorChangeKeepsNotFoundDisplay` — 「見つかりません」の表示中は、祖先の通知で移らない。
- `BrowserModelFolderTests.volumeRemovalShowsNotFound` — ボリュームの取り外しで「見つかりません」にし、選択・プレビュー・履歴の場所を空にする（E1〜E3）。
- `BrowserModelFolderTests.volumeChangeKeepsExistingFolder` — 表示中のフォルダが残っていれば、ボリュームの変更で表示を変えない。
- `BrowserModelArchiveTests.renamedContainingFolderLeavesArchive` — zip を含むフォルダの改名で zip から出る（C）。
- `BrowserModelArchiveTests.volumeRemovalInsideArchiveShowsNotFound` — zip の中でボリュームが外れたら、zip を閉じて「見つかりません」にする。
- `FolderNavigationTests` — 祖先の判定（path components、`/private`）、最も近い祖先の探索、根の内側の判定。

## Local Verification

- Cloud の静的チェックは `test.md` を参照。Swift のビルド・テストは macOS CI、GUI は保守者の確認が必要。

## Deviations from Assessment

- 保守者の確認により、E（外部ボリュームの取り外し）をこの Issue で扱い、最初の修正による `/Volumes` への移動（退行）を直した（assessment の「追記」）。

## Follow-ups

- なし（再マウント後に自動で元の表示へ戻さないことを、保守者が決定した）。
