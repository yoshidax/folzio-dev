# Tasks: ファイル名検索で zip ファイルも検索対象にする

**Input**: `specs/TAK-51-search-zip-files/` の spec.md、plan.md、research.md、quickstart.md。

**Prerequisites**: 設計レビューの承認前には実装しない（`docs_private/cloud-agent-workflow.md`）。

**Tests**: Core のロジックと異常系にテストを付ける（`Tests/FolzioCoreTests`）。GUI は quickstart.md で保守者が確認する。

**Organization**: US1=US54、US2=US55、US3=US56。Cloud は Issue 単位のため全タスクを順次実行し、[P] は使用しない。Cloud では `swift` を実行できないため、ビルドとテストは macOS CI で確認する。

## Phase 1: Setup

- [x] T001 `specs/TAK-51-search-zip-files/plan.md` の設計レビューの承認を保守者から受け、実装開始の根拠を `specs/TAK-51-search-zip-files/quickstart.md` の「記録」に残す。
- [x] T002 research.md R1 の未確認点を、実装前にコードで確かめて追記する。`treeSyncRequest` の受け取り側（`Sources/FolzioApp/Tree/DirectoryTreeViewController.swift`）が、フォルダの行を開く場合と同じ経路で EC-102（ツリーに表示されない場合の祖先の選択）を処理しており、zip を含むフォルダを渡しても同じに動くこと。違えば plan.md の対象に加える。

## Phase 2: US2（設定に従う）と US1（zip を名前から探す）

**Goal**: 「zipファイルを表示」がオンで始めた検索だけ、名前が一致する zip ファイルが行として出る。オフ（既定）では従来と同じ。

**Independent Test**: quickstart シナリオ 1〜5。

- [x] T003 `Sources/FolzioCore/Search/SearchRequest.swift` に `public var includesArchives: Bool`（既定 `false`、`init` の引数にも追加）を追加し、doc comment を英語で書く（FR-278）。
- [x] T004 `Sources/FolzioCore/FileSystem/DirectoryLister.swift` の `.archive` の行の生成を、`folderRow` と同じ形の `static func archiveRow(at:values:kindNames:)` に取り出し、`mediaFiles(in:)` から使う。リストの出力が変わらないことを既存のテストで確認する（FR-279）。
- [x] T005 `Sources/FolzioCore/Search/FileNameSearcher.swift` の `matchedFile` で、`request.includesArchives` が true で、拡張子が `zip`（大文字小文字を区別しない）のファイルを `.archive` の行（T004 の `archiveRow`）として返す。ファイルへのシンボリックリンクは既存の判定（リンク先がフォルダなら外す）を共通に使う。ディレクトリは先に判定されるので、名前が `x.zip` のフォルダはフォルダの行のままにする（R4・R5）。型の doc comment の「Does not open zips」を更新する（FR-083・269）。
- [x] T006 `Tests/FolzioCoreTests/FileNameSearcherTests.swift` に追加する。（1）オンで `trip` が `trip_2024.zip` と `Trip.ZIP` に一致する（2）オフでは一致しない（3）zip の中のディレクトリ名・ファイル名は一致しない（4）`*.zip` のワイルドカードが `archive.zipx`・`archive.zip.bak` を除く（5）隠し zip・パッケージ内・フォルダへのシンボリックリンク内の zip は出ない（6）ファイルへのシンボリックリンクの `.zip` は出て、フォルダへのリンクの `x.zip` は出ない（7）名前が `x.zip` のフォルダはフォルダの行（8）異なる場所の同名の zip が別の行で、URL が異なる（US54-AS1〜AS6・SC-139・SC-140）。
- [x] T007 `Sources/FolzioCore/Browser/BrowserModel.swift` で、`startSearch` が開始時の `showsZipFiles` を `searchIncludesArchives` に保持し、`startSearchStream`（名前の変更後の追加の列挙を含む）が `SearchRequest.includesArchives` に渡す。`resetForNavigation` で `searchIncludesArchives` を `false` に戻す。`rebuildListing` は `isShowingSearchResults` のとき `ZipFileVisibility` を適用しない。`setShowsZipFiles` は検索結果の表示中に既存の行を変えない（FR-278・R2）。
- [x] T008 `Tests/FolzioCoreTests/BrowserModelSearchTests.swift` に追加する。（1）オフで始めた検索の結果に zip がない（2）オンで始めた検索の結果に zip の行があり、件数に数えられる（3）結果の表示中・検索中に設定を切り替えても行と件数が変わらず、次の `startSearch` から切り替え後に従う（4）検索を終えて一覧に戻ると切り替え後の設定に従う（5）zip だけが一致するとき該当する項目がない旨の状態にならない（6）「画像のみ」で zip と動画だけが一致するとき zip の行は残り、状態は絞り込み中になる（7）フォルダ名変更後の追加の列挙でも同じ設定を使う（US55-AS1〜AS4・US56-AS4・SC-141）。

**Checkpoint**: US54・US55 が自動テストで確認できる。

## Phase 3: US3 検索結果の zip を開く・操作する

**Goal**: 検索結果の zip の行を、通常の zip と同じく開き、ファイル操作の対象にする。

**Independent Test**: quickstart シナリオ 6〜9。

- [x] T009 `Sources/FolzioCore/Browser/BrowserModel.swift` の `openItem`（`.archive`）と `openArchive` を、検索結果から開くときに zip を含むフォルダ（`url.deletingLastPathComponent()`）を `listing.folder` にし、`TreeSyncRequest` を発行し、`onLocationEvent` を `.openedSearchResultFolder` で通知するようにする。通常の一覧から開くときの挙動と `guard listing.archive == nil` は変えない（FR-280・R1）。
- [x] T010 `Sources/FolzioCore/Browser/BrowserModel.swift` の `didRenameItem` で、`.archive` の行は新しい名前の拡張子が `zip`（大文字小文字を区別しない）の間は `.archive` のまま残し、種類名を更新し、それ以外は `removeSearchResults` で外す。メディアの行の既存の判定は変えない（FR-281・R3）。
- [x] T011 `Tests/FolzioCoreTests/BrowserModelSearchTests.swift` と `BrowserModelHistoryTests.swift` に追加する。（1）検索結果の zip を開くと検索結果が終わり、`listing.archive` が zip の最上位、`listing.folder` が zip を含むフォルダになり、`treeSyncRequest` が同じフォルダを指す（2）履歴に zip の最上位が新しく記録され、戻ると検索前の場所に戻って検索結果には戻らない（3）zip の中で始めた検索から開いた場合は EC-100 どおりに記録する（4）`.zip` のまま名前を変えた行が残り、`.txt` にすると外れる（5）ゴミ箱・移動で行が外れる（6）zip の行を選択するとプレビューが空になり、フルスクリーンの移動・スライドショーの対象にならない（US56-AS1・AS3・AS5・AS6・SC-142〜SC-144）。
- [x] T012 `Sources/FolzioApp/FileList/` の検索結果の表示（`FileListViewController.swift`・`ListModeView.swift`・`ThumbnailModeView.swift`・`ListItemSupport.swift`）で、`.folder` を前提にした分岐が `.archive` の行で破綻しないことを確認する。右クリックメニューの「中を表示（⌘↓）」と区切り線、「上の階層へ」が出ないこと、ドラッグ&ドロップの受け側が `.folder` だけであること、「場所」列とツールチップが zip の行にも出ることを確かめ、不足があれば最小限の修正を行う。結果を research.md の末尾に追記する（FR-279・271）。

**Checkpoint**: US54〜US56 の自動検証が揃う。

## Phase 4: 検証と仕上げ

- [x] T013 Cloud の検査を行う: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`。新規・変更したコードのコメントは英語で書く。
- [x] T014 作業ブランチに push し、保守者の依頼で PR を作って、CI（`swift build`、`swift test`）の成功を確認する。（PR は未作成のため、`workflow_dispatch` で `83feaf8` を実行し、成功を確認した。PR を作ったときの CI は、依頼があったときに確認する）
- [x] T015 [MANUAL] 保守者が `quickstart.md` のシナリオ 1〜9 をローカルで確認し、結果を `specs/TAK-51-search-zip-files/checklists/validation.md` に記録する。GUI は Cloud で起動しない。
- [x] T016 実装と検証が終わった後に、`git merge origin/master` で最新の master を取り込み、spec.md の「反映先」の表に従って `specs/product/search.md`・`specs/product/zip.md` を更新する（ID の重複確認を含む。EC は EC-191 から採番）。spec.md の冒頭に凍結の注記を入れる。差分を保守者に示し、承認を得てからコミットする。
