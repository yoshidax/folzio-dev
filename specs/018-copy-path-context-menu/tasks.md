# Tasks: パス名のコピー

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、[contracts/menus.md](contracts/menus.md)、[quickstart.md](quickstart.md)

**Tests**: Core の判定にテストを付ける（憲章 IV）。AppKit の部分は GUI 確認（[MANUAL]）で確かめる。

## Phase 1: 実装と検証

変更は同じメニュー・ペインの実装を共有するため、以下を順次実施し、この Phase の最後に検証・GUI 確認・コミットを行う。
実装中に更新する文書は、このファイルのチェックと T017 の記録だけにする。

### Foundational: Core の判定と翻訳

- [ ] T001 `Tests/FolzioCoreTests/ListItemCommandsTests.swift` に `allowsCopyPathname(selectionCount:)` のテストを追加する。選択1件のメディア・フォルダ・zip ファイル（zip 外・検索結果表示中を含む）は true。選択0件・2件以上、`..`、zip 内のメディア・ディレクトリ・`..` は false。修正前の失敗を確認する。
- [ ] T002 `Tests/FolzioCoreTests/FavoriteCommandsTests.swift` に `pathnameTarget(_:)` と `contextMenu` のテストを追加する。`.folder`（ホーム・ボリュームのルートを含む）と `.favorite` は URL を返し、`.favoritesHeader` と nil は nil。`contextMenu(for:)` は `.folder` では `.revealInFinder` の直前、`.favorite` では末尾（区切り線の後）に `.copyPathname` を含み、`.favoritesHeader` は空のまま。
- [ ] T003 `Sources/FolzioCore/Model/ListItemCommands.swift` に `allowsCopyPathname(selectionCount:)`（`allowsFileOperations` かつ件数が1）を追加し、`Sources/FolzioCore/Model/FavoriteCommands.swift` に `pathnameTarget(_:)` と `TreeContextMenuItem.copyPathname` を追加して `contextMenu(for:roots:)` に並べる。doc comment は英語（三人称単数・現在形）で書く。T001・T002 を通す。
- [ ] T004 `Sources/FolzioLocalization/TextKey.swift` に `menuEditCopyPathname = "menu.edit.copyPathname"` を追加し、`Resources/ja.lproj/Localizable.strings`（「パス名をコピー」）と `Resources/en.lproj/Localizable.strings`（「Copy as Pathname」）に説明コメント付きで追加する。`MainMenu.refreshTitles` が参照する再翻訳の対象に含める。欠けを検出するローカライズのテストを通す。

### User Story 1: ファイルリストの項目のパスをコピーする（P1）

**Independent Test**: [quickstart.md](quickstart.md) の手順 1〜4・8。

- [ ] T005 [US1] `Sources/FolzioApp/FileList/FileListViewController.swift` に `@objc func copyPathname(_:)` を追加し、選択が1件のとき `NSPasteboard.general` を `clearContents()` して `url.path` を `.string` で書く。`validateMenuItem` に、`selectionItemCommands.allowsCopyPathname(selectionCount:)` が false または名前の変更中なら false を返す分岐を追加する。選択・フォーカス・プレビューは変えない。
- [ ] T006 [US1] `Sources/FolzioApp/FileList/FileContextMenu.swift` に「パス名をコピー」の項目を「コピー」の直後（ペーストの前）に追加し、`menuNeedsUpdate` の再翻訳に含める。ショートカット表示は ⌥⌘C。

### User Story 2: ツリーのフォルダのパスをコピーする（P1）

**Independent Test**: [quickstart.md](quickstart.md) の手順 5・6。

- [ ] T007 [US2] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` の `makeContextMenuItem` に `.copyPathname` を追加し、右クリックした行の URL（`representedObject`）を書き込む `@objc` アクションを追加する。ツリーの選択・ファイルリスト・プレビューは変えない（A-21）。
- [ ] T008 [US2] 同ファイルの `validateMenuItem` に、`FavoriteCommands.pathnameTarget` が nil、見つからないお気に入り（`fileTargetNode(for:)` が nil）、名前の変更中のとき false を返す分岐を追加する。

### User Story 3: キーボードでパスをコピーする（P2）

**Independent Test**: [quickstart.md](quickstart.md) の手順 6・7。

- [ ] T009 [US3] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` に、メニューバーから呼ばれる `@objc func copyPathname(_:)` を追加する。対象は選択中の行（`pathnameTarget(role(for: selectedItem))`）で、「お気に入り」の見出し・選択なし・見つからないお気に入りでは無効にする。
- [ ] T010 [US3] `Sources/FolzioApp/App/MainMenu.swift` の「編集」メニューの「移動ペースト」の後に「パス名をコピー」（⌥⌘C、`menuEditCopyPathname`）を追加する。`target = nil` にして「移動ペースト」と同じくレスポンダチェーンで `FileListViewController.copyPathname(_:)`・`DirectoryTreeViewController.copyPathname(_:)` に届ける（プレビューにフォーカスがあるときは受け手がなく自動で無効になる）。フルスクリーン中・スライドショー実行中・ペインの表示切り替えで対象のペインを隠している間（FR-092）の無効化は、既存の「コピー」「ゴミ箱に入れる」の分岐（`FileListViewController.validateMenuItem`、`DirectoryTreeViewController.validateMenuItem`、`MainSplitViewController.validateMenuItem`）が使う条件を調べ、同じ条件を `copyPathname` にも適用する（調べた結果を実装のコメントではなくコミットメッセージに残す）。

### ユーザーガイド

- [ ] T011 [US3] `docs/usage.md`（英語）と `docs/usage.ja.md`（日本語）の操作一覧の表に「パス名をコピー」の行を同じ構造で追加する（「Show in Finder」「Finder に表示」の行の次。ファイルリストとツリーの右クリックメニュー、「編集 > パス名をコピー」、⌥⌘C、複数選択・zip の中・`..`・「お気に入り」の見出しでは使えない旨）。英語版には日本語の表示名「パス名をコピー」を括弧で添える。`scripts/check-readme-sync.sh master` は README のみを対象にするため、2つのファイルを目視で突き合わせる。

### 検証

- [ ] T012 `swift build` を実行する。
- [ ] T013 `swift test` を実行する。
- [ ] T014 `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh` を実行する。
- [ ] T015 `scripts/make-app.sh` で `.build/Folzio.app` を作成する。
- [ ] T016 [MANUAL] ユーザーが `open .build/Folzio.app` を実行し、[quickstart.md](quickstart.md) の「GUI 確認」の手順 1〜9 を確認して結果を報告する。手順 1・5 で、実行後にファイルリストとツリーの選択・プレビューが変わらないこと（FR-185）も確かめる。
- [ ] T017 GUI 報告を受けて、`checklists/validation.md`（実行日、OS、確認項目、合否）に結果を記録する。各手順が対応する成功基準（SC-086〜089）も併記し、このファイルの進捗を更新する。
- [ ] T018 Phase の変更をコミットする。
