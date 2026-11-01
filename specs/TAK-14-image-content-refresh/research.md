# Research: 同一パスのファイルの内容更新をサムネイルとプレビューに反映する

調査の基準: origin/master 4ec25c0（2026-11-01）。コードの静的な確認による。Cloud では Swift を実行できないため、再現は CI のテストと
保守者の GUI 確認で行う。

## 現状の原因（静的な確認）

| 層 | 現状 | 根拠 |
|---|---|---|
| プレビューのデコード済み画像 | `DecodedImageCache` は URL だけをキーに保持する。`BrowserModel.decodedImage(for:)`・`archiveImage(for:maxPixelSize:)` はキャッシュを先に引く | `Sources/FolzioCore/Imaging/DecodedImageCache.swift`、`BrowserModel.swift` の `decodedImage(for:)` |
| 変更の通知 | `handleFileSystemEvent` → `reloadCurrentFolder` は一覧を作り直し、同じ URL の選択を保つ。フォーカスが残ればプレビューを読み込み直さない | `BrowserModel.reloadCurrentFolder()` |
| 一覧の行の値 | `MediaFile` は大きさ・作成日を持つが、更新日時・実体の番号を持たない。`==` と `hash` は URL だけ | `Sources/FolzioCore/Model/MediaFile.swift` |
| 縮小画像 | `ThumbnailProvider` の `NSCache` のキーは `URL#pixelSize` | `ThumbnailProvider.cacheKey(for:pixelSize:)` |
| 一覧の表示 | リスト形式・サムネイル形式とも、URL の並びが変わったときだけ `reloadData` する。サムネイルのセルは URL が変わったときだけ代替アイコンに戻す | `ListModeView.applyModel()`、`ThumbnailModeView.applyModel()`・`ThumbnailCell.configure(with:iconPointSize:)` |
| 検索結果 | 変更の通知では、消えた結果を外すだけ | `BrowserModel.pruneMissingResults(under:)` |
| zip | zip の識別情報（大きさ・更新日時・inode）は `ArchiveIndex.identity` にある。`ZipArchiveReader.open` は毎回開き直す。キャッシュは仮想 URL をキーにするため、開き直した zip でも古い画像が当たる | `ArchiveIndex.swift`、`ZipArchiveReader.open(_:)` |
| プレビューの倍率 | 倍率は URL を単位に保たれ、同じ URL の表示を差し替えてもフィットに戻らない | `PreviewViewController.zoomIdentity(for:)`、`PreviewZoomTracker.present(_:)` |

## R1 内容の識別情報

- **Decision**: `FileContentVersion`（大きさ・内容の更新日時・ファイルの識別子（inode））を Core に追加し、`MediaFile` に `contentVersion` として持たせる。
  通常のファイルは `URLResourceValues` の `fileSize`・`contentModificationDate`・`fileIdentifier` から作る。
  zip の中のファイルは、zip ファイル自体の `ArchiveIdentity` から作る（同じ zip の中の項目はすべて同じ値）。
- **Rationale**: 上書き（同じ inode、更新日時が変わる）と、置き換え（コピーの「置き換える」や安全な保存。inode が変わる）の両方を
  内容を読まずに判別できる。`contentsOfDirectory(at:includingPropertiesForKeys:)` で前もって取得するため、追加の I/O は小さい。
  zip は既に同じ3つの値で変更を判別している（EC-26）。
- **API の確認**: `URLResourceValues.fileIdentifier: UInt64?` は macOS 13.3 以降（Apple の文書で確認。2026-11-01）。
  対象は macOS 15 以降のため使える。文書は「すべてのファイルシステムで安定とは限らない」としているため、
  永続化せず、比較の要素の1つとしてだけ使う。値が得られない場合は `nil` で比較する。
- **Alternatives**: 内容のハッシュ（全体を読むため遅い。不採用）。更新日時だけ（日時を保つコピーで置き換えると見逃す。TAK-43 では
  タイムスタンプがコピー元の値になった）。`stat(2)` を個別に呼ぶ（行ごとに syscall が増える。`fileIdentifier` で足りる）。

## R2 プレビューのキャッシュ

- **Decision**: `DecodedImageCache` の `get`・`put` に `version: FileContentVersion?` を加える。保持している値と版が違えば、
  `get` はその項目を捨てて `nil` を返す。`version` が `nil`（一覧にない URL など）のときは、キャッシュを使わず、保持もしない。
- **Rationale**: 置き換え前に始めた読み込みが後から `put` しても、古い版の項目は新しい版の `get` に当たらない（EC-161、FR-230）。
  メモリの上限（憲章 II）は変えない。URL ごとに1つだけ保持するため、版の違う項目が積み上がらない。
- **Alternatives**: 変更を検出したときに URL の項目を消す（消した直後に、実行中の古い読み込みが `put` すると古い画像が戻る。不採用）。

## R3 縮小画像のキャッシュ

- **Decision**: `ThumbnailProviding.thumbnail(for:pointSize:scale:)` と `cancel(for:pointSize:scale:)` に `version: FileContentVersion?` を加え、
  キャッシュのキーを `URL#pixelSize#version` にする。
- **Rationale**: 版の違う古い縮小画像は当たらなくなり、古い項目は `NSCache` の上限で自然に追い出される。実行中の要求の照合にも版を使う。
- **QuickLook のリスク**: `QLThumbnailGenerator` が OS 側で縮小画像を保持している場合、版を変えても古い縮小画像が返る可能性がある。
  文書では確認できなかった。保守者の GUI 確認（quickstart の Q2）で確かめ、古い縮小画像が返るなら、別の課題として
  通常の画像を ImageIO で作る方法を検討する（この feature の範囲を超えるため、ここでは採らない）。

## R4 変更の検出と通知

- **Decision**: `reloadCurrentFolder` で、新旧の `allFiles` を URL で突き合わせ、版の違う URL の集合を求める。
  - 集合を `contentChangeGeneration`（世代番号）と `changedContentURLs` として公開し、App の一覧が該当する行だけを読み込み直す。
  - フォーカス中のファイルが集合に含まれ、プレビューが静止画・アニメーション画像・読み込み中なら、プレビューを読み込み直す（FR-229）。
  - 近くの先読みの実行中のタスクは、版の違う URL について取り消す。
- **Rationale**: 版の比較は Core の純粋なロジックとしてテストできる（憲章 IV）。変わっていない行には何もしない（SC-116）。
- **Alternatives**: 一覧全体を `reloadData`（10,000 行で全セルを作り直し、縮小画像の要求が増える。不採用）。

## R5 プレビューの読み込み直し

- **Decision**: 読み込み直しでは、静止画は `.loading` に切り替えず、現在の表示を保ったままデコードし、終わったら `.image` を差し替える（EC-162）。
  アニメーション画像は、`preview` に同じ `.animatedImage(url)` を設定し直し、App が読み込み直す（`PreviewContent` は `Equatable` でないため、
  Observation は設定のたびに通知する）。種類が変わった場合（EC-159）は通常の `loadPreview(for:)` に任せる。
  動画（A-142）と zip の中の項目は、読み込み直しの対象にしない（表示中の zip が変わったら EC-26 で一覧に戻る）。
- **Rationale**: 倍率は URL 単位で保たれる既存の仕組み（`PreviewZoomTracker`）のままで EC-162 を満たせる。
  `previewGeneration` を進めるため、実行中の古い読み込みの結果は表示されない。

## R6 検索結果

- **Decision**: `pruneMissingResults(under:)` の、通知のあったフォルダの下の結果を調べる処理で、存在の確認と一緒に版も取り直す
  （バックグラウンドで `resourceValues`）。版が変わった結果は `allFiles` の値を差し替え、R4 と同じ通知と読み込み直しを行う。
- **Rationale**: 検索結果は一覧を作り直さない（R38、FR-087）。既にあるバックグラウンドの確認に相乗りし、対象を通知のあったフォルダの下に限る。

## R7 zip

- **Decision**: zip の一覧の行の `contentVersion` を、開いたときの `ArchiveIndex.identity` から作る。プレビュー（`archiveImage`）と
  縮小画像（`archiveThumbnail`）は、その版でキャッシュを引く。
- **Rationale**: zip を置き換えて開き直すと版が変わるため、古い画像は当たらない（FR-231）。表示中の zip の変更は既存の EC-26 のまま。

## R8 App の一覧

- **Decision**: `ListModeView`・`ThumbnailModeView` は `contentChangeGeneration` を観察し、URL の並びが同じで版の違う行だけを
  `reloadData(forRowIndexes:columnIndexes:)`・`reloadItems(at:)` で読み込み直し、その行の縮小画像を新しい版で要求し直す。
  サムネイルのセルは、URL か版が変わったときに代替アイコンへ戻す。
- **Rationale**: 選択・フォーカス・スクロール位置を変えない（FR-229）。
