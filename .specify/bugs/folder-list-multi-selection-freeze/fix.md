# Bug Fix: 10,000 フォルダの複数選択で検索モーダル・右クリックが固まる

- **Slug**: folder-list-multi-selection-freeze
- **Fixed**: 2026-10-27
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

ファイルリストとサムネイル一覧の選択同期で、選択した URL ごとに一覧全体を線形探索していた処理を、
URL → 行番号の対応表を1回だけ作る方式へ変更した。10,000 行・5,000 選択の変換は、ローカル計測で
約 2.43 秒から約 0.008 秒になった。⌘F や右クリックの前にメインスレッドを占有していた処理がなくなる。

## Changes

| File | Change | Notes |
|------|--------|-------|
| `Sources/MediaViewerCore/Model/SelectionIndex.swift` | added | `Set<URL>` と `[URL]` から `IndexSet` を作る純粋関数。重複 URL は最初の行、一覧にない URL は無視 |
| `Sources/MediaViewerApp/FileList/ListModeView.swift` | modified | `urls.firstIndex(of:)` の繰り返しを `SelectionIndex.indexes` に置換 |
| `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift` | modified | 同じ変換を `SelectionIndex.indexes` に置換し、`IndexPath` へ変換 |
| `Tests/MediaViewerCoreTests/SelectionIndexTests.swift` | added | 空入力・通常・重複 URL の回帰 |
| `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` | added test | 10,000 行・5,000 選択の変換が 100ms 未満 |

## Diff Highlights

```swift
public static func indexes(of selected: Set<URL>, in urls: [URL]) -> IndexSet {
    guard !selected.isEmpty, !urls.isEmpty else { return IndexSet() }

    var indexByURL: [URL: Int] = [:]
    indexByURL.reserveCapacity(urls.count)
    for (index, url) in urls.enumerated() where indexByURL[url] == nil {
        indexByURL[url] = index
    }

    var indexes = IndexSet()
    for url in selected {
        if let index = indexByURL[url] {
            indexes.insert(index)
        }
    }
    return indexes
}
```

```swift
// ListModeView.applyModel
let selected = SelectionIndex.indexes(of: model.selection.selected, in: urls)
```

```swift
// ThumbnailModeView.applyModel
let selectedPaths = Set(
    SelectionIndex.indexes(of: model.selection.selected, in: urls).map {
        IndexPath(item: $0, section: 0)
    }
)
```

## Tests Added or Updated

- `SelectionIndexTests.emptyInputs` — 選択・一覧が空のとき空の `IndexSet`
- `SelectionIndexTests.mapsSelectedURLs` — 選択 URL の行番号を返し、一覧にない URL を無視する
- `SelectionIndexTests.duplicateURLsUseFirstRow` — 重複 URL は先頭行（`firstIndex(of:)` と同じ意味）
- `PerformanceBaselineTests.selectionIndexTenThousandRows` — 10,000 行・5,000 選択で件数・先頭・末尾と 100ms 未満を検証
  （観測値 7.9ms、2026-10-27）

## Local Verification

- `swift build` → 成功（既存の `MainToolbarController.swift:70` の MainActor 警告のみ）
- `swift test --filter SelectionIndexTests` → 3 件成功
- `swift test --filter selectionIndexTenThousandRows` → 1 件成功、`[perf] selection index 10,000 rows / 5,000 selected: 0.006524583 seconds`
- `swift test --filter MediaViewerCoreTests --no-parallel` → 776 件成功
- `swift test --filter MediaViewerPerformanceTests` → 27 件中、既存の時間依存 5 件が高負荷（load 10 前後）で失敗。
  追加した選択インデックスの計測は成功（7.9ms）。失敗は `didRenameFolder`・フォルダ列挙・zip open・
  50,000 件バッチ・スライドショー抽出で、今回の変更箇所ではない
- `scripts/check-no-network.sh` → ネットワーク API の参照なし
- `scripts/make-app.sh` → 成功（`.build/MediaViewer.app` 更新）
- GUI 確認: 未実施。ユーザーが 10,000 フォルダの複数選択・⌘F・右クリックを確認する必要がある

## Deviations from Assessment

なし。Core の共通ヘルパーに切り出し、リスト形式とサムネイル形式の両方へ適用した。

## Follow-ups

- GUI 確認（ユーザー）:
  - `many-folders` で約 5,000 行を選択し、選択の反映が数十秒止まらない
  - 選択直後の ⌘F と右クリックがすぐ開く
  - リスト形式とサムネイル形式の両方で選択位置がずれない
  - 検索結果表示中（`SC-016`）でも同じ操作が 100ms 以上止まらない
- 確認後に `.specify/bugs/folder-list-multi-selection-freeze/test.md` を作成する。GUI 未確認の間は `partial` とする
- 010 の T031（大量件数・応答）は、この修正後のアプリで再確認する
