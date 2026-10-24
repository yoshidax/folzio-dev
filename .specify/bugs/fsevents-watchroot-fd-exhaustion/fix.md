# Bug Fix: フォルダの監視がファイルディスクリプタを使い切り、描画中に落ちる

- **Slug**: fsevents-watchroot-fd-exhaustion
- **Fixed**: 2026-10-25
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

`FileSystemWatcher` の FSEvents のストリームを2つに分け、ツリーの行などの通常のフォルダ（`folders`）の監視から
`kFSEventStreamCreateFlagWatchRoot` を外した。WatchRoot は検索の起点（`subtrees`）のストリームにだけ付ける（R38 のまま）。
あわせて、監視の対象が変わった側のストリームだけを作り直すようにした。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/MediaViewerCore/FileSystem/FileSystemWatcher.swift` | modified | `stream` を `folderStream`（WatchRoot なし）と `subtreeStream`（WatchRoot あり）に分けた。`rebuildStream` を `rebuildFolderStream`・`rebuildSubtreeStream`・`makeStream(paths:watchesRoot:)` に分け、`applyFolders` は変わった側だけを作り直す。`stopStream` は両方を止める（`deinit` は従来どおり `stopStream` を呼ぶ） |
| `Tests/MediaViewerCoreTests/FileSystemWatcherTests.swift` | added tests | ディスクリプタの使用量の回帰テストを2つ追加 |

## Diff Highlights (optional)

```swift
// 変わった側だけを作り直す。ツリーの操作のたびに起点のストリームを作り直さない
if foldersChanged {
    rebuildFolderStream()      // makeStream(paths:, watchesRoot: false)
}
if subtreesChanged {
    rebuildSubtreeStream()     // makeStream(paths:, watchesRoot: true)
}
```

イベントの処理（`handleEventPaths`・`subtreeFolders`・`scheduleEmit`）は変えていない。2つのストリームは同じ `queue` と
コールバックを使うため、どちらから届いたイベントも従来と同じ判定と debounce を通る。

## Tests Added or Updated

- `FileSystemWatcherTests.swift::watchingManyFoldersDoesNotExhaustDescriptors` — 100 フォルダを集合を変えながら4回作り直しても、
  開いているディスクリプタ（`/dev/fd` の数）の増加が 100 未満。修正前は +2,145 で失敗することを確かめた
- `FileSystemWatcherTests.swift::subtreeWatchRootCostsOnlyForTheRoot` — 100 フォルダと起点1つを監視し、`folders` だけを変えて
  作り直しても、増加が 150 未満（起点の WatchRoot の分だけ）。修正前は +4,419 で失敗することを確かめた
- 閾値は、ほかのテストが同じプロセスで同時にファイルを開く分の余裕を見て、修正前の値（1,000 以上）と十分に離した

## Local Verification

- Commands run:
  - `swift test --filter "watchingManyFoldersDoesNotExhaustDescriptors|subtreeWatchRootCostsOnlyForTheRoot"`（修正前）→ 2件とも失敗（+2,145、+4,419）
  - `swift test --filter FileSystemWatcher` → 12 件すべて成功（既存の 10 件: 追加・名前変更・削除の通知、外部変更の一覧への反映、
    subtrees の配下の通知、隠しフォルダの除外、最大の遅延、`/private` の扱い、起点自身・親の削除と移動の通知）
  - `swift build` → 成功
  - `swift test` → Core 506 件、性能 17 件すべて成功
  - `scripts/check-no-network.sh` → no network API references in Sources
- Manual checks: GUI の確認は `/speckit-bug-test` で行う（1〜3 個のフォルダを展開し、フォルダの削除・名前の変更を繰り返しても
  落ちないこと、システムログに `Too many open files` が出ないこと）

## Deviations from Assessment

なし。

## Follow-ups

- 起動時に `setrlimit(RLIMIT_NOFILE)` でソフト上限を引き上げる保険（assessment の Alternatives）は今回入れていない。必要になれば別に扱う
- 003（ツリーのフォルダの名前の変更と削除）のブランチは、この修正を master にマージした後に rebase し、GUI の確認を再開する
