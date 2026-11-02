# Research: ファイル名検索で zip ファイルも検索対象にする

## R1: 検索結果から zip を開くときの位置とツリー同期

- **確認したこと**: `BrowserModel.openItem` の `.archive` は `openArchive` を呼び、`listing.folder` を引き継ぐ（`BrowserModel.swift` の `openArchive`）。
  検索結果の表示中の `listing.folder` は検索前の場所 A で、zip の親 B ではない。フォルダの行は `navigateToFolder(... reason: .openedSearchResultFolder)` で
  ツリー同期（`TreeSyncRequest`）と履歴の記録を行う。`HistoryNavigator` の `.openedSearchResultFolder` は、検索結果の表示を終えた状態を現在の履歴に反映してから記録する（EC-99・EC-100）。
- **決定**: `openArchive` に「zip を含むフォルダ」と「位置の変更の理由」を渡せるようにする。検索結果から開くときは、親フォルダを `listing.folder` にし、
  `TreeSyncRequest(folder: 親)` を発行してから、`.openedSearchResultFolder` で通知する。通常の一覧から開くときは従来どおり（`.navigated`）。
- **理由**: FR-271 の「ツリーの選択は zip を含むフォルダ」「履歴は検索結果を記録せず zip の最上位を記録」を、フォルダの行と同じ経路で満たせる。
- **未確認**: ツリーに表示されない場合の EC-102 の処理がどこにあるか（`DirectoryTreeViewController` の `treeSyncRequest` 受け取り側と思われる）。実装時に、フォルダの行と同じ経路で動くことを確かめる。

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
