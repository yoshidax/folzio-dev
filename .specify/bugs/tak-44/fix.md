# Bug Fix: サムネイル形式でリスト内のファイルをリスト内のフォルダへドラッグ&ドロップできない

- **Slug**: tak-44
- **Fixed**: 2026-11-01
- **Assessment**: ./assessment.md
- **Status**: applied（ビルドとテストは CI、GUI の確認は保守者のローカルで行う。Cloud では未実行）

## Summary

サムネイル画像の `NSImageView` をドラッグの受け付け先から外し、項目の上のドロップがコレクションビューの `validateDrop` に届くようにした。
あわせて、`validateDrop` の宛先を、提案された操作ではなくポインタの下の項目から求め、フォルダ項目なら `.on` に付け替えるようにした。

## 保守者による確認（assessment の後、2026-11-01）

- 診断と修正の案を承認。リスト形式とツリーのアイコンへの同じ対処は入れない。
- フォルダ項目の**名前の部分**へのドロップは**できる**。サムネイル形式から**ツリー**のフォルダへのドロップも**できる**。
  - ドラッグの開始と、`validateDrop` / `acceptDrop` / `InternalDrag` の非同期の検証は機能している。画像の部分だけが失敗するため、
    assessment の仮説 A（`NSImageView` がドロップを横取りする）が原因と判断した。仮説 B（非同期の検証の再問い合わせ）は、名前の部分で成功することから、原因ではないと判断した。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/FolzioApp/FileList/ThumbnailModeView.swift` | modified | `ThumbnailItemView.loadView` で `thumbnailImageView.unregisterDraggedTypes()`。`validateDrop` でポインタの下の項目を宛先にし、`.on` に付け替える |
| `Tests/FolzioAppTests/ThumbnailDropTargetTests.swift` | added test | 項目の画像ビューにドラッグの受け付け先の登録がないこと |

## Diff Highlights

```swift
// ThumbnailItemView.loadView
thumbnailImageView.unregisterDraggedTypes()

// validateDrop
let location = collectionView.convert(info.draggingLocation, from: nil)
guard !model.isBrowsingArchive,
      let indexPath = collectionView.indexPathForItem(at: location) else { return [] }
...
proposedIndexPath.pointee = indexPath as NSIndexPath
dropOperation.pointee = .on
return InternalDrag.operation(info, destination: model.listing.files[index].url)
```

- 項目間・背景（ポインタの下に項目がない）、ファイル、zip 内は、従来どおり受け付けない（FR-163）。`acceptDrop` は `.on` を前提とするまま変更していない。
- 宛先の付け替えは、検証の結果を待たずに行う。同じ項目の上では、端で `.before` が提案されても宛先が変わらない。返す操作が空の間は、ドロップは受け付けられない。

## Tests Added or Updated

- `Tests/FolzioAppTests/ThumbnailDropTargetTests.swift::thumbnailImageIgnoresDrops`（フォルダ・ファイルの2通り）— 項目の `imageView` の
  `registeredDraggedTypes` が空であること。`unregisterDraggedTypes()` の削除を検出する。

## Local Verification

- `scripts/check-no-network.sh` → No network API references in Sources
- `scripts/check-readme-sync.sh master` → in sync
- `scripts/dev/check-english-comments.sh` → English-only
- `scripts/dev/check-skill-sync.sh` → in sync
- `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` → OK
- `swift build` / `swift test`: Cloud に Swift がないため未実行。CI で確認する。
- GUI: 未確認。保守者のローカルで確認する。

## Deviations from Assessment

- assessment は、素の `NSImageView()` に登録があることを前提として確かめる検査を提案していた。保守者の確認で仮説 A の根拠が得られたこと、
  AppKit が登録する時点（初期化時か、ウインドウへの追加時か）に依存して CI が誤って失敗する恐れがあることから、この前提の検査は置かなかった。
  そのため、追加したテストは、AppKit が既定で登録しない環境では、`unregisterDraggedTypes()` を消しても失敗しない。
- assessment の手順 3（仮説 B への対処）は、保守者の確認により不要と判断し、行っていない。

## Follow-ups

- リスト形式（`ListModeView.swift:40`）とツリー（`DirectoryTreeViewController.swift:1933`）の 16pt のアイコンの上のドロップも、同じ理由で
  届かない可能性がある。保守者の判断で今回は対象外。
