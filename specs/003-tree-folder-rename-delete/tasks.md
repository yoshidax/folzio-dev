---

description: "Task list for ツリーのフォルダの名前の変更と削除"
---

# Tasks: ツリーのフォルダの名前の変更と削除

**Input**: Design documents from `/specs/003-tree-folder-rename-delete/`

**Prerequisites**: plan.md, spec.md, research.md（R57〜R67）, data-model.md, contracts/, quickstart.md

**Tests**: 憲章 原則 IV（テスト必須）により、`MediaViewerCore` の判断ロジックと異常系には自動テストを付ける
（data-model.md の「テスト」の表）。各テストタスクは対応する実装タスクの前に書き、ビルドエラーまたは失敗になることを確かめてから実装する。
行内編集・メニュー・確認モーダル・ツリーの展開状態・VoiceOver は、quickstart.md の手動確認で検証する（R67）。

**Organization**: spec.md のユーザーストーリーは US1（既存 US1 への追加）だけ（US4-AS7 の変更は US1 のゴミ箱の確認に含まれる）のため、
Phase 3 に Core とアプリの実装をまとめる。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1)
- Include exact file paths in descriptions

## Path Conventions

- Core（AppKit 非依存）: `Sources/MediaViewerCore/`
- UI（AppKit）: `Sources/MediaViewerApp/`
- テスト: `Tests/MediaViewerCoreTests/`・`Tests/MediaViewerPerformanceTests/`
- 共通ルール: Swift 6 strict concurrency。Core から `import AppKit` しない（`UniformTypeIdentifiers` は使ってよい）。ネットワーク API は使わない。
  デコード・ディレクトリ列挙・ファイル操作を UI スレッドで行わない
- 変更しないファイル: `Sources/MediaViewerApp/App/MainMenu.swift`・`FileListViewController.swift`・`ListModeView.swift`・`ThumbnailModeView.swift`（plan.md）
- コードのコメントでは判断の根拠を `R57` のように research.md の番号で参照する
- `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` を触るタスク（T019〜T022）は同じファイルのため並列にしない（AGENTS.md の worktree 規約）

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 変更前の状態が健全であることを確かめる。新しいターゲットや外部依存は追加しない

- [X] T001 ブランチ `003-tree-folder-rename-delete` で、変更前に `swift build` と `swift test` が通ることを確かめる。失敗があれば
  この feature の変更に入る前にユーザーへ報告する（既存の失敗をこの feature で直さない）

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: なし。ユーザーストーリーが US1 の1つだけで、追加する型はすべて US1 のためのものなので Phase 3 に置く

---

## Phase 3: User Story 1 - ツリーのフォルダの名前の変更と削除 (Priority: P1) 🎯 MVP

**Goal**: ツリーの通常のフォルダを、Return・右クリックの「名前を変更」・「編集 > 名前を変更」で行の中で名前を変えられるようにし、
結果をツリー・ファイルリスト・検索結果・お気に入りに食い違いなく反映する。ツリーのゴミ箱は省略設定に関わらず必ず確認する。
フォルダをパッケージになる名前に変えることをツリーとファイルリストの両方で拒否する（FR-103〜106、FR-079・FR-024・FR-076・FR-099・FR-102 の変更、EC-14・EC-53）

**Independent Test**: `swift test` で data-model.md の「テスト」の表のテストが通ること。`.app` で quickstart.md の「3. 手動確認」1〜26 を行い、
ツリーのフォルダの名前を変えると Finder でも変わり、ツリーの展開・選択とファイルリストの表示・プレビューが保たれ、Esc・キャンセルでは何も変わらず、
省略設定がオンでもツリーのゴミ箱で確認モーダルが出ること

### Tests for User Story 1（Core の部品）

> **NOTE: 先に書き、ビルドエラーまたは失敗になることを確かめてから T007〜T010 を実装する**

- [X] T002 [P] [US1] `Tests/MediaViewerCoreTests/PackageNameTests.swift` を新規作成する（`@Suite("PackageName")`、Swift Testing）。T007 の前にビルドエラーになることを確かめる:
  - `isPackage("Photos.app")`・`isPackage("Docs.rtfd")`・`isPackage("X.bundle")` は true
  - `isPackage("2025.01")`・`isPackage("Photos")`・`isPackage("a.txt")`・`isPackage("")` は false
  - `isPackage(".app")`（先頭の `.` だけで拡張子のない名前。`pathExtension` は空）は false
  - `isPackage("Photos.APP")` の結果を実行して確かめ、その値でテストを固定する（UTType の照合に従う。R57）。結果をテスト名に書く
- [X] T003 [P] [US1] `Tests/MediaViewerCoreTests/NameValidationTests.swift` にケースを追加する（T007 の前に失敗することを確かめる）:
  - `validateNewName("Photos.app", for: URL(fileURLWithPath: "/tmp/a/Photos"), existingNames: [], isDirectory: true)` は
    `.invalid(reason: "この名前にするとフォルダがパッケージとして扱われ、表示されなくなります")`（EC-53）
  - 同じ名前でも `isDirectory: false`（ファイル `/tmp/a/Photos.png`）は既存どおり `.needsExtensionChangeConfirmation`（ファイルには適用しない）
  - `isDirectory: true` の `"2025.01"` は `.ok`（拡張子の変更の確認もしない。EC-49）
  - 既存の検査が先に当たること: `".app"` は「名前の先頭に「.」は使用できません」、`"a/b.app"` は「名前に「/」または「:」は使用できません」、
    既存の `"Photos.app"` があるときの `"photos.app"` は「同じ名前の項目がすでに存在します」
- [X] T004 [P] [US1] `Tests/MediaViewerCoreTests/ConfirmationPolicyTests.swift` を新規作成する（`@Suite("ConfirmationPolicy")`）。T008 の前にビルドエラーになることを確かめる。
  data-model.md の表のすべての組み合わせ（`.copy`・`.trash`・`.move`・`.rename(newName:)` × `.fileList`・`.tree`）を `@Test(arguments:)` で確かめる:
  `.copy` はどちらも true、`.trash` は `.fileList` だけ true・`.tree` は false、`.move`・`.rename` はどちらも false（FR-024・FR-079、SC-027）
- [X] T005 [P] [US1] `Tests/MediaViewerCoreTests/RenamedFolderTests.swift` を新規作成する（`@Suite("RenamedFolder")`）。T009 の前にビルドエラーになることを確かめる。
  `from = /tmp/r/Album/2025`・`to = /tmp/r/Album/2025b` とする:
  - 自身: `rebase(/tmp/r/Album/2025)` → `/tmp/r/Album/2025b`。末尾が `/` の `URL(fileURLWithPath: "/tmp/r/Album/2025/", isDirectory: true)` は結果も `hasDirectoryPath == true`
  - 配下: `rebase(/tmp/r/Album/2025/Trip/a.jpg)` → `/tmp/r/Album/2025b/Trip/a.jpg`
  - 兄弟の前方一致: `rebase(/tmp/r/Album/20250/a.jpg)`・`rebase(/tmp/r/Album/2025b/a.jpg)` は nil（`path` の文字列の前方一致で付け替えない。R61）
  - 関係のない URL（`/tmp/r/Album/Other`・`/tmp/r/Album`（親）・`/tmp/x`）は nil。`rebaseOrSelf` は元の URL を返す
  - 表記の違い（`/tmp/r/Album/./2025/a.jpg`・`/tmp/r/Album/x/../2025/a.jpg`）も付け替える（`standardizedFileURL` で比べる）
  - zip の中: `ArchiveURL.entry(archive: /tmp/r/Album/2025/t.zip, path: "dir/a.jpg")` → `ArchiveURL.entry(archive: /tmp/r/Album/2025b/t.zip, path: "dir/a.jpg")`、
    `ArchiveURL.parentLink(of: ArchiveLocation(archive: /tmp/r/Album/2025/t.zip, directory: "dir/"))` → 新しい zip の `parentLink`。
    zip が関係のない場所なら nil
  - `ParentLink.url(for: /tmp/r/Album/2025)`（`mvparent`）と `https://example.com/` は nil
  - `from == to` のとき、自身・配下は同じ URL を返す
- [X] T006 [P] [US1] `Tests/MediaViewerCoreTests/FavoriteCommandsTests.swift` を更新する（T010 の前にビルドエラーになることを確かめる）。
  `roots = [/Users/me, /]`、ルート以外のフォルダ `a = /Users/me/A` とする:
  - 既存の「renameTarget は .favorite のときだけ URL を返す」を置き換える: `renameTarget(.favorite(a), roots:)` は `.favorite(a)`、
    `renameTarget(.folder(a), roots:)` は `.folder(a)`、`renameTarget(.folder(/Users/me), roots:)`・`renameTarget(.folder(/), roots:)`（ルート）・
    `renameTarget(.favoritesHeader, roots:)`・`renameTarget(nil, roots:)` は nil（FR-103、US1-AS35・45）。`roots` が空のとき `.folder` は nil
  - `contextMenu(for: .folder(a), roots:)` が `[.moveToTrash, .separator, .renameFolder, .separator, .pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]`（A-37）
  - `contextMenu(for: .folder(/Users/me), roots:)`（ルート）と `roots` を省いた `contextMenu(for: .folder(a))` は既存どおり
    `[.pasteHere, .movePasteHere, .separator, .addToFavorites, .separator, .revealInFinder]`（`.renameFolder` を含まない）
  - `.favorite` は既存どおり `[.renameFavorite, .removeFromFavorites]`、`.favoritesHeader` は空

### Implementation for User Story 1（Core の部品）

- [X] T007 [P] [US1] `Sources/MediaViewerCore/Operations/PackageName.swift` を新規作成し（`import UniformTypeIdentifiers`、`public enum PackageName`、
  `public static func isPackage(_ name: String) -> Bool`）、`Sources/MediaViewerCore/Operations/NameValidation.swift` の `validateNewName` に、
  既存の4つの検査の後・`guard !isDirectory else { return .ok }` の前で「`isDirectory` かつ `PackageName.isPackage(name)` なら
  `.invalid(reason: "この名前にするとフォルダがパッケージとして扱われ、表示されなくなります")`」を足す（R57、data-model.md）。
  判定は「`(name as NSString).pathExtension` が空なら false。空でなければ `UTType(filenameExtension: ext, conformingTo: .directory)?.conforms(to: .package) == true`」。
  T002・T003 を通す
- [X] T008 [P] [US1] `Sources/MediaViewerCore/Operations/ConfirmationPolicy.swift` を新規作成する（`public enum OperationOrigin: Sendable, Equatable { case fileList, tree }`、
  `public enum ConfirmationPolicy { public static func isSkippable(_ kind: FileOperation.Kind, origin: OperationOrigin) -> Bool }`）。
  data-model.md の表どおり。`switch kind` は `default` を使わず全ケースを書く（種類が増えたときにコンパイルで気づくため）。T004 を通す（R58）
- [X] T009 [P] [US1] `Sources/MediaViewerCore/Model/RenamedFolder.swift` を新規作成する（`public struct RenamedFolder: Sendable, Equatable`、`from`・`to`、
  `rebase(_:)`・`rebaseOrSelf(_:)`）。data-model.md の「規則」どおり。`file` スキームは `standardizedFileURL.pathComponents` で比べ、
  `to` に残りの要素を `appendingPathComponent` で足す（`url.hasDirectoryPath` なら最後の要素で `isDirectory: true`）。`mvzip` は
  `ArchiveURL.parse` で zip の絶対パスと `path`・`isParentLink` を取り出し、zip の URL を付け替えて `ArchiveURL.entry(archive:path:)` または
  `ArchiveURL.parentLink(of: ArchiveLocation(archive:directory:))` で作り直す。T005 を通す（R61）
- [X] T010 [P] [US1] `Sources/MediaViewerCore/Model/FavoriteCommands.swift` を変更する: `public enum TreeRenameTarget: Sendable, Equatable { case favorite(URL), folder(URL) }` を追加し、
  `renameTarget(_ role: TreeItemRole?, roots: [URL]) -> TreeRenameTarget?` に変える（`.folder` は `trashTarget(role, roots:)` が URL を返すときだけ）。
  `TreeContextMenuItem` に `.renameFolder` を追加し、`contextMenu(for:roots:)` のルート以外の `.folder` を
  `[.moveToTrash, .separator, .renameFolder, .separator] + 既存の項目` にする。ドキュメントコメントを更新する（R59）。
  呼び出し側（`DirectoryTreeViewController.swift` の `rename(_:)`・`renameFavoriteFromMenu(_:)`・`validateMenuItem`）は、この時点では
  `roots: rootURLs` を渡し、`case .favorite = ` で判定してお気に入りだけを対象にする最小の変更でビルドを通す（フォルダの対応は T019）。T006 を通す

### Tests for User Story 1（BrowserModel の付け替え）

> **NOTE: T009 の後に書き、ビルドエラーまたは失敗になることを確かめてから T013・T014 を実装する**

- [X] T011 [P] [US1] `Tests/MediaViewerCoreTests/BrowserModelFolderTests.swift` に `didRenameFolder` のケースを追加する（既存の `Env`・`makeEnv` と FixtureKit の
  一時ディレクトリを使い、テストの中で `FileManager.moveItem` で実際に名前を変えてから呼ぶ）:
  - 表示中のフォルダ自身（`root/A` を表示し、ファイル `a.jpg` を選択・フォーカス中）: `didRenameFolder(from: root/A, to: root/A2)` の後、
    `listing.folder == root/A2`、各行の `url` が `root/A2/...`、`selection.focused == root/A2/a.jpg`。`preview` と `stopPlaybackSignal` は呼ぶ前と同じ。
    設定の `viewSettings.lastFolder == root/A2`
  - 祖先（`root/A/B` を表示中に `root/A` → `root/A2`）: `listing.folder == root/A2/B`、`..` の行が `ParentLink.url(for: root/A2/B)`
  - 親の一覧（`root` を表示中に、行 `root/A`（フォルダ）を選択して `root/A` → `root/Z`）: その行の `url == root/Z`・`name == "Z"`、
    並び順の位置へ移り（名前の昇順なら末尾側）、選択は `root/Z` のまま
  - zip の中（`root/A/t.zip` の中を表示中に `root/A` → `root/A2`）: `listing.archive?.archive == root/A2/t.zip`、行の URL が新しい zip の `ArchiveURL`、
    zip の中の別の画像を `select` すると、新しい zip のパスからプレビュー（`.image`）が読める。
    続けて `goToEnclosingLevel()` で zip の最上位 → もう一度で `root/A2` の一覧に戻り、`t.zip` の行が選ばれる（EC-50）
  - 祖先のケースの続きで `goToEnclosingLevel()` を呼ぶと `listing.folder == root/A2` になる（US1-AS40 の ⌘↑）
  - 名前の変更の後に古い場所のイベント `handleFileSystemEvent([root/A, root])` を送っても、`listing.folder` は `root/A2` のまま（親へ移らない。R62）
  - 異常系: 関係のないフォルダ（`root/Other` → `root/Other2`）の `didRenameFolder` では、`listing`・`selection`・`lastFolder` が変わらない
- [X] T012 [P] [US1] `Tests/MediaViewerCoreTests/BrowserModelSearchTests.swift` に `didRenameFolder` のケースを追加する。既存の `FakeSearcher` を、
  `search(in:matching:)` の呼び出しごとの起点を記録し、呼び出しごとに別のストリームへバッチを送れる形に広げる（既存のテストは変えない）:
  - 検索結果の表示中（`phase == .finished`）に結果のファイルを含むフォルダの名前を変える: 結果は残り、`url` と `listing.search!.location(of:)` が新しい名前、
    選択とフォーカスも付け替わり、`preview` は変わらない。`sortOrder.column == .location` なら新しい場所で並べ直されている（FR-105、US1-AS42）
  - 検索起点そのもの（`root/S` → `root/S2`）と祖先の名前を変える: `listing.search?.root` が新しい場所になり、結果は外れない
  - 検索中: `didRenameFolder` の後に、元のストリームから古い場所の結果（`root/S/sub/a.jpg`）が届いたら `root/S2/sub/a.jpg` として加わる。
    追加の列挙が新しい場所（名前を変えたのが起点なら新しい起点 `root/S2`、配下なら `to`）で1回だけ始まる。両方のストリームが同じファイルを返しても1行だけ。
    元と追加の両方のストリームが終わるまで `phase == .searching`、終わったら `.finished`（EC-52、R63）
  - 検索起点の外のフォルダの名前を変えても、追加の列挙を始めない

### Implementation for User Story 1（BrowserModel の付け替え）

- [X] T013 [US1] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に `public func didRenameFolder(from oldURL: URL, to newURL: URL)` を追加する（R62、data-model.md）。
  `RenamedFolder(from:to:)` で `listing.folder`・`listing.archive?.archive`（`ArchiveLocation` を作り直す）・`allFiles` の各行の `url`（行が `oldURL` 自身なら
  `name = newURL.lastPathComponent`）・`selection`（`SelectionState(selected:focused:)` を直接代入し、`select` は呼ばない）・`listing.search?.root`・
  `searchResultsByFolder`（付け替えた URL で作り直す）・`settings.viewSettings.lastFolder`（配下のときだけ書く）を付け替え、
  `allFiles = sorted(allFiles, by: sortOrder)` の後に `rebuildListing()` する。`preview`・`stopPlaybackSignal`・`navigationGeneration`・`treeSyncRequest` は変えない。
  関係する URL が1つもなければ何もしない。T011 と T012 の表示中（検索中以外）のケースを通す
- [X] T014 [US1] `Sources/MediaViewerCore/Browser/BrowserModel.swift` に検索中の付け替えを追加する（R63、data-model.md の「検索中」）: `private var searchRenames: [RenamedFolder]`・
  `activeSearchStreams: Int`・`searchPattern: SearchPattern?` を足し、`startSearch` で設定、`resetForNavigation` で空・0・nil に戻す。
  `appendSearchResults` で届いた行の `url` を `searchRenames` の順に `rebaseOrSelf` で付け替え、`searchResultsByFolder` にすでにある URL を捨ててからマージする。
  `didRenameFolder` は `phase == .searching` のとき記録に足し、`oldURL` が起点の配下（起点そのもの・祖先を含む）なら、`oldURL` が起点か祖先なら付け替えた起点、
  そうでなければ `newURL` を `searcher.search(in:matching: searchPattern)` で追加で列挙する（`navigationGeneration` で古い検索の結果を捨てる既存の規則に従う）。
  `phase = .finished` は `activeSearchStreams` が 0 になったときだけにする。T012 の検索中のケースを通す

### Implementation for User Story 1（App）

- [X] T015 [US1] `Sources/MediaViewerApp/Operations/ConfirmationPresenter.swift` を変更する（R58）: `confirm(_ operation: FileOperation, includesFolders: Bool = false, origin: OperationOrigin = .fileList, location: String? = nil)` にし、
  省略の判断を `ConfirmationPolicy.isSkippable(operation.kind, origin: origin)` に置き換えて、App の `isSkippable` を消す。`location` があれば本文の末尾に
  `"場所: \(location)"` を足す（contracts/keyboard-and-menus.md §5 の本文）。省略できない確認は「今後この確認を表示しない」を出さず、シートの親がなくても
  確認なしでは実行しない（既存の `allowsSuppression == false` の扱い）
- [X] T016 [US1] `Sources/MediaViewerApp/Operations/FileOperationCoordinator.swift` を変更する（R62・R64・R66）:
  - `trash(_ urls: [URL], origin: OperationOrigin = .fileList)`。`.tree` のときは `confirmation.confirm(operation, includesFolders:, origin: .tree, location: urls.first?.path)`
  - `rename(_ file: URL, to newName: String, origin: OperationOrigin = .fileList)`。`.tree` のときは確認モーダルに `location: file.path` を渡す
  - `var onFolderRenamed: ((URL, URL) -> Void)?` を追加する。名前の変更に成功し、対象がフォルダ（既存の `isDirectory`）なら
    「`onFolderRenamed?(file, renamed)` → `model.didRenameFolder(from: file, to: renamed)` → `reloadCurrentFolder()` → `notifyFoldersChanged`」の順にする。
    ファイルなら既存どおり `didRenameItem`。ファイルリストからのフォルダの名前の変更も同じ経路を通る（EC-17 の変更）
- [X] T017 [US1] `Sources/MediaViewerApp/App/MainSplitViewController.swift` で `fileOperationCoordinator.onFolderRenamed` を `treeViewController` の
  `didRenameFolder(from:to:)`（T021 で実装する。この時点では空の `func didRenameFolder(from: URL, to: URL) {}` を `DirectoryTreeViewController.swift` に置いてよい）へ
  `[weak treeViewController]` でつなぐ（`onFoldersChanged` の既存の配線と同じ形）
- [X] T018 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の編集の状態を共有にする（振る舞いは変えない。R60）: `editingFavorite: FavoriteEntry?` を
  `private enum EditingTarget { case favorite(FavoriteEntry), folder(Node) }` と `editingTarget: EditingTarget?` に置き換え、`beginEditingFavorite`・`finishEditingFavorite`・
  `editingFieldHasFocus`・`prepareCell`・`applyFavoriteProbe`・`outlineViewItemWillCollapse`・`control(_:textView:doCommandBy:)`・`controlTextDidEndEditing`・
  `validateMenuItem`・`menuNeedsUpdate`・`applyRoots` の参照を `editingTarget` に合わせる。行を引くのは `.favorite(entry)` なら `entry`、`.folder(node)` なら `node`。
  この時点では `.folder` を作らない。002 の quickstart の 15・22〜24（編集中の無効化・折りたたみ・右クリック・ボリュームの増減）が変わらないことは T026 で確かめる
- [X] T019 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` に通常のフォルダの行内編集を追加する（FR-103、R59・R60、contracts/keyboard-and-menus.md §2・§3）:
  - `rename(_:)` は `FavoriteCommands.renameTarget(role(for: selectedItem), roots: rootURLs)` で分岐し、`.folder` なら選択中の `Node` の編集を始める。
    右クリックの `.renameFolder` を `makeContextMenuItem` に追加し（タイトル「名前を変更」、キー等価 `"\r"`・修飾なし、`renameFolderFromMenu(_:)`）、
    右クリックした行を対象にしてツリーの選択は変えない（A-21・A-36）。メニューの追跡中に始められなければ次のターンに回す（`renameFavoriteFromMenu` と同じ）
  - フォルダの編集を始めるとき: `field.stringValue = node.folder.name`、Formatter は付けない、アクセシビリティラベル「フォルダの名前」、
    選択範囲は `(name as NSString).deletingPathExtension` の長さ（`ListModeView.beginRenaming` と同じ）
  - 確定: 前後の空白（改行を含む）を除き、空・編集前と同じなら何もしない（EC-48）。それ以外は編集の見た目を戻してから
    `Task { await coordinator.rename(node.url, to: name, origin: .tree) }`。Esc は取り消す（確認モーダルも出さない。US1-AS38）
  - `validateMenuItem`: `rename(_:)` は `renameTarget(..., roots: rootURLs) != nil`、`renameFolderFromMenu(_:)` は右クリックした行で同じ判定。
    名前の変更中は両方とも無効（既存の編集中の無効化の一覧に `renameFolderFromMenu(_:)` を足す）
- [X] T020 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` の `moveToTrash(_:)` と `trashFolderFromMenu(_:)` の `coordinator.trash([url])` を
  `coordinator.trash([url], origin: .tree)` にする（FR-079 の変更、R66）。お気に入りの削除（`removeFavorite`）は変えない（FR-064 の省略は従来どおり）
- [X] T021 [US1] `Sources/MediaViewerApp/Tree/DirectoryTreeViewController.swift` に名前の変更の反映を追加する（FR-104・106、R64・R65）:
  - `func didRenameFolder(from oldURL: URL, to newURL: URL)`: `RenamedFolder(from:to:)` で `flattenedNodes(from: roots)` の各ノードの `folder.url` を付け替え
    （ノードが `oldURL` 自身なら `folder.name = newURL.lastPathComponent`）、`folder.children` も付け替える。ノードのオブジェクトは作り直さない。
    名前を変えたノードの行を `reloadItem(_:reloadChildren: false)` で描き直し、`updateWatchSet()` と `refreshFavoriteAvailability()` を呼ぶ
  - `applyListing` の成功時に、同じ場所（`standardizedFileURL`）の既存の `Node` があれば作り直さずに使い回す（`children`・`isLoading`・`folder` の状態を保つ。
    `folder.name` は新しい一覧の名前にする）。これで親の読み直しの後も展開状態と選択が保たれ、兄弟の並び順の位置へ移る
  - `loadChildrenIfNeeded` で読み込みを始めたときの `node.url` を覚え、`await` の後に `node.url` が変わっていたら結果を捨てて `children = nil` のままにする
  - `reloadChildren(of:)` の後、選択中の行が名前を変えたフォルダか配下なら `scrollRowToVisible` で最小限スクロールする
  - 名前の変更中（`editingTarget` が `.folder(node)`）に親の読み直しが来たら、既存の `applyRoots` と同じく先に編集を確定する
  - `refreshFavoriteAvailabilityIfNeeded(in:)` の判定を、変更のあったフォルダが登録したフォルダの親のときだけでなく、祖先（変更のあったフォルダの
    `standardizedFileURL.pathComponents` が、登録したフォルダの `pathComponents` の先頭と一致する）のときにも確かめ直すように広げる
    （アプリの外での祖先の名前の変更・戻し。R65、FR-106）

- [X] T028 [P] [US1] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` のチェックボックスのタイトルを
  「コピー・ゴミ箱に入れる・お気に入りから削除する前に確認する（名前の変更・移動・ツリーのフォルダのゴミ箱は常に確認する）」に変える
  （FR-024 の変更、contracts/settings.md）

### Polish for User Story 1

- [X] T022 [P] [US1] `Tests/MediaViewerPerformanceTests/PerformanceBaselineTests.swift` に「10,000 件の検索結果での didRenameFolder が 0.1 秒以内」を追加する（R67、憲章 II）。
  FixtureKit で 10,000 ファイルを1つのサブフォルダの下に置き、そのサブフォルダを含む起点で検索を終えてから、サブフォルダの名前を `FileManager.moveItem` で変えて
  `didRenameFolder` の所要時間を測る。既存の性能テストと同じ計測と書き方にする

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: 検証ゲートと記録

- [X] T023 `swift build`・`swift test`・`scripts/check-no-network.sh` をこの順で実行し、すべて成功することを確かめる（AGENTS.md の検証ゲート 1〜3）
- [X] T024 `scripts/make-app.sh` で `.app` を作り、起動スモーク（3ペインが表示されること）をユーザーに依頼する。依頼には
  `open .build/MediaViewer.app` と quickstart.md の「2. 準備」を示す（GUI の起動はユーザーに依頼する。AGENTS.md）
- [X] T025 quickstart.md の「3. 手動確認」1〜26 をユーザーに依頼し、結果を `specs/003-tree-folder-rename-delete/checklists/validation.md` に記録する
  （`specs/001-three-pane-media-viewer/checklists/validation.md` の形式に倣う。実行日・OS・確認項目・合否）。R62 のサムネイルの読み直しの程度と、
  T022 の計測値（基準 0.1 秒に対する実測値。憲章 II）も記録する
- [X] T026 002 の quickstart.md の 15・22〜24（お気に入りの名前の編集中の無効化・見出しの折りたたみ・右クリック・ボリュームの増減）をユーザーに依頼し、
  T018 の共有化で変わっていないことを T025 と同じ validation.md に記録する
- [X] T027 Phase 単位でコミットする（tasks.md のチェックと validation.md を含める）

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし
- **Foundational (Phase 2)**: なし
- **User Story 1 (Phase 3)**: T001 の後
- **Polish (Phase 4)**: Phase 3 の後

### Within User Story 1

- T002〜T006（テスト）は互いに独立。T002・T003 → T007、T004 → T008、T005 → T009、T006 → T010
- T007〜T010（Core の部品）は互いに独立（別のファイル）
- T011・T012 は T009 の後（`RenamedFolder` を使う）。T011・T012 → T013 → T014（同じファイル `BrowserModel.swift`）
- T015 は T008 の後。T016 は T013・T015 の後。T017 は T016 の後
- T018 は T010 の後。T018 → T019 → T020 → T021（同じファイル `DirectoryTreeViewController.swift`。並列にしない）。T019・T020 は T016 の後、T021 は T017 の後
- T022 は T014 の後
- T028 はいつでもよい（ほかのタスクと独立。ID は analyze の指摘で後から足したため順番が前後している）

### Parallel Opportunities

- T002・T003・T004・T005・T006 を同時に
- T007・T008・T009・T010 を同時に（別の worktree でもよい。AGENTS.md の worktree 規約）
- T011・T012 を同時に（別のファイル）
- T015 と T018 を同時に（別のファイル）
- T022 は T019〜T021 と同時に（別のファイル）

---

## Parallel Example: User Story 1

```bash
# Core のテストを同時に書く
Task: "T002 PackageNameTests.swift"
Task: "T003 NameValidationTests.swift"
Task: "T004 ConfirmationPolicyTests.swift"
Task: "T005 RenamedFolderTests.swift"
Task: "T006 FavoriteCommandsTests.swift"

# Core の部品を同時に実装する（worktree ごとに1つ）
Task: "T007 PackageName.swift + NameValidation.swift"     # agent/T007-package-name
Task: "T008 ConfirmationPolicy.swift"                     # agent/T008-confirmation-policy
Task: "T009 RenamedFolder.swift"                          # agent/T009-renamed-folder
Task: "T010 FavoriteCommands.swift"                       # agent/T010-rename-target
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1（T001）
2. Core の部品（T002〜T010）→ `swift test` が通ることを確かめる
3. BrowserModel の付け替え（T011〜T014）→ `swift test`
4. App（T015〜T021）→ `swift build`
5. T022〜T027 の検証ゲート。GUI の確認はユーザーに依頼する

### Incremental Delivery

- 途中で止める場合の区切り: T010 まで（Core の判断だけ。ツリーとファイルリストの振る舞いは変わらない。ただし T007 でファイルリストのフォルダの
  パッケージになる名前の拒否は効く）、T014 まで（BrowserModel の付け替えまで。App はまだ使わない）、T021 まで（全機能）
- T018 の共有化は振る舞いを変えないため、ここで一度ビルドして既存のテストが通ることを確かめてから T019 に進む

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- 名前の変更とゴミ箱はファイルシステムを変えるため、GUI の確認では quickstart.md の準備で作ったフォルダだけを使う
- テストの失敗を3回直しても解決しない場合は、作業を止めて状況を報告する（AGENTS.md）
