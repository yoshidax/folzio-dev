# Research: ファイル名検索で zip ファイルも検索対象にする

## R1: 検索結果から zip を開くときの位置とツリー同期

- **確認したこと**: `BrowserModel.openItem` の `.archive` は `openArchive` を呼び、`listing.folder` を引き継ぐ（`BrowserModel.swift` の `openArchive`）。
  検索結果の表示中の `listing.folder` は検索前の場所 A で、zip の親 B ではない。フォルダの行は `navigateToFolder(... reason: .openedSearchResultFolder)` で
  ツリー同期（`TreeSyncRequest`）と履歴の記録を行う。`HistoryNavigator` の `.openedSearchResultFolder` は、検索結果の表示を終えた状態を現在の履歴に反映してから記録する（EC-99・EC-100）。
- **決定**: `openArchive` に「zip を含むフォルダ」と「位置の変更の理由」を渡せるようにする。検索結果から開くときは、親フォルダを `listing.folder` にし、
  `TreeSyncRequest(folder: 親)` を発行してから、`.openedSearchResultFolder` で通知する。通常の一覧から開くときは従来どおり（`.navigated`）。
- **理由**: FR-271 の「ツリーの選択は zip を含むフォルダ」「履歴は検索結果を記録せず zip の最上位を記録」を、フォルダの行と同じ経路で満たせる。
- **確認済み（T002）**: ツリー側（`DirectoryTreeViewController.syncSelection`）は `model.listing.folder == request.folder` で照合して選択し、`completeSearchResultTreeSync` で EC-102 の祖先を保存する。
  `listing.folder` を zip を含むフォルダにすれば同じ経路で動く。ただし `completeSearchResultTreeSync` の `listing.archive == nil` の条件が zip の場合に保存を止めるため、外した
  （`pendingSearchTreeSyncID` が検索結果から開いたときだけ設定されるので、通常の一覧・履歴からの同期は従来どおり拒否される）。

## R2: 設定の固定と `rebuildListing` のフィルタ

- **確認したこと**: `rebuildListing` は `ZipFileVisibility(showsZipFiles:)` を `allFiles` に毎回適用する。`setShowsZipFiles` は `listing.archive == nil`（検索結果を含む）のとき `rebuildListing` を呼ぶ。
  このままでは、検索結果の表示中に設定をオフにすると zip の行が消える（FR-269 に反する）。
- **決定**: `rebuildListing` は、検索結果の表示中（`isShowingSearchResults`）は `ZipFileVisibility` を適用しない。検索に含める・含めないは検索の開始時の値（`searchIncludesArchives`）で決め、
  検索条件は `resetForNavigation` で破棄する。

## R3: 名前の変更

- **確認したこと**: `didRenameItem` は `MediaKind(fileExtension:)` で新しい拡張子を判定し、対応メディアでなければ行を外す。`.archive` の行は `kind = .media(...)` に書き換えてしまう懸念がある。
- **決定**: 行の種類が `.archive` なら、新しい拡張子（小文字）が `zip` の間は `.archive` のまま残し、種類名を更新する。それ以外は外す。

## R4: ファイルへのシンボリックリンク

- **確認したこと**: `FileNameSearcher.matchedFile` は、ファイルへのシンボリックリンクを通常のファイルとして扱い、フォルダへのリンクは外す。
- **決定**: `.zip` も同じ判定を使う（FR-083）。リンク先がフォルダの `x.zip` は外す。

## R5: 名前が `x.zip` のフォルダ

- **確認したこと**: 列挙では `isDirectory` を先に見るため、フォルダの `x.zip` はフォルダの行として扱われ、zip 判定に進まない。
- **決定**: 現状の分岐順を保ち、テストで固定する。

## R6: App 層の確認（T012）

- `ListItemCommands.canOpenContainer` は `ListItemKind.opensAsContainer`（`.archive` を含む）を使うため、「中を表示（⌘↓）」・ダブルクリックは検索結果の zip の行でも有効になる（`FileListViewController.openFocusedItem`）。
  「上の階層へ」は `isShowingSearchResults` で無効のまま。
- `.folder` を固定で見ている分岐は、ドロップ先の判定（`ListModeView`・`ThumbnailModeView`）だけで、zip はドロップ先にならないので変更不要。
- `BrowserModel` の `hasMedia`・フルスクリーンの移動・スライドショーは `kind.isMedia` で判定しており、`.archive` の行は対象にならない。
- 上は読んで確認した結果であり、実際の表示（メニューの項目・区切り線・「場所」列）は quickstart のシナリオ 6〜9 で保守者が確認する。
