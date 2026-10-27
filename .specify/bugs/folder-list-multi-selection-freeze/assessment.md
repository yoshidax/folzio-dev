# Bug Assessment: 10,000 フォルダの複数選択で検索モーダル・右クリックが固まる

- **Slug**: folder-list-multi-selection-freeze
- **Created**: 2026-10-27
- **Source**: pasted text（010 の GUI 確認中のユーザー報告）
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> テストデータのmany_folder内で半数くらいのフォルダを選択して検索モーダル表示（CMD+F）や右クリックをすると数十秒固まるほど負荷がかかっているようです。

条件:

- `~/MediaViewerFixtures/search-folder-picker/many-folders`（直下 10,000 フォルダ、各 1 JPEG）
- 約半数（5,000 件程度）を複数選択した後、⌘F または右クリック
- 数十秒の UI 停止。010 の標準パネル導入前から存在しうるファイルリスト側の挙動

## Symptom

10,000 行の一覧で数千行を複数選択すると、選択の反映に非常に長い時間がかかり、その後の ⌘F や右クリックが
数十秒固まる。期待は、FR-016 の複数選択と SC-003/SC-016 の「選択操作が 100ms 以上止まらない」を満たし、
選択後すぐに検索シートやコンテキストメニューを開けること。

## Reproduction

1. `~/MediaViewerFixtures/search-folder-picker/many-folders` を開く（10,000 フォルダ）。
2. Shift クリックや ⌘A で約 5,000 行を選択する。
3. 選択の反映を待つ（数十秒）。
4. ⌘F または右クリックする。

- GUI での再現はユーザー報告。実測の停止時間・選択件数は `[NEEDS CLARIFICATION: 選択件数と停止時間の詳細]`。
- 自動の再現: 10,000 URL と半数 5,000 URL の選択集合で `urls.firstIndex(of:)` を繰り返すと、
  ローカル計測で約 2.43 秒。辞書化すると約 0.011 秒だった（debug build、2026-10-27）。
- 選択行数が 10,000 の半分でなくても、選択数 × 一覧数に比例して悪化する。

## Suspected Code Paths

- `Sources/MediaViewerApp/FileList/ListModeView.swift:280` — `model.selection.selected.compactMap { url in urls.firstIndex(of: url) }`。
  `selected` は `Set<URL>` で、選択 5,000 件それぞれについて 10,000 件の配列を線形探索するため O(N×M)。
  リスト形式の選択変更時に `observeModel()` から `applyModel()` が呼ばれる。
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift:580` — 同じ `urls.firstIndex(of:)` の繰り返し。
  サムネイル形式を表示中なら同様に O(N×M)。
- `Sources/MediaViewerApp/FileList/ListModeView.swift:253` / `ThumbnailModeView.swift:551` — `model.selection.selected` を
  `withObservationTracking` で監視しており、複数選択のたびに同期処理が走る。
- `Sources/MediaViewerApp/FileList/FileContextMenu.swift:37` — 右クリック時の `menuNeedsUpdate` は主因ではないが、
  選択の同期が終わるまでメニューが表示されないため、固まって見える。

## Root Cause Hypothesis

**Confidence: high.** 選択 URL から行インデックスへの変換が、選択件数ごとに一覧全体を線形探索する O(N×M) 実装に
なっている。10,000 行・5,000 選択で約 5,000 万回の URL 比較がメインスレッドで発生し、その間 UI が応答しない。
⌘F 自体や `SearchPanelController` は一覧を列挙していないため、010 の標準パネル実装が主因ではない。
右クリックも、選択反映の完了を待つために同じ停止として観測される。

## Spec Comparison

- **FR-016**（file-list.md）: クリック・⌘クリック・Shift クリック・Shift+矢印・⌘A で複数選択できなければならない。
  機能は成立するが、実用的な時間で反映されない。
- **SC-003**（file-list.md）: 10,000 ファイルのフォルダでも、読み込み中・選択の操作が途切れない。
  数十秒の停止はこれに反する。
- **SC-016**（search.md）: 検索中もスクロール・選択・プレビュー・ツリーの操作が 100ms 以上止まらない。
  検索結果表示中の同様の複数選択でも同じ経路を通る。
- **判定**: 実装が既存仕様に反している → fix へ進む。

## Proposed Remediation

**Preferred**: URL から行インデックスへの対応表を 1 回だけ作り、選択集合を O(N+M) で `IndexSet` に変換する。
純粋な Core の小さなヘルパー（例: `SelectionIndex.indexes(of:in:)`）に切り出し、リスト形式とサムネイル形式の両方で使う。
これにより選択変更 1 回あたりの処理を約 2.4 秒から約 10ms に短縮できる見込み。

- 実装: `Sources/MediaViewerCore/Model/SelectionIndex.swift` を追加。
  `for (index, url) in urls.enumerated() where map[url] == nil { map[url] = index }` で先頭一致を保持する。
- `ListModeView.applyModel`: `IndexSet(SelectionIndex.indexes(of: model.selection.selected, in: urls))`。
- `ThumbnailModeView.applyModel`: `IndexSet` から `Set<IndexPath>` を作る。
- `scripts` / 外部依存 / 保存形式は変更しない。

**Alternatives**:
- 一覧の URL 配列を `BrowserModel` 側で辞書として保持する（変更範囲が広く、一覧の更新ごとの整合性管理が必要）。
- 選択変更時に差分だけ反映する（選択操作の種類ごとの実装が複雑になり、今回の症状に対して過剰）。

**Files likely to change**:
- `Sources/MediaViewerCore/Model/SelectionIndex.swift`（新規）
- `Sources/MediaViewerApp/FileList/ListModeView.swift`
- `Sources/MediaViewerApp/FileList/ThumbnailModeView.swift`
- `Tests/MediaViewerCoreTests/SelectionIndexTests.swift`（新規）
- `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift`（10,000 行・5,000 選択の計測）

**Tests to add or update**:
- 10,000 URL・5,000 選択で正しい `IndexSet` を返す（先頭一致、未選択、重複 URL）。
- 同じ入力の処理が 100ms 未満であることを計測する（O(N×M) への退行を検出）。
- 既存の選択・並べ替え・サムネイル選択の回帰テストへの影響がないこと。

## Risks & Considerations

- 一覧に同じ URL が重複する場合は先頭の行を選ぶ。既存の `firstIndex(of:)` と同じ意味にする。
- 選択 URL が一覧にない場合は従来どおり無視する。
- `IndexSet` の順序・件数は従来と同じにする。
- サムネイル形式の `selectionIndexPaths` の型変換を誤ると選択がずれるため、単体テストで固定する。
- 停止の体感は GUI で再確認する。自動計測は変換処理だけを対象とし、GUI 全体の 100ms を保証しない。

## Open Questions

- [NEEDS CLARIFICATION: ユーザーが選択した正確な件数と、⌘F・右クリックそれぞれの停止時間。修正後の GUI 再確認で記録する]
- 010 の T031（大量件数・応答）の証拠として扱えるか。010 の標準パネルとは独立した既存ファイルリストの不具合なので、
  修正は別 bug として記録し、010 の T031 では修正後のアプリで再確認する。
