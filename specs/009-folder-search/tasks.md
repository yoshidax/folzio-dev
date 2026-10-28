---
description: "検索でフォルダも検索対象にする 実装タスク"
---

# Tasks: 検索でフォルダも検索対象にする

**Input**: `specs/009-folder-search/` の spec.md・plan.md・research.md・data-model.md・contracts/folder-search.md・quickstart.md、spec が参照する `specs/product/` の領域（search.md・file-list.md・file-operations.md・directory-tree.md・navigation-history.md・preview.md・zip.md・overview.md）と `specs/product/contracts/keyboard-and-menus.md`、憲章 v1.2.0。

**Prerequisites**: `009-folder-search` ブランチ。Swift 6 / macOS 15 以降 / AppKit / 単一 Swift Package。外部パッケージの追加なし。UserDefaults の新しいキーなし（検索結果・検索条件・照合済みの記録は保存しない）。

**Tests**: plan の Testing 方針と憲章 IV に従い、Core の照合（フォルダの行・除外・値の一致）、照合済みの記録、名前の変更の台帳、`BrowserModel` の一覧の状態・開く・ファイル操作・外部の変更・検索中と検索後の名前の変更・検索結果の一覧からのゴミ箱・移動の判断（EC-101）、`HistoryNavigator` の EC-99・EC-100 と EC-101 の後半（検索を終えたときの「フォルダが見つかりません」と履歴）を Swift Testing で自動テストする。テストを先に追加し、実装前に期待する失敗を確認する。GUI の操作・見た目・ツリーの同期・フォーカスは `.app` の手動確認で確かめる。

**Organization**: spec のユーザーストーリーは US15 の1つだけ。検索の要求（`SearchRequest`）と照合済みの記録（`SearchVisitLog`）、フォルダの行の共有は、照合・開く・名前の変更のすべてが使う前提として Phase 2 に置く。US15 は、検証ゲートとコミットの単位を小さくするため、3つの Phase（照合と一覧の表示 → 開く・履歴 → ファイル操作・外部の変更・検索中の名前の変更）に分ける。Phase 3 だけで「フォルダが検索結果に出る」価値が、Phase 4 までで「探して開く」（US15 の Independent Test）が成り立つ。

## Format: `[ID] [P?] [Story] Description`

- `[P]`: 同じ Phase 内で、前提完了後に別ファイルとして並行処理できる候補。既定は順次実装。
- `[US15]`: spec.md の US15 との対応。Setup・Foundational・最終 Phase には付けない。
- 手動ゲートは `[US15] 手動:` または `手動:` と書き、ユーザーが GUI の操作・確認を行う。未実施なら未チェックに保つ。
- パスはリポジトリルートからの相対パス。新規ファイルは「新規」と明示する。

## Path Conventions

- Core: `Sources/MediaViewerCore/`（AppKit を import しない）
- App: `Sources/MediaViewerApp/`（MainActor で描画・入力・ウインドウを扱う）
- Fixtures: `Sources/FixtureKit/`、テスト: `Tests/MediaViewerCoreTests/`・`Tests/MediaViewerPerformanceTests/`
- 実装中に更新する設計文書は、本書のチェックと、タスクで明示した `specs/009-folder-search/quickstart.md` への追記だけ。`specs/product/` への反映は T056 まで行わない。

## 共通の実装・検証規則

- 照合・照合済みの記録・名前の変更の付け替えの判断は Core（`FileNameSearcher`・`SearchRequest`・`SearchVisitLog`・`SearchRenameLedger`）に置き、`BrowserModel` は台帳を持って一覧へ反映するだけにする。履歴の判断は `HistoryNavigator` に置き、`BrowserModel` は `LocationEvent` の種類を分けるだけにする（001 の R70）。
- フォルダの行は `ListItemKind.folder`（`MediaFile.kind == .folder`）のまま扱い、検索結果専用の行の種類・状態（`.searchFolder`・`.foldersOnly` など）を作らない（R1・R5）。一覧の状態・種類フィルタ・プレビューの除外・フルスクリーンの飛ばし・スライドショーの除外・右クリックメニュー・⌘↓ の判定は既存の `.folder` の分岐に任せ、`FileContextMenu`・`validateMenuItem`・`ListModeView`・`ThumbnailModeView`・`MainMenu`・`FocusNavigator`・`SlideshowSequence` は変えない。
- 列挙は1回の走査のまま UI スレッドの外で行う。一致しないディレクトリには先読み済みのキー（`.isDirectoryKey`・`.isSymbolicLinkKey`）しか使わず、`isPackage`・作成日は名前が一致したディレクトリにだけ問い合わせる（R1、SC-054）。
- ファイルだけ・フォルダだけの切り替え（A-77）、zip ファイルの名前と zip の中の照合（A-79）、開いたフォルダから検索結果へ戻る操作（A-80）、件数の内訳（A-81）は作らない。
- 各 Phase 末尾のゲートは build → 全 test → no-network → bundle 作成 → ユーザーの起動スモーク → コミットの順。GUI の起動はユーザーに依頼し、未実施を合格・完了にしない。build/test の失敗を3回直しても解決しない場合は止めて報告する。
- ゲートの結果は `specs/009-folder-search/quickstart.md` の末尾に「Phase 検証記録」の節を作って（既にあれば追記して）記録する。日付・コマンド結果・GUI 確認内容・未実施項目を書く。
- AppKit の禁止 split delegate override は追加しない。ビュー・制約・`NSSplitViewController` には触れない。UI の変更は MainActor のみ。
- 並列実装を行う場合は、未コミットの変更を先にコミットまたは stash し、`009-folder-search` をベースに専用の worktree と `agent/<task-id>-<slug>` ブランチを作る。同じファイルを触るタスクは直列化する（特に `BrowserModel.swift`・`BrowserModelSearchTests.swift`・`FileNameSearcherTests.swift`）。

## Phase 1: Setup — EC-101 の確認・検証データ・既存回帰の確認

**Purpose**: ユーザーが採用済みの EC-101（research.md R8）を前提に、手動確認とテストに使う `folder-search/` の検証データを用意し、既存の回帰ゲートを通す。

- [X] T001 手動: 2026-10-27 にユーザーが EC-101 をゴミ箱・移動とも採用した。検索結果から検索前のフォルダ自身・祖先を操作した場合は検索表示を続け、消えた結果だけを外す。続く Esc・⌘[ は「フォルダが見つかりません」、その場所は履歴に記録しない。ツリーからのゴミ箱は従来どおり親へ移る。結果を quickstart.md「Phase 検証記録」に記録済み。同じ回答で、ツリーに表示されない検索結果のフォルダは最も近い表示可能な祖先を選択・保存する EC-102 も確定した（T061〜T063）。
- [X] T002 [P] 新規 `Tests/MediaViewerCoreTests/FolderSearchFixtureTests.swift` に Swift Testing を追加する。(1) `FixtureSets.folderSearch(in:)` が一時ディレクトリに quickstart.md「検証データ」の構成を作ることを確かめる: `folder-search/Kyoto/` の下に `2024_Kyoto/IMG_0001.jpg`・`2024_Kyoto_old/`・`kyoto_map.png`・`kyoto/kyoto_01.jpg`・`kyoto/kyoto_day2/`・`kyoto/IMG_0002.jpg`・`.kyoto/`・`Kyoto.app/Contents/`・`kyoto_link`（`2024_Kyoto` を指すシンボリックリンク。`destinationOfSymbolicLink` で確かめる）・`kyoto.zip`・`2024.10_trip/`・`photos.jpg/`（ディレクトリ）・`east/kyoto_day1/`・`west/kyoto_day1/`・`clips/kyoto_clip.mov`・`locked_kyoto/secret_kyoto.jpg`。`locked_kyoto` は生成直後に読めること。EC-102 の検証用に `folder-search/.hidden-parent/search-root/kyoto_open/IMG_0003.jpg` も生成されること（隠しの親の中を起点として直接指定する）。(2) `FixtureSets.folderSearchScale(in:matchingFolders:matchingFiles:otherFolders:excludedEach:)` が既定値（50・50・50・5）で、名前に `kyoto` を含む起点フォルダ `folder-search-scale/kyoto_root/` の下に、`kyoto` を含むフォルダ50個・`kyoto` を含む対応メディアファイル50個・含まないフォルダ50個、`kyoto` を含む隠しフォルダ・パッケージ（`.app`）・フォルダへのシンボリックリンク・zip ファイルを各5個作り、起点の URL を返すこと。引数で件数を変えられること。`defer` で一時ディレクトリを削除する（SC-053、quickstart.md「検証データ」）
- [X] T003 `Sources/FixtureKit/FixtureSets.swift` に `public static func folderSearch(in directory: URL) throws` と `@discardableResult public static func folderSearchScale(in directory: URL, matchingFolders: Int = 50, matchingFiles: Int = 50, otherFolders: Int = 50, excludedEach: Int = 5) throws -> URL` を追加し、`makeAll(in:)` から `folderSearch(in:)` だけを呼ぶ（`folderSearchScale` は呼ばない）。画像は既存の `ImageFixtures.jpeg` / `ImageFixtures.png`（64×48）、動画は `VideoFixtures.mov`、zip は `ZipFixtureWriter.write`、リンクは `FileManager.createSymbolicLink(at:withDestinationURL:)` で作る。既存の `prepare(_:)` で生成先を作り直す。既存の `search`・`mixed`・`zip` などのファイル名・内容・生成順は変えない（T002 を通す）
- [X] T004 `scripts/make-fixtures.sh .build/FolderSearchFixtures` を実行し、`.build/FolderSearchFixtures/folder-search/Kyoto/` の構成を `ls -la`（隠しフォルダ・リンクを含む）で確認する。外部ツール（`cwebp` / `img2webp`）の導入が必要になった場合は導入せずユーザーへ確認する。quickstart.md の「検証データ」と食い違いがあれば、`specs/009-folder-search/quickstart.md` の「検証データ」の表を実装に合わせて直す
- [X] T005 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/009-folder-search/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T006 手動: ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、3ペインが表示されること、既存の検索（⌘F、`search/` で `cat`）の結果・検索バー・Esc での終了に回帰がないことを確認してもらう。結果を `specs/009-folder-search/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T007 直前の自動・GUI ゲート合格後、`Sources/FixtureKit/`・`Tests/MediaViewerCoreTests/FolderSearchFixtureTests.swift`・`specs/009-folder-search/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: EC-101 の採否が確定し、`folder-search/` の検証データと既存の回帰ゲートが揃う。

## Phase 2: Foundational — 検索の要求・照合済みの記録・フォルダの行の共有

**Purpose**: 照合・開く・名前の変更のすべてが使う、検索の要求の型、照合済みの記録、フォルダの行を作る関数を用意する。この Phase では照合の結果（ファイルだけを返す）を変えない。

**Blocking**: T008〜T018 完了後に US15 へ進む。

- [X] T008 [P] 新規 `Tests/MediaViewerCoreTests/SearchVisitLogTests.swift` に `SearchVisitLog` のテストを追加する。初期状態で `contains` が false、`record(path)` の後に同じ文字列で true、別のパスで false。`withTaskGroup` で複数の Task から1,000件を並行に `record` し、すべて `contains` が true になること（`NSLock` による保護）（data-model.md §2、R2）
- [X] T009 [P] `Tests/MediaViewerCoreTests/FileNameSearcherTests.swift` にテストを追加する。`FileNameSearcher().search(SearchRequest(root:pattern:visits:))` で `search` フィクスチャを `cat` で検索し終えた後、`visits` に `a`・`a/b`・`a/b/deep`・`b`・`numbers`・`kana`・`cat-folder`・`Viewer.app`（パッケージもディレクトリとして照合前に記録する）の標準化したパス（起点の形）があり、ファイル（`Cat01.jpg`）・隠しフォルダ（`.hidden`）・フォルダへのリンク（`link`）・パッケージの中（`Viewer.app/Contents`）・起点そのもの（`matchesRoot == false`）がないこと。`search(in:matching:)`（プロトコル拡張）が `search(_:)` と同じ結果を返すこと（R2、data-model.md §2 の不変条件）
- [X] T010 [P] `Tests/MediaViewerCoreTests/DirectoryListerTests.swift` に、`DirectoryLister.folderRow(at:creationDate:)` が返す行が、同じフォルダを含む親に対する `DirectoryLister().mediaFiles(in:)` のフォルダの行と `url`・`name`・`kind == .folder`・`typeDescription == "フォルダ"`・`creationDate`・`fileSize == 0` で一致するテストを追加する（FR-139、R1）
- [X] T011 新規 `Sources/MediaViewerCore/Search/SearchRequest.swift` に `public struct SearchRequest: Sendable`（`root: URL`・`pattern: SearchPattern`・`matchesRoot: Bool`（既定 false）・`visits: SearchVisitLog`、`init(root:pattern:matchesRoot: = false, visits: = SearchVisitLog())`）と `public final class SearchVisitLog: @unchecked Sendable`（`NSLock` で保護した `Set<String>`、`public init()`・`public func record(_ path: String)`・`public func contains(_ path: String) -> Bool`）を実装する。ロックは既存の `Archive/ArchiveAssetLoader.swift` と同じ `NSLock` の `withLock` で書き、`Synchronization.Mutex` は使わない。ディレクトリだけを記録する前提をドキュメントコメントに記す（contracts/folder-search.md「MediaViewerCore の公開 API」、T008 を通す）
- [X] T012 `Sources/MediaViewerCore/Search/FileNameSearcher.swift` の `FileNameSearching` の要件を `func search(_ request: SearchRequest) -> AsyncStream<[MediaFile]>` の1つに変え、`extension FileNameSearching { public func search(in root: URL, matching pattern: SearchPattern) -> AsyncStream<[MediaFile]> }` で `SearchRequest(root:pattern:)` を作って呼ぶ。`FileNameSearcher.search(_:)` は列挙の各項目で、先読みした値が `isDirectory == true` かつ `isSymbolicLink != true` なら `request.visits.record(rebase(url).standardizedFileURL.path)` を照合の前に呼ぶ（この Phase ではディレクトリを結果に加えない）。バッチ（256件・100ms）・取り消し・`rebaser` は変えない（R1・R2、T009 を通す）
- [X] T013 `Sources/MediaViewerCore/FileSystem/DirectoryLister.swift` に `static func folderRow(at url: URL, creationDate: Date?) -> MediaFile`（internal）を追加し、`mediaFiles(in:)` のフォルダの行の生成をこの関数に置き換える。値（`kind: .folder`・`name: url.lastPathComponent`・`typeDescription: "フォルダ"`・`creationDate`・`fileSize: 0`）は変えない（FR-139、R1、T010 を通す）
- [X] T014 `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` の `FakeSearcher` を `search(_ request: SearchRequest)` を実装する形に改める。`requests` の要素に `matchesRoot` と `visits` を加え（例: `(root: URL, pattern: SearchPattern, matchesRoot: Bool, visits: SearchVisitLog)`）、既存の `send(_:)`・`send(_:to:)`・`finish()`・`cancelledCount` は保つ。あわせて `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` の `StreamingSearcher` も `search(_ request: SearchRequest)` に改める。既存テストの期待値は変えない
- [X] T015 `Sources/MediaViewerCore/Browser/BrowserModel.swift` の `startSearchStream(in:matching:)` で `searcher.search(SearchRequest(root: root, pattern: pattern))` を呼ぶ形に変える（台帳との接続は T045 で行う）。`grep -rn "FileNameSearching\|search(in:" Sources Tests` で他の実装・呼び出しが残っていないことを確かめる
- [X] T016 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/009-folder-search/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T017 手動: ユーザーに `open .build/MediaViewer.app` の実行を依頼し、3ペインが表示されること、既存の検索（`search/` で `cat`・`*.png`）の結果と件数、通常のフォルダの一覧のフォルダの行に回帰がないことを確認してもらう（この時点ではフォルダは検索結果に出ない）。結果を「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T018 直前の自動・GUI ゲート合格後、`Sources/MediaViewerCore/Search/`・`Sources/MediaViewerCore/FileSystem/DirectoryLister.swift`・`Sources/MediaViewerCore/Browser/BrowserModel.swift`・`Tests/`・`specs/009-folder-search/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: `SearchRequest`・`SearchVisitLog`・`DirectoryLister.folderRow` が単体テストで固定され、検索器と `BrowserModel` が要求の形で接続されている。

## Phase 3: User Story 15 — フォルダを名前で探して開く（P1）: 照合と一覧の表示 🎯 MVP

**Goal**: 検索キーワードに一致するフォルダが、一致したメディアファイルと同じ検索結果の一覧に、通常のフォルダの行と同じ見た目（汎用アイコン・種類「フォルダ」・作成日・「場所」列）で混ざって並ぶ。隠し・パッケージ・フォルダへのリンク・zip・起点は出ない。件数はファイルとフォルダの合計、0件のメッセージは「該当する項目はありません」、種類フィルタはフォルダの行を隠さない。

**Independent Test**: `folder-search/Kyoto` を起点に `kyoto`・`*_Kyoto`・`2024.10`・`*.jpg`・`clip` で検索し、一致したフォルダとファイルだけが行として出ること、件数・並べ替え・種類フィルタ・プレビューが空になること・フルスクリーンとスライドショーでフォルダの行を飛ばすことを確かめる（quickstart.md 手動シナリオ 1・4）。

### Tests for US15（照合と一覧）

- [X] T019 [P] [US15] `Tests/MediaViewerCoreTests/FileNameSearcherTests.swift` の既存の期待値を更新する。`keywordCat`（「cat は対応メディアだけを返し…」）は `cat-folder` を含む `["Cat01.jpg", "a/my_cat.mov", "a/b/deep/cat-deep.png", "b/Cat01.jpg", "cat-folder"]`・`files.count == 5` にし、`cat-folder/x.jpg` を含まないことを明記して、テスト名を「cat は対応メディアとフォルダを返し、隠し・パッケージ・zip・リンク経由・一致したフォルダの中の一致しない名前を除く」に改める。`skipsUnreadableFolders`（「権限のないサブフォルダを飛ばして終わる」）は `search` フィクスチャの全体を `cat` で検索するため、`cat-folder` を含む `["Cat01.jpg", "a/my_cat.mov", "a/b/deep/cat-deep.png", "b/Cat01.jpg", "cat-folder"]` の5件に改める（`denied` は `cat` に一致しないため行にならず、`denied/cat-denied.jpg` も出ない）。`batches`（「バッチは batchSize 件以下に分けて流す」）は、`cat` の合計を `== 4` から `== 5` に改める。`grep -rn "FileNameSearcher(\|FixtureSets.search(" Tests` で（`FileNameSearcher(batchSize:…)` も拾う）、実際の検索器と `search` フィクスチャを使う他のテストに `cat-folder` などのフォルダの一致の影響がないか確かめ、あれば期待値を同じ方針で直す（R9、EC-92）
- [X] T020 [P] [US15] `Tests/MediaViewerCoreTests/FileNameSearcherTests.swift` に `FixtureSets.folderSearch(in:)` を使うテストを追加する。起点は `folder-search/Kyoto`。(1) `kyoto` の結果の相対パスが `2024_Kyoto`・`2024_Kyoto_old`・`kyoto_map.png`・`kyoto`・`kyoto/kyoto_01.jpg`・`kyoto/kyoto_day2`・`east/kyoto_day1`・`west/kyoto_day1`・`clips/kyoto_clip.mov`・`locked_kyoto`・`locked_kyoto/secret_kyoto.jpg` の集合と等しく、`.kyoto`・`Kyoto.app`・`kyoto_link`・`kyoto.zip`・`2024_Kyoto/IMG_0001.jpg`・`kyoto/IMG_0002.jpg`・起点そのものを含まない（US15-AS1・AS6・AS9、EC-92・EC-98）。(2) `*_Kyoto` は `2024_Kyoto` だけ（US15-AS2）。(3) `2024.10` は `2024.10_trip` だけ、`*.jpg` は `photos.jpg`（`kind == .folder`）と `.jpg` のファイルを含む（EC-97）。(4) `locked_kyoto` を `0o000` にして（`defer` で `0o755` に戻す）`kyoto` で検索すると `locked_kyoto` の行は出て `secret_kyoto.jpg` は出ず、ストリームは終わる（EC-33・EC-91）。(5) フォルダの行の値（`kind`・`name`・`typeDescription`・`creationDate`・`fileSize`）が `DirectoryLister.folderRow` / 親の `mediaFiles(in:)` の行と一致し、URL が起点の形（`/var/...` で始まる起点なら `/var/...`）（FR-139、R1）。(6) `SearchRequest(root: kyoto2024, pattern: "kyoto", matchesRoot: true)` では起点 `2024_Kyoto` そのものが行として出て、`matchesRoot: false` では出ない。`matchesRoot: true` でも隠し属性の起点（`.kyoto`）とパッケージの起点（`Kyoto.app`）は出ない（R3、data-model.md §1）
- [X] T021 [P] [US15] `Tests/MediaViewerCoreTests/FileNameSearcherTests.swift` に SC-053 のテストを追加する。`FixtureSets.folderSearchScale(in:)` の既定値で作った起点（`kyoto_root`）を `kyoto` で検索し、結果が一致するフォルダ50件とファイル50件のちょうど100件で、隠しフォルダ・パッケージ・フォルダへのリンク・zip・一致しないフォルダ・起点そのものが0件であること（SC-053）
- [X] T022 [P] [US15] `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` に `FakeSearcher` でフォルダの行（`DirectoryLister.folderRow` 相当の `kind: .folder` の `MediaFile`）を流すテストを追加する。(1) フォルダ2件とファイル3件を流して終えると `listing.search?.totalCount == 5`・`phase == .finished`・`state == .loaded`（US15-AS10、A-81）。(2) フォルダ1件だけで終えると `state == .loaded`、メッセージの状態にならない（EC-96）。(3) 0件で終えると `state == .empty`（EC-32）。(4) 種類フィルタを画像のみにしてフォルダ1件と動画1件を流すと、`listing.files` にフォルダの行だけが残り `state == .noMatches`（US15-AS5、FR-139）。(5) 種類フィルタがオンでフォルダだけが一致した場合は `state == .loaded`（EC-96）。(6) 動画の行をフォーカスして再生中にフォルダの行へフォーカスを移すと、`preview` が空になり `stopPlaybackSignal` が進む（US15-AS4、FR-139、FR-075）。(7) 名前・種類・作成日・「場所」の並べ替えで、フォルダとファイルが区別なく混ざって並ぶ（FR-084、A-25）。(8) 検索結果の表示中は先頭に `..` の行がない（FR-084）
- [X] T023 [P] [US15] `Tests/MediaViewerCoreTests/FocusNavigatorTests.swift` と `Tests/MediaViewerCoreTests/SlideshowSequenceTests.swift` に、`.folder` の行とメディアの行が混ざった並び（検索結果と同じ形）で、フルスクリーンの移動がフォルダの行に止まらずに飛ばし、スライドショーの対象にフォルダの行が含まれないことのテストを追加する。既存のテストで同じ並びを確認済みなら、そのテスト名を本書の注記に記して追加しない（US15-AS4、FR-139、SC-057） → 既存のテストで確認済みのため追加しない: `FocusNavigatorTests` の「フォルダと .. の行も読み飛ばす」（`[.parent, .folder, .media, .folder, .media]`）と「後ろにメディアがなければ前の最も近いメディアを選ぶ」（`[.media, .folder, .media, .folder, .archive]`）、`SlideshowSequenceTests` の「対象は表示順のメディアだけで、親・フォルダ・zip・zip 内フォルダを除く」と「開始はフォルダ選択だけなら対象先頭、対象なしなら nil」。
- [X] T024 [P] [US15] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に SC-054 の試験を追加する。既存の SC-016 の試験と同じ 100 フォルダ × 100 ファイルの階層を作り、フォルダ名の半数（50個）がキーワードを含むようにする。`FileNameSearcher().search(in:matching:)` で、フォルダ50件とファイルの一致件数の合計を確かめ、完了まで 3 秒以内であることを `ContinuousClock` で検査する。既存の SC-016 の試験（`folder-%03d` は `cat` を含まない）の件数5,000が変わらないことも確かめる。この試験は完了までの時間だけを測る。UI 停止の 100ms 基準は T055 と quickstart.md 手動シナリオ 7 の Instruments 計測で別に確かめる（SC-054、R9、憲章 II）

### Implementation for US15（照合と一覧）

- [X] T025 [US15] `Sources/MediaViewerCore/Search/FileNameSearcher.swift` でディレクトリを照合する。列挙の各項目で、`isDirectory == true` かつ `isSymbolicLink != true` なら、T012 の記録の後に `pattern.matches(fileName: url.lastPathComponent)` で照合し、一致したときだけ `url.resourceValues(forKeys: [.isPackageKey, .creationDateKey])` を読み、`isPackage != true` なら `DirectoryLister.folderRow(at: rebase(url), creationDate:)` をバッチに加える。一致しないディレクトリには先読み済みのキー以外を問い合わせない。`request.matchesRoot == true` のときだけ、列挙の前に起点そのものを同じ規則（ディレクトリ・リンクでない・隠し属性 `.isHiddenKey` でない・パッケージでない・名前の一致）で照合し、記録してから行を加える。ファイルの扱い（拡張子による判定・ファイルへのリンク・フォルダへのリンクの除外）は変えない。読み取り権限のないディレクトリは列挙器が URL を返すため照合され、中は `errorHandler` で飛ばされる。型とプロトコルのドキュメントコメントを「メディアファイルとフォルダ」に改める（FR-082・FR-083・FR-139、US15-AS1・AS2・AS6・AS9、EC-33・EC-91・EC-92・EC-97、A-78・A-79、R1、T019〜T021 を通す）
- [X] T026 [P] [US15] `Sources/MediaViewerCore/Search/SearchPattern.swift` の `matches(fileName:)` とキーワードのドキュメントコメントに「ファイル名とフォルダ名。名前全体を照合し、フォルダ名の「.」を拡張子として扱わない」を記す。引数名と挙動は変えない（FR-082、EC-97、R1）
- [X] T027 [P] [US15] `Sources/MediaViewerApp/FileList/FileListViewController.swift` の `refresh` で、検索結果の `.empty` の文言 `"該当するファイルはありません"` を `"該当する項目はありません"` に変える。通常のフォルダの `"対応するメディアファイルがありません"` と、`MediaTypeFilter` の絞り込み中のメッセージは変えない（EC-32、FR-084、R5）
- [X] T028 [US15] `README.md` の検索の節（「ファイル名の検索」の箇条）は Phase 6 の T053 でまとめて更新するため、この Phase では変更しない。代わりに `grep -rn "該当するファイルはありません" Sources Tests` を実行し、検索結果の `.empty` 以外の箇所（`MediaTypeFilter` の絞り込み中のメッセージ）だけが残っていることを確かめる
- [X] T029 [US15] `swift build` → `swift test` → `swift test --filter MediaViewerPerformanceTests` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/009-folder-search/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T030 [US15] 手動: ユーザーに `scripts/make-fixtures.sh ~/MediaViewerFixtures` と `open .build/MediaViewer.app` の実行を依頼する。3ペインの表示を確認した後、`specs/009-folder-search/quickstart.md` の手動シナリオ 1（フォルダとファイルの一致: 出る行・出ない行、汎用アイコン・種類・作成日・「場所」列、2つの `kyoto_day1` の見分け、サムネイル形式のツールチップ、件数、並べ替え、`*_Kyoto`・`2024.10`・`*.jpg`、0件と「フォルダだけ」のメッセージ）と手動シナリオ 4（プレビューが空・動画の停止、フルスクリーンの移動、スライドショー、種類フィルタ）を確認してもらう。結果を「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T031 [US15] 直前の自動・GUI ゲート合格後、`Sources/MediaViewerCore/Search/`・`Sources/MediaViewerApp/FileList/FileListViewController.swift`・`Tests/`・`specs/009-folder-search/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: フォルダが検索結果に通常のフォルダの行として出て、件数・メッセージ・種類フィルタ・プレビュー・フルスクリーン・スライドショーが FR-139 のとおりに振る舞う。

## Phase 4: User Story 15 — フォルダの行を開く・履歴

**Goal**: 検索結果のフォルダの行をダブルクリック・⌘↓・「中を表示」で開くと、検索結果の表示を終え（検索中なら止め）、そのフォルダの一覧に切り替わり、ツリーも同期し、フォーカスはファイルリストに残る。⌘[ で検索前の場所へ戻り、検索結果には戻らない。EC-99・EC-100 の履歴が成り立つ。

**Independent Test**: `folder-search/Kyoto/east` を表示してから `folder-search/Kyoto` で `kyoto` を検索し、`2024_Kyoto` を3つの手段で開いてファイルリスト・ツリー・フォーカスを確かめ、⌘[ で `east` に戻ること、EC-99・EC-100 の戻り先を確かめる（quickstart.md 手動シナリオ 2・3）。

### Tests for US15（開く・履歴）

- [X] T032 [P] [US15] `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` にフォルダの行を開くテストを追加する。実在するフォルダ（一時ディレクトリ）の行を `FakeSearcher` で流す。(1) 検索中に `openItem(folderRowURL)` を呼ぶと、`FakeSearcher.cancelledCount` が増え、`listing.search == nil`・`listing.folder == folderRowURL`・先頭に `..` の行・`treeSyncRequest?.folder == folderRowURL`・`settings.viewSettings.lastFolder == folderRowURL` になる。続けて古いストリームへ `send` したバッチは一覧に混ざらない（FR-140、US15-AS3、EC-93）。(2) 検索が終わった後に開いても同じ。(3)「場所」で並べ替え中に開くと、保存済みの並べ替えに戻る（R6）。(4) メディアの行で `openItem` を呼んでも何も変わらない（FR-140）。(5) `onLocationEvent` が `.openedSearchResultFolder(leavingFocus: folderRowURL)`（開く直前のフォーカス）を1回だけ受け取り、検索結果の表示中でないフォルダの行を開いた場合は従来どおり `.navigated` を受け取る（R7）。(6) 読み取り権限のないフォルダの行（`0o000`、`defer` で戻す）を開くと `listing.state == .denied` になり、`..` の行がある（EC-91）。EC-101（検索前のフォルダのゴミ箱）のテストは、判断を Core に移したため T040 の (8) に置く
- [X] T033 [P] [US15] `Tests/MediaViewerCoreTests/HistoryNavigatorTests.swift` に、`Env` の一時ディレクトリに `folder-search` 相当の階層を作り、既存の Env の実際の `FileNameSearcher` を使って次のテストを追加する。(1) A を表示 → 起点を A の親にして検索 → 検索中に `host.presentation` をサムネイル形式に変える → A と異なる F の行を開くと、履歴が …, A, F になり、A の表示の状態がサムネイル形式、`canGoForward == false`。`goBack()` で A に戻り、検索結果には戻らない（FR-113、US15-AS3、SC-055）。(2) EC-99: A だけの履歴で、起点を A の祖先にして検索し A の行を開くと、新しい履歴は記録されず、A の表示の状態が検索終了時のものになり、`canGoBack == false`。A の前に履歴がある場合は `goBack()` で A より前へ移る（EC-99）。(3) EC-100: zip の中の階層 D を表示 → zip を含むフォルダより上を起点に検索 → F の行を開くと履歴が …, D, F になり、zip を含むフォルダの一覧は記録されない。`goBack()` で D へ戻る（EC-100）。(4) 開いたフォルダが開く直前に消えていて `.notFound` になった場合、記録は取り消され、A は検索終了時の表示の状態のまま現在の履歴として残る（R7 の 3、EC-62）。既存の「検索結果の表示中にフォルダを選ぶと新しい履歴になる（FR-113）」「検索を終えた後の表示の状態は現在の履歴になる（R76）」の期待値は変えない

### Implementation for US15（開く・履歴）

- [X] T034 [US15] `Sources/MediaViewerCore/Browser/BrowserModel.swift` の `LocationEvent` に `case openedSearchResultFolder(leavingFocus: URL?)` を加え、`LocationChangeReason` に対応する `case openedSearchResultFolder` を加える。`selectFolder(_:reason:)` の通知の分岐で、この理由なら `onLocationEvent?(.openedSearchResultFolder(leavingFocus: leavingFocus))` を送る（`leavingFocus` は既存どおり呼び出しの直前に読む）。`openItem(_:)` の `.folder` の分岐で、`isShowingSearchResults` なら `navigateToFolder(file.url, selecting: nil, reason: .openedSearchResultFolder)`、そうでなければ従来どおり `.navigated` にする。列挙の停止・`leaveSearchIfNeeded`・`lastFolder`・`treeSyncRequest` は既存の経路のまま変えない。`grep -rn "LocationEvent\|onLocationEvent\|case .navigated" Sources Tests` で網羅的な `switch` を探し、新しい case を扱う（FR-140、US15-AS3、EC-93、R6・R7、contracts/folder-search.md、T032 を通す）
- [X] T035 [US15] `Sources/MediaViewerCore/History/HistoryNavigator.swift` の `handleLocationEvent(_:)` に `.openedSearchResultFolder(leavingFocus)` を加える。`model.historyLocation` と `currentViewState()` を得られなければ何もしない。得られたら、まず `history.updateCurrentViewState(viewState)` で現在の履歴（検索前の場所）に検索終了時の表示の状態を反映し、続けて `.navigated` と同じ処理（同じ場所なら `clearSnapshot()` で終える。違えば反映後の `history` を `snapshot` にし、`record(location:viewState:kind: .navigation, leavingFocus:)` で記録し、記録できたら `snapshotVersion` を設定、できなければ `clearSnapshot()`）を行う。`.navigated` の既存の処理・`canGoBack`・`canGoForward`・検索結果の表示中の「戻る」の分岐は変えない（FR-107・FR-113・FR-140、EC-99・EC-100、R7、data-model.md §5、T033 を通す）
- [X] T061 [US15] `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` に EC-102 のテストを追加する。`FixtureSets.folderSearch(in:)` の `.hidden-parent/search-root/kyoto_open` 相当の実在する階層を使い、検索結果から F を開いた後に `completeSearchResultTreeSync(request, selectedFolder: V)` で表示可能な祖先 V を通知する。(1) `listing.folder`・履歴への通知先・フォーカス・`treeSyncRequest.folder` は F のままで、`lastFolder` だけ V になり、追加の列挙や移動通知はない。(2) F 自身の通知なら F を保存する。(3) 古い ID・別の依頼・F の祖先でない場所（文字列 prefix が同じ兄弟も含む）・重複した完了は無視する。(4) 次のツリー選択・検索開始・zip を開く・履歴移動を含む `resetForNavigation` の後は、同じ F を再表示していても古い依頼を無視する。(5) 通常の一覧から開いた依頼・履歴からの依頼は対象外。(6) `.notFound` の場合は保存しない。Core では App の表示可否を推測せず、祖先関係と依頼の有効性を検証する。実装前に追加したテストの失敗を確認する（FR-140、EC-102、R10）。
- [X] T062 [US15] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に `completeSearchResultTreeSync(_ request: TreeSyncRequest, selectedFolder: URL)` を実装する。検索結果のフォルダを開く `selectFolder(_:reason:)` の `resetForNavigation()` の後に同期依頼の ID を保留し、次の reset で保留を消す。完了時は保留 ID・現在の依頼と一覧の場所の一致、検索結果・zip の表示中でも `.notFound` でもないこと、選択先が依頼のフォルダそのものまたは祖先であること（標準化した pathComponents）を検査する。受け入れたら保留 ID を消し、`SettingsStore.viewSettings.lastFolder` だけを選択先へ更新する。一覧・履歴・フォーカスは変えず、存在確認・ディレクトリ列挙を追加しない（EC-102、R10、T061 を通す）。
- [X] T063 [US15] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の `syncSelection(to:)` で、既存の `expandAncestors` が返したノードを選択できた後に、`model.completeSearchResultTreeSync(request, selectedFolder: node.url)` を呼ぶ。既存の取り消し・現在の依頼 ID と一覧の場所の検査、`isRestoringSelection`、スクロール・フォーカスの規則を保つ。App で保存の判断や `selectFolder` による祖先への移動を行わない。通常の同期の保存先は Core が変更せず、検索結果から開いたフォルダの同期にだけ適用する（FR-140、EC-102、R10）。
- [X] T036 [US15] `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/009-folder-search/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T037 [US15] 手動: ユーザーに `open .build/MediaViewer.app` の実行を依頼し、3ペインの表示を確認した後、`specs/009-folder-search/quickstart.md` の手動シナリオ 2（ダブルクリック・⌘↓・右クリックメニューの「中を表示」で開く、検索バーが消え `..` が出る、ツリーの選択、フォーカスがファイルリストに残る、⌘[ / ⌘] の行き先、フォルダの行の右クリックメニューの「中を表示（⌘↓）」と区切り線・「上の階層へ」が出ない、メディアの行で ⌘↓ が何もしない、検索中に開いたときに結果が混ざらない、`lastFolder` の保存、手動シナリオ 2-8 の非表示のフォルダに対する祖先の選択と保存・履歴・フォーカス）と手動シナリオ 3（EC-99・EC-100）を確認してもらう。確認点は FR-140 と product の contracts/keyboard-and-menus.md（右クリックメニュー（ファイルリスト））に合わせ、メディアの行の右クリックメニューに「中を表示」が出るかどうかは合否の条件にしない（既存の契約と実装の食い違い。research.md R6 の注記）。見えた状態だけを「Phase 検証記録」に書く。手動シナリオ 2-7 の20回（SC-055）は T055 で記録してもよい。結果を「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T038 [US15] 直前の自動・GUI ゲート合格後、`Sources/MediaViewerCore/Browser/BrowserModel.swift`・`Sources/MediaViewerCore/History/HistoryNavigator.swift`・`Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`・`Tests/`・`specs/009-folder-search/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: US15 の Independent Test（探して開き、⌘[ で検索前に戻る）が単独で成り立つ。

## Phase 5: User Story 15 — ファイル操作・外部の変更・検索中の名前の変更

**Goal**: 検索結果のフォルダの行の名前の変更・ゴミ箱・移動・外部の削除で、行と中の結果が FR-087・FR-105 のとおりに残る・外れる。検索中にフォルダの名前を変えても、照合済みかどうかで EC-94 のとおりに扱う。検索結果の一覧から検索前のフォルダの祖先をゴミ箱に入れた・移動した場合は EC-101（T001 の確定内容）に従う。

**Independent Test**: `kyoto` の検索結果で `kyoto` フォルダの行の名前を変え、ゴミ箱に入れ、Finder で移動して、行と中の結果の表示・外れ方・プレビューを確かめる。検索中にフォルダの名前を変えて EC-52・EC-94 を確かめる（quickstart.md 手動シナリオ 5・6）。

### Tests for US15（ファイル操作・名前の変更）

- [X] T039 [P] [US15] 新規 `Tests/MediaViewerCoreTests/SearchRenameLedgerTests.swift` に `SearchRenameLedger` のテストを追加する。ディスクは使わず、URL と `SearchVisitLog` だけで組み立てる。(1) 初期状態で `isEmpty == true`。`addStream(visits:)` は 0, 1, … を返す。(2) `place(_:fromStream:)` は、その列挙を始めた後の名前の変更だけを順に当てる（列挙0の開始前の変更は当てない。列挙0の開始後の変更 r1・r2 は順に当てる）。(3) `.folder` の行の URL の最後の要素が変わったら `name` も新しい名前にし、メディアの行と、祖先だけが変わったフォルダの行の `name` は変えない（FR-105）。(4) `hasVisited(_:)` は、各列挙の開始後の名前の変更を逆順に戻した場所で `visits.contains` を問う（F → F′ → F″ と2回変えた後の `hasVisited(F″)` が、列挙0の記録の F で true）。複数の列挙のどれかに記録があれば true。(5) `recordRename(_:visited: false)` の後、その変更より前に始めた列挙から届いた、変更 k の時点の場所が k の元の場所と同じ結果（F そのもの）は `place` が nil を返して捨て、F の中の結果は付け替えて残す。`visited: true` なら F の結果は F′ に付け替えて残す。(6) 名前の変更の後に始めた列挙の結果は捨てない（data-model.md §3、FR-105、EC-52・EC-94、R3）
- [X] T040 [P] [US15] `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` に検索結果のフォルダの行のファイル操作のテストを追加する。実在する一時ディレクトリの F（中に g）を `FakeSearcher` で流す。(1) F をディスクで `zzz` に変えて `didRenameFolder(from: F, to: zzz)` を呼ぶと、F の行は `name == "zzz"` の新しい URL で残り、g の URL は `zzz/g` になり（「場所」が新しい名前）、「名前」で並べ替え中なら並べ直され、選択・フォーカスは新しい URL で保たれる（US15-AS7、FR-087・FR-105、SC-056）。(2) 続けて `zzz` をディスクから削除して `reloadCurrentFolder()`（または `handleFileSystemEvent` で親を通知）すると、`zzz` の行と `zzz/g` が両方外れる。これは `rebaseSearchIndex` がキーの変わらない行（`zzz`）の URL を付け替えていないと失敗することを確かめる（R4）。(3) g をフォーカスしてプレビュー中に F を削除して `reloadCurrentFolder()` を呼ぶと、F と g が外れ、プレビューが空になり、`totalCount` が減る（US15-AS8、EC-35、FR-087）。(4) アプリの外で F を別の場所へ移動して `handleFileSystemEvent` を送ると、F と g が外れ、新しく作ったフォルダ `kyoto_new` は加わらない（EC-95）。(5) F を複製したフォルダは加わらない（FR-087）。(6) 起点の配下でないフォルダの名前の変更では結果が変わらない。(7) 検索が終わった後（`phase == .finished`）に、行でない起点の配下のフォルダ H（キーワードに一致しない名前）をディスクで一致する名前 H′ に変えて `didRenameFolder(from: H, to: H′)` を呼ぶと、`listing.files` の行数と `totalCount` は増えず、H′ の行もなく、`FakeSearcher.requests.count` も増えない（追加の列挙を始めない）（EC-94 の前半、FR-105）。(8) EC-101: 検索前のフォルダ A（例 `trip/day1`）を表示してから、A の祖先 P（例 `trip`）を含む起点で検索し、P のフォルダの行と P の中のファイルを流す。P をディスクから削除して `leaveTrashedFolders([P], origin: .fileList)` を呼ぶと false を返し、`isShowingSearchResults` のまま、`listing.folder`・`settings.viewSettings.lastFolder`・`treeSyncRequest` は変わらない。続けて `reloadCurrentFolder()` を呼ぶと P の行と P の中の結果が外れる。続けて Esc と同じ `selectFolder(model.listing.folder)`（`FileListViewController.leaveSearchResults` の経路）を呼ぶと、`isShowingSearchResults == false` になり、`onLocationEvent` が `.notFound(HistoryLocation(folder: A))` を受け取る（EC-101 の後半、EC-62）。同じ状態で `origin: .tree` を渡すと true を返して親へ移り、検索結果の表示を終える（FR-079）。検索結果の表示中でなければ `origin` に関わらず従来どおりの判断になる。既存の「leaveTrashedFolders は検索前のフォルダの祖先なら親へ移って表示を終え…」のテストはツリーからの経路（既定値 `.tree`）の確認として期待値を変えない。⌘[ と履歴の確認は、`HistoryNavigator` が要るため `Tests/MediaViewerCoreTests/HistoryNavigatorTests.swift` の `Env` に置く: A を表示 → P を起点に検索 → P をディスクから削除し、`FileOperationCoordinator.trash` と同じ順に `navigator.didRemoveItems([P])` → `model.leaveTrashedFolders([P], origin: .fileList)`（false）→ `model.reloadCurrentFolder()` を呼ぶ → `goBack()` で検索結果の表示が終わって `.notFound` になり、A と P の配下の場所が履歴に残らない（既存の「見つからなかった移動は記録を取り消し、現在を残さない（EC-62）」と同じ確かめ方。EC-101、EC-62、FR-109）。T049 の前に、(8) の `.fileList` の期待が失敗する（引数がない、または親へ移る）ことを確認する（EC-101、R8、US15-AS8、EC-36）。(9) EC-101 の移動: (8) と同じ状態で、P をディスクで起点の外の一時ディレクトリ Q へ移動し（`FileOperationCoordinator.transfer` と同じく `leaveTrashedFolders` は呼ばない）、`reloadCurrentFolder()` を呼ぶと、`isShowingSearchResults` のまま、`listing.folder`・`settings.viewSettings.lastFolder`・`treeSyncRequest` は変わらず、P の行と P の中の結果が外れ、`Q/P` の行は加わらない。続けて `selectFolder(model.listing.folder)` を呼ぶと `.notFound(HistoryLocation(folder: A))` になる。(9) は現在のコードでも通る見込みのため、失敗の確認は要らず、挙動を固定する回帰テストとして扱う（EC-101、FR-087、EC-35）。(10) EC-36（変更）: 既存の「検索起点そのものが消えると、すべての結果を外して表示は続ける」と同じ組み立てで、検索前のフォルダ（例 `trip/day1`）を表示してから起点 `s` で検索し、フォルダの行 `s/x`・`s/y` と、その中のファイル `s/x/clip.mp4`・`s/y/a.jpg` を流して終える。`clip.mp4` をフォーカスしてから `s` をディスクから削除して `handleFileSystemEvent([s])` を送ると、フォルダの行と中の結果がすべて外れ（`listing.files.isEmpty`・`state == .empty`）、`isShowingSearchResults` のまま、検索バーのキーワードと起点、`listing.folder`・`settings.viewSettings.lastFolder`・`treeSyncRequest` は変わらず、`stopPlaybackSignal` が進む。現在のコードでも通る見込みのため、(9) と同じく挙動を固定する回帰テストとして扱う（EC-36、FR-087）
- [X] T041 [P] [US15] `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` に検索中の名前の変更のテストを追加する。`FakeSearcher` の `requests` の `visits`・`matchesRoot` と `send(_:to:)` を使い、テストから記録を操作して列挙の進み具合を再現する。(1) 照合済み: 列挙0の `visits` に F を `record` し（F は一致しなかったので行は流さない）、F をキーワードに一致する名前 F′ に変えて `didRenameFolder` を呼ぶと、追加の列挙が `root == F′`・`matchesRoot == false` で始まり、F′ は一覧に加わらない（EC-94 の前半）。(2) 未照合: F を記録せずに名前を変えると、追加の列挙が `matchesRoot == true` で始まる。その後に列挙0から F の行（古い URL）が届いても捨てられ、追加の列挙が流した F′ の行だけが新しい名前で残る（EC-94 の後半）。(3) 照合済みで一致した F の行が既に一覧にあるとき、名前を変えると行は新しい名前で残り、キーワードに一致しなくなっても外れない。名前の変更の後に列挙0から届いた F の中の結果は F′ の場所で加わる（EC-52、FR-105）。(4) 列挙0から F の行が名前の変更の後に届いた（照合済み）場合、行は F′ の URL と名前で加わる（R3）。(5) 起点そのものの名前を変えた場合は、追加の列挙が新しい起点を `matchesRoot == false` で列挙し、起点は行にならない（既存の EC-52 のテストの期待値を保つ）。(6) 同じ結果が元の列挙と追加の列挙の両方から届いても1件になる
- [X] T042 [P] [US15] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` の「10,000 件の検索結果での didRenameFolder が 0.1 秒以内」の試験に、名前を変えるフォルダそのものの行と、ほかのフォルダの行（例: 100件）を結果に含めたケースを加え、`rebaseSearchIndex` の修正後も 0.1 秒以内であることを確かめる（R4・R9、001 の R67、憲章 II）

### Implementation for US15（ファイル操作・名前の変更）

- [X] T043 [US15] 新規 `Sources/MediaViewerCore/Search/SearchRenameLedger.swift` に `public struct SearchRenameLedger: Sendable` を実装する。フィールドは `renames: [RenamedFolder]`（今の検索の間の名前の変更、順）・`streams: [Stream]`（列挙ごとの `visits: SearchVisitLog` と開始時点の `renames.count`）・`rejudged: [Int: String]`（未照合として扱った名前の変更の `renames` の位置 → 元の場所の標準化したパス）。API は `public init()`・`public var isEmpty: Bool`（名前の変更がない）・`public mutating func addStream(visits:) -> Int`・`public func hasVisited(_ folder: URL) -> Bool`（各列挙について、開始後の名前の変更を逆順に戻した場所で `visits.contains`）・`public mutating func recordRename(_ renamed: RenamedFolder, visited: Bool)`（`visited == false` なら `rejudged` に元の場所を記録）・`public func place(_ file: MediaFile, fromStream index: Int) -> MediaFile?`（開始後の名前の変更を順に当て、途中の変更 k が `rejudged` にあり、k の時点の場所が k の元の場所と同じなら nil。`.folder` の行の最後の要素が変われば `name` も変える）。ディスクを読まず、パスは `standardizedFileURL.path` で比べる。逆向きの付け替えに必要なら `Sources/MediaViewerCore/Model/RenamedFolder.swift` に `RenamedFolder` の逆向きの付け替え（例: `reversed`）を足し、`Tests/MediaViewerCoreTests/RenamedFolderTests.swift` にそのテストを足す（data-model.md §3、FR-105、EC-52・EC-94、R3、T039 を通す）
- [X] T044 [US15] `Sources/MediaViewerCore/Browser/BrowserModel.swift` の `rebaseSearchIndex(_:moved:)` で、キーが変わらないエントリ（`else` の分岐）の URL にも `moved[$0] ?? $0` を当てる（`renamed.rebaseOrSelf` は当てない。キーが変わらないエントリで変わるのは名前を変えたフォルダの行そのものだけ）。`pruneMissingResults`・`removeSearchResults`・`didRenameItem`・`rebuildListing` は変えない（R4、FR-087・FR-105、US15-AS7・AS8、T040 の (2) を通す）
- [X] T045 [US15] `Sources/MediaViewerCore/Browser/BrowserModel.swift` の `searchRenames: [RenamedFolder]` を `searchLedger = SearchRenameLedger()` に置き換える。(1) `startSearchStream(in:matching:matchesRoot:)` は `SearchVisitLog` を作り、`searchLedger.addStream(visits:)` で番号を得て、`SearchRequest(root:pattern:matchesRoot:visits:)` で検索器へ渡し、バッチを `appendSearchResults(_:fromStream:)` に番号付きで渡す。`startSearch` は `matchesRoot: false` で呼ぶ。(2) `appendSearchResults(_:fromStream:)` は `!searchLedger.isEmpty` のとき、既存の `searchRenames.reduce` の付け替えを `searchLedger.place(_:fromStream:)` に置き換え（nil は捨てる）、既存の重複除き（同じ標準化したパスが索引にある・バッチ内で重複）・マージ・索引の追加・`totalCount` の更新を行う。(3) `didRenameFolder(from:to:)` の検索中の分岐で、起点そのものか祖先の名前の変更なら既存どおり `searchLedger.recordRename(renamed, visited: true)` の後に新しい起点を `matchesRoot: false` で列挙する。起点の配下のフォルダなら、`recordRename` の前に `let visited = searchLedger.hasVisited(oldURL)` を求め、`recordRename(renamed, visited: visited)` の後に `newURL` を `matchesRoot: !visited` で列挙する。(4) `resetForNavigation()` の `searchRenames.removeAll()` を `searchLedger = SearchRenameLedger()` に置き換える。照合済みの記録は列挙ごとに作り、検索を止めたら台帳ごと捨てる（data-model.md §4、FR-105、EC-52・EC-94、R2・R3、T041 を通す）
- [X] T046 [US15] T040 の (8)（`HistoryNavigatorTests.swift` に置いた ⌘[ と履歴の確認を含む）と (9) の期待値が、T001 で採用済みの EC-101（ゴミ箱・移動とも検索結果の表示を続ける）と一致することを確認する。採否の再確認や不採用の分岐は不要。
- [X] T047 [US15] `grep -rn "searchRenames" Sources Tests` が0件であることと、`Sources/MediaViewerCore/Search/` の新しいファイルが AppKit を import していないことを確かめる
- [X] T048 [US15] `Sources/MediaViewerCore/Browser/BrowserModel.swift` の T015 で入れた `SearchRequest(root:pattern:)` の暫定の呼び出しが T045 の形に置き換わり、すべての列挙が台帳に登録されていることを確かめる（`startSearchStream` 以外で `searcher.search` を呼んでいないこと）
- [X] T049 [US15] T001 の採用済み EC-101 に従い、`Sources/MediaViewerCore/Browser/BrowserModel.swift` の `leaveTrashedFolders(_:)` に `origin: OperationOrigin = .tree` を加え、`origin == .fileList` かつ `isShowingSearchResults` なら `FolderNavigation.folderToShow` を問わずに false を返す。それ以外は既存のまま。ドキュメントコメントに、検索結果の一覧からのゴミ箱では検索結果の表示を続ける（EC-101）旨を加える。`Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift` の `trash(_:origin:)` は `model.leaveTrashedFolders(trashedSources, origin: origin)` と経路を渡すだけにし、App に検索結果の表示の分岐を作らない。直後のコメント（「ファイルリストからのゴミ箱はそれらを対象にしないため false になり…」）を、検索結果では検索前のフォルダの祖先を選べるため経路で分ける（判断は `BrowserModel`）旨に改める。移動（`transfer`）は `leaveTrashedFolders` を呼ばないため変更しない（EC-101 の移動は T040 の (9) で固定する）（EC-101、R8、FR-079・FR-087、US15-AS8、EC-36、T040 の (8)・(9) を通す）
- [X] T050 [US15] `swift build` → `swift test` → `swift test --filter MediaViewerPerformanceTests` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/009-folder-search/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T051 [US15] 手動: ユーザーに `scripts/make-fixtures.sh ~/MediaViewerFixtures` と `open .build/MediaViewer.app` の実行を依頼し、3ペインの表示を確認した後、`specs/009-folder-search/quickstart.md` の手動シナリオ 5（フォルダの行の名前の変更・ゴミ箱・Finder での移動と新規作成・⌘C と ⌘V / ⌥⌘V の淡色・⌘D・ドラッグでの移動・EC-101 の検索前のフォルダのゴミ箱と移動、ツリーからのゴミ箱との違い）と手動シナリオ 6（`chmod 000` の権限なしのフォルダ・検索中の名前の変更）を確認してもらう。手動シナリオ 5-5（ゴミ箱）と 5-6（移動）では、ツリーが読み直されて検索前のフォルダの行が消えた後も、ツリーで別のフォルダが選ばれた状態にならず、検索バーが残って検索結果の表示が続くことを、数秒待ってから確認点に含める（Core のテスト T040 の (8)・(9) は `treeSyncRequest` しか見ないため、`DirectoryTreeViewController.outlineViewSelectionDidChange` から `model.selectFolder` が呼ばれる経路を検出できない）。崩れた場合は不合格として記録し、T060 へ進む。権限を変えた `locked_kyoto` は確認の後に `chmod 755` で戻してもらう。結果を「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T060 [US15] T051 の手動シナリオ 5-5・5-6 で、ツリーの読み直しの後に選択が別のフォルダへ移り、検索結果の表示が終わった場合に限り行う（崩れなければ「不要」と「Phase 検証記録」に書いてチェックする）。推測で直さず、まずツリーの読み直し（`FileOperationCoordinator.notifyFoldersChanged` → `onFoldersChanged`）で選択中のノードが消えたときに `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の `outlineViewSelectionDidChange` が呼ばれ、`model.selectFolder` に至っていることを、ログまたは lldb のブレークポイントで確かめる（GUI の起動はユーザーに依頼する）。確かめられたら、ユーザーの操作でない選択の変化（読み直しによるもの）で `model.selectFolder` を呼ばないよう、読み直しの経路を既存の `isRestoringSelection` で囲むなど、ツリーの読み直しの範囲で直す。ツリーからのゴミ箱（FR-079）・ツリーでのクリックやキー操作による選択・EC-36 の起点の消失の挙動は変えない。直した後に T050 の自動ゲートを再実行し、T051 の手動シナリオ 5-5・5-6 と、ツリーからのゴミ箱の比較の手順をユーザーに再確認してもらう。原因がツリーの読み直しでない、または直すには Core の判断（`BrowserModel` の EC-101 の扱い）を変える必要がある場合は、作業を止めて状況を報告し、plan.md・research.md R8 に戻って設計を見直す（EC-101、FR-079、AGENTS.md の AppKit UI の不変条件）
- [X] T052 [US15] 直前の自動・GUI ゲート合格後、`Sources/MediaViewerCore/`・`Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift`・（T060 を行った場合）`Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift`・`Tests/`・`specs/009-folder-search/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: US15 の全受け入れシナリオ（AS1〜AS10）と EC-32〜EC-102 の本 feature の項目が自動テストと GUI で確かめられている。

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 利用者向け文書を更新し、成功基準の回数・実時間の証拠を揃え、Living spec へ反映して feature を凍結する。

- [X] T053 [P] `README.md` の検索の箇条（「ファイル名の検索」）とキーボードの表を更新する。名前（ファイル名とフォルダ名）で検索し、一致したフォルダも通常のフォルダの行として結果に混ざること、隠し・パッケージ・フォルダへのリンク・zip・起点は出ないこと、件数はファイルとフォルダの合計、フォルダの行はダブルクリック・⌘↓・「中を表示」で開け、開くと検索結果を終えて ⌘[ で検索前に戻ること、フォルダの行のファイル操作（ペーストはできない）と、ゴミ箱・名前の変更での行と中の結果の扱い、0件のメッセージが「該当する項目はありません」であることを追記し、「ファイル名の検索」だけを示す古い記述を残さない（FR-080・FR-084・FR-087・FR-140、A-81・A-82）
- [X] T054 最終の自動ゲートとして `swift build` → `swift test` → `swift test --filter MediaViewerPerformanceTests` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行する。`grep -rn "import AppKit" Sources/MediaViewerCore` が0件であることも確認する。結果を `specs/009-folder-search/quickstart.md` の「Phase 検証記録」へ追記する（憲章 I・II・IV）
- [X] T055 手動: ユーザーに `open .build/MediaViewer.app` を依頼し、成功基準の回数と実時間を記録してもらう。SC-055（ダブルクリック・⌘↓・「中を表示」を合わせて20回開き、ファイルリストは毎回そのフォルダ、ツリーはそのフォルダまたは EC-102 の祖先、⌘[ で検索前に戻った回数20・検索結果に戻った回数0）、SC-056（フォルダの行の名前の変更とゴミ箱を各10回、古い名前のまま残った件数0・残った件数0）、SC-057（フォルダの行を20回選択してプレビューが空になった回数20、フルスクリーンとスライドショーでフォルダの行に止まった回数0）、SC-054（quickstart.md 手動シナリオ 7。完了まで 3 秒以内の条件は T024 の実測で確認し、UI 応答はユーザーが Instruments の Hangs を 100ms 未満のしきい値（例: 33ms 超）に設定して記録する。10,000 ファイル以上の階層で検索中にスクロール・選択・プレビュー・ツリーの各操作を行い、検索区間の 100ms 以上のイベントが0件であることを確かめる。trace のパス・Instruments のバージョンとしきい値・操作・検索回数・イベント件数と最大継続時間を残す。計測未実施なら目視だけで合格にしない）。結果と環境（macOS・機種・build 種別）、自動試験の SC-053・SC-054 の結果を `specs/009-folder-search/quickstart.md` の「最終検証結果」へ追記する。未実施なら未チェックに保つ
- [X] T059 T056 の前に、research.md R6 の注記の食い違い（ファイルリストの右クリックメニューで、メディアの行にも「中を表示」が淡色で出る。FR-140 と product の contracts/keyboard-and-menus.md（右クリックメニュー（ファイルリスト））はフォルダ・zip ファイルの行にだけ加えると定める）を、T037 の「Phase 検証記録」に書いた見えた状態とあわせてユーザーに示し、扱いを確認する。憲章「仕様の管理」に従い、実装が product の契約に反している不具合として扱う場合は、本 feature の統合後にクリーンな master から `bugfix/<slug>` を切って `/speckit-bug-assess` を行う候補として、slug 案・症状・該当 ID（FR-140、contracts/keyboard-and-menus.md の右クリックメニュー（ファイルリスト））を `specs/009-folder-search/quickstart.md` の「最終検証結果」に記録する（`.specify/bugs/` は bug 拡張の assess で作るため、本 feature では作らない）。契約の文言を実装に合わせると決まった場合は、仕様の変更として別の feature（sdd-increment）の候補を同じ節に記録する。どちらの場合も本 feature の実装は変えず、T056 では FR-140 を spec の文言のまま反映し、契約の右クリックメニューの既存の記述は変えない
- [X] T056 T054・T055・T059 が終わり、T054・T055 の自動・GUI がすべて合格した場合に限り、`specs/009-folder-search/spec.md` の「反映先」の表どおり、`specs/product/search.md`（FR-080・FR-082〜FR-085・FR-087・FR-105・FR-139・FR-140、US15-AS1〜AS10、EC-32・EC-33・EC-35・EC-36・EC-52・EC-91〜EC-102、SC-053〜SC-057、A-76〜A-82、検索結果のエンティティ）、`specs/product/navigation-history.md`（FR-113）、`specs/product/overview.md`（A-14）、`specs/product/directory-tree.md`（A-34）、`specs/product/contracts/keyboard-and-menus.md`（検索結果を表示している間の件数・名前の列・並べ替え・ファイル操作・一覧から外れる項目・⌘↓ とダブルクリック、ファイルリストの右クリックメニューの検索結果の行、検索結果の表示中の履歴、検索バーの件数）へ全追加／変更 ID を移す。EC-101（T001 で確定した内容）と EC-102 も「反映先」の表どおり search.md と契約へ反映する。契約は参照で記載して ID 本文を重複定義せず、Clarifications は feature に残す。手順と ID の付け方は `specs/product/README.md` に従い、`specs/009-folder-search/spec.md` の冒頭へ移行済み・凍結の注記を付す（憲章「仕様の管理」）
- [X] T057 `specs/009-folder-search/spec.md` の「反映先」の表と `specs/product/` の ID・リンク・契約を照合し、反映漏れ・重複・「ファイルだけ」を前提にした古い記述（「該当するファイルはありません」、件数・途中経過・権限なし・起点の消失・検索中の名前の変更をファイルに限る記述）が残っていないことを確認する。`specs/001-three-pane-media-viewer/` が未変更であること、`specs/009-folder-search/` の spec・plan・research・data-model・contracts・quickstart が実装の記録として整合していることも確認する
- [X] T058 T054〜T057 の合格後、`README.md`・`Sources/`・`Tests/`・`specs/product/`・`specs/009-folder-search/` の差分を確認し、本書の完了チェックとともに最終コミットを作成する（push は行わない）

**Checkpoint**: 自動・GUI・成功基準の記録が揃い、Living spec への反映と feature の凍結が完了する。

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: Setup (T001–T007)          ← T001 の EC-101 は採用済み
  → Phase 2: Foundational (T008–T018)
    → Phase 3: US15 照合と一覧 (T019–T031)  ← MVP（フォルダが結果に出る）
      → Phase 4: US15 開く・履歴 (T032–T038、T061–T063)  ← US15 の Independent Test が成立
        → Phase 5: US15 ファイル操作・名前の変更 (T039–T052、T060)
          → Phase 6: Polish (T053–T059)
```

### User Story Dependencies

- **US15 (P1)**: Phase 2 の `SearchRequest`・`SearchVisitLog`・`DirectoryLister.folderRow` と、検索器・`BrowserModel` の要求の形への接続が前提。1つのストーリーで完結し、他のストーリーへの依存はない。
- US15 の中では、照合（Phase 3）→ 開く・履歴（Phase 4）→ ファイル操作・名前の変更（Phase 5）の順に進める。Phase 4 と Phase 5 はどちらも `BrowserModel.swift` と `BrowserModelSearchTests.swift` を触るため並行しない。Phase 5 の台帳（T043）と `rebaseSearchIndex` の修正（T044）は Phase 3 のフォルダの行が前提（フォルダの行がないと R4 の欠陥と EC-94 が表に出ない）。

### Within Each Phase

- Phase 1: T001 → T002 → T003 → T004 → T005 → T006 → T007。T001 はユーザーの回答で完了済み。
- Phase 2: T008・T009・T010（テスト）→ T011 → T012 → T013 → T014 → T015 → T016 → T017 → T018。T013 は T011・T012 と独立。T014 は T012 の後（プロトコルの変更でコンパイルが通らなくなるため、T012 と T014・T015 は同じ作業単位で続けて行う）。
- Phase 3: T019・T020・T021（同じ `FileNameSearcherTests.swift` のため順に書く）、T022・T023・T024（別ファイル）→ T025 → T026・T027（別ファイル）→ T028 → T029 → T030 → T031。
- Phase 4: T032・T033（別ファイル）→ T034 → T035 → T061 → T062 → T063 → T036 → T037 → T038。T035 と T062 は T034 の新しい case が前提。T032・T061 は同じテストファイル、T034・T062 は同じ Core ファイルなので直列化する。
- Phase 5: T039・T042（別ファイル）、T040 → T041（同じ `BrowserModelSearchTests.swift`。T040 の (8) は `HistoryNavigatorTests.swift` にも足すが、Phase 5 でこのファイルを触るのは T040 だけ）→ T043 → T044 → T045 → T046 → T047 → T048 → T049 → T050 → T051 → T060 → T052。T044・T045・T049 は同じ `BrowserModel.swift` を触るため直列。T049 は T001 の確定と、T040 の (8) の失敗の確認が前提。T060 は T051 の結果が前提で、崩れなかった場合は作業なしでチェックする。
- Polish: T053・T054 → T055 → T059 → T056 → T057 → T058。T059 は T037 の記録が前提で、ユーザーの回答が要る。未実施の GUI 確認や成功基準の記録を自動テストで置き換えて T056 を進めない。

### Parallel Opportunities

既定は順次実装。`[P]` は明示的に並列化する場合の候補を示すだけで、内部 subagent に同じ作業ディレクトリを編集させる指示ではない。

```text
Phase 2 のテスト（別ファイル）:
  T008 SearchVisitLogTests.swift
  T009 FileNameSearcherTests.swift
  T010 DirectoryListerTests.swift

Phase 3 のテスト（別ファイル。T019〜T021 は同じファイルなので1人が順に書く）:
  T019–T021 FileNameSearcherTests.swift
  T022 BrowserModelSearchTests.swift
  T023 FocusNavigatorTests.swift / SlideshowSequenceTests.swift
  T024 PerformanceBaselineTests.swift

Phase 3 の実装（T025 の後、別ファイル）:
  T026 SearchPattern.swift
  T027 FileListViewController.swift

Phase 4 のテスト（別ファイル）:
  T032 → T061 BrowserModelSearchTests.swift（同じファイルなので直列）
  T033 HistoryNavigatorTests.swift

Phase 5 のテスト（別ファイル）:
  T039 SearchRenameLedgerTests.swift
  T040–T041 BrowserModelSearchTests.swift（同じファイルなので順に。T040 の (8) の一部は HistoryNavigatorTests.swift）
  T042 PerformanceBaselineTests.swift

Phase 6:
  T053 README.md
  T054 swift build / swift test / 性能テスト / no-network / bundle
```

並列実装を行う場合は、未コミットの変更を先にコミットまたは stash し、`009-folder-search` をベースに専用の worktree と `agent/<task-id>-<slug>` ブランチを作る。担当者は自分の worktree だけを編集し、小さなコミットの SHA を報告する。インテグレータが `git merge --no-ff` で統合し、統合ごとに `swift build` / `swift test` を実行する。GUI の起動スモークは統合後に1つずつ行う。最後に worktree と作業ブランチを削除する。同じファイルの変更は直列化する。

## Implementation Strategy

### MVP First（US15）

1. Setup では採用済みの EC-101 を前提に、`folder-search/` の検証データと既存回帰を確認する。
2. Foundational で `SearchRequest`・`SearchVisitLog`・`DirectoryLister.folderRow` を自動テスト付きで用意し、検索器と `BrowserModel` を要求の形に接続する（挙動は変えない）。
3. Phase 3 でフォルダを照合して結果に出す。**STOP and VALIDATE**: quickstart の手動シナリオ 1・4 で、フォルダが通常の行として出ることを単独で確かめる（最小の MVP）。
4. Phase 4 でフォルダの行を開き、履歴を FR-113 に合わせる。**STOP and VALIDATE**: 手動シナリオ 2・3 で US15 の Independent Test を確かめる（「探して開く」の MVP）。
5. Phase 5 でファイル操作・外部の変更・検索中の名前の変更を FR-087・FR-105・EC-94 に合わせる。

### Incremental Delivery

1. Setup + Foundational → 要求の型と記録が固まり、既存の検索は無変更のまま回帰が通る。
2. Phase 3 → フォルダが結果に出る。件数・メッセージ・種類フィルタ・プレビュー・フルスクリーン・スライドショーが揃う。
3. Phase 4 → フォルダの行を開け、⌘[ で検索前に戻る。EC-99・EC-100 が成り立つ。
4. Phase 5 → 名前の変更・ゴミ箱・移動・外部の変更・検索中の名前の変更が揃う。
5. Polish → README・成功基準の記録・Living spec への反映・凍結。

## Requirement Coverage

| 対象 | 主なタスク |
|---|---|
| FR-080 / 名前（ファイル名とフォルダ名）による検索 | T025、T053 |
| FR-082 / フォルダ名の全体照合・ワイルドカード | T020、T025、T026 |
| FR-083 / 一致の対象と除外・中を辿る・権限なし・zip | T009、T019〜T021、T025 |
| FR-084 / 混ぜた一覧・「場所」・件数・0件のメッセージ | T022、T027、T030 |
| FR-085 / 途中の件数・開いたときの停止 | T022、T032、T034 |
| FR-087 / フォルダの行のファイル操作・消えたフォルダの中の結果 | T040、T044、T049、T051 |
| FR-105 / 名前の変更の同期・検索中の照合 | T039〜T041、T043〜T045、T051 |
| FR-113 / 検索結果から開いたときの履歴 | T033、T035、T037 |
| FR-139 / フォルダの行の表示・プレビュー・種類フィルタ・フルスクリーン・スライドショー | T010、T013、T020、T022、T023、T025、T030 |
| FR-140 / フォルダの行を開く | T032、T034、T037、T055、T061〜T063、T059（右クリックメニューのメディアの行の食い違い） |
| US15-AS1〜AS10 | T019〜T023、T032、T040、T030・T037・T051 |
| EC-32・EC-33・EC-35・EC-36・EC-52 | T020、T022、T032、T040（EC-36 は (10)）、T041、T051 |
| EC-91〜EC-98 | T020、T022、T032、T040、T041（EC-94 の検索後は T040 の (7)） |
| EC-99・EC-100 | T033、T035、T037 |
| EC-102 / 表示可能な最も近い祖先の選択・保存 | T002、T003、T061〜T063、T037、T055、T056 |
| SC-053 | T002、T003、T021、T055 |
| SC-054 | T024（完了まで 3 秒）、T029、T055（Instruments で 100ms 以上の UI 停止が0件） |
| SC-055〜SC-057 | T023、T032、T033、T040、T055 |
| A-14・A-34・A-76〜A-82 | T025、T027、T049、T053、T056 |
| EC-101 / R8（検索前のフォルダを含むフォルダの行のゴミ箱・移動） | T001、T040、T046、T049、T051、T060（ツリーの選択が崩れた場合）、T056 |
| 検証データ・性能基準 | T002〜T004、T024、T042、T054 |
| Living spec への反映・凍結 | T056、T057、T058 |
