# Tasks: TAK-17 フォルダの新規作成

**Input**: `specs/TAK-17-new-folder/` の設計文書。
**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/new-folder.md / quickstart.md。
**Tests**: Core の自動テスト必須（憲章 原則 IV）。実装は保守者の設計承認後。

## Phase 1: Setup

- [x] T001 `specs/TAK-17-new-folder/spec.md` と checklists/requirements.md を作成し、TAK-17 の判断4点（名前・⇧⌘N・作成先・背景の範囲）を保守者の回答で Clarifications に記録する。
- [x] T002 `specs/TAK-17-new-folder/plan.md`・research.md・data-model.md・contracts/new-folder.md・quickstart.md に設計と検証方法を記録する。
- [ ] T003 設計レビュー（analyze の結果を含む）で保守者の承認を得る。未承認なら T004 以降に進まない。

## Phase 2: Foundational（Core。全ストーリーの前提）

- [ ] T004 `Tests/FolzioCoreTests/NameValidationTests.swift` に `newFolderName(baseName:existingNames:)` のテストを追加する（空き → 既定名、既定名あり → 「 2」、大文字小文字違い・ファイル名・隠し項目名との一致、「 2」もあれば「 3」、`uniqueName` の既存の挙動が変わらないこと）。
- [ ] T005 `Sources/FolzioCore/Operations/NameValidation.swift` に `newFolderName(baseName:existingNames:)` を実装する（research.md R2）。
- [ ] T006 `Tests/FolzioCoreTests/FileOperationServiceTests.swift` に `createFolder(in:baseName:)` のテストを追加する（FixtureKit の一時ディレクトリで、成功時の URL と実在・空であること、既定名あり → 連番、作成先なし → destinationNotFound、作成先がファイル、書き込み不可 → systemFailure で何も作られない、既存の項目が変わらないこと）。
- [ ] T007 `Sources/FolzioCore/Operations/FileOperationService.swift` の `FileOperating` に `createFolder(in:baseName:)` を追加して実装する（detached task、`withIntermediateDirectories: false`、作成時の同名は次の番号で再試行。research.md R1・R3）。
- [ ] T008 `Tests/FolzioCoreTests/FavoriteCommandsTests.swift` と `ListItemCommandsTests.swift` に、`newFolderTarget` と `contextMenu(for:roots:)` の新しい構成（通常のフォルダ・ルート・お気に入り・見出し）、`allowsNewFolder`（通常・zip の中・検索結果）のテストを追加する。既存の構成のテストは新しい構成に合わせて更新する。
- [ ] T009 `Sources/FolzioCore/Model/FavoriteCommands.swift` に `TreeContextMenuItem.newFolder`・`newFolderTarget(_:)`・メニューの先頭の項目を、`Sources/FolzioCore/Model/ListItemCommands.swift` に `allowsNewFolder` を実装する（research.md R5、data-model.md）。
- [ ] T010 `Tests/FolzioCoreTests/ShortcutCatalogTests.swift` の件数を 45 にして `newFolder` の位置を確かめ、`Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift` に `newFolder`（⇧⌘N、files、duplicate の後）を追加する。
- [ ] T011 `Sources/FolzioLocalization/TextKey.swift`・`ShortcutText.swift`・`Resources/{ja,en}.lproj` に「新規フォルダ」「名称未設定フォルダ」とショートカット一覧の説明・条件を両言語で追加する（contracts/new-folder.md の localization.md）。`Tests/FolzioCoreTests/Localization/` の網羅テストが通るようにする。
- [ ] T012 `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` に `createFolder(in:) async -> URL?`（失敗の表示・再読み込み・`onFoldersChanged`）と、`rename` の確認を省く引数を追加する（research.md R4、data-model.md「作成後の反映」）。

## Phase 3: User Story 35 — 整理先のフォルダをその場で作る (P1)

**Goal**: ツリー・お気に入り・ファイルリストの背景・「ファイル」メニュー・⇧⌘N から作成し、行内で名前を付けられる。
**Independent Test**: quickstart.md の GUI 手順 1〜9。

- [ ] T013 [US35] `Sources/FolzioApp/App/MainMenu.swift` の「ファイル」の先頭に「新規フォルダ」（⇧⌘N、target nil、`MainMenu.bind`）と区切りを追加する（research.md R6）。
- [ ] T014 [US35] `Sources/FolzioApp/FileList/ListModeView.swift`・`ThumbnailModeView.swift` に、右クリックの位置に項目があるかの判定と、名前の編集の開始に「作成直後」の印を付けて `onRename` に渡す経路を追加する（research.md R7・R8）。
- [ ] T015 [US35] `Sources/FolzioApp/FileList/FileListViewController.swift` に `newFolder(_:)`・`revealDisplayedFolderInFinder(_:)`・作成した URL の選択と名前の編集の開始（ツリーからの依頼用の入口を含む）と `validateMenuItem` の条件（`allowsNewFolder`・読み込めないフォルダ・名前の変更中）を追加する（FR-208・210・212）。
- [ ] T016 [US35] `Sources/FolzioApp/FileList/FileContextMenu.swift` で背景の右クリックのときだけ専用メニュー（新規フォルダ / ─ / ペースト / 移動ペースト / ─ / Finder に表示）に作り直し、項目の右クリックでは従来のメニューに戻す（FR-213）。
- [ ] T017 [US35] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` に `newFolder(_:)`・`newFolderFromMenu(_:)`・右クリックメニューの項目・`validateMenuItem` の条件（見つからないお気に入り・名前の変更中）、作成先の展開と新しい行の編集、編集の状態の「作成直後」の印と確定時の確認の省略を追加する（FR-208・210・211、research.md R9）。
- [ ] T018 [US35] `Sources/FolzioApp/App/MainSplitViewController.swift` で、ファイルリストの名前の確定の「作成直後」の印を `coordinator.rename` の確認の省略に結び、ツリーのお気に入りの項目からファイルリストへの編集の依頼とフォーカスの移動を結線する（FR-210 の（3））。
- [ ] T019 [US35] 変更した Swift ファイルのコメントを英語で書く（AGENTS.md「コードコメント（英語）」）。

## Phase 4: Polish & Cross-Cutting

- [ ] T020 Cloud で `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` を実行し、結果をこの tasks.md に記録する。
- [ ] T021 macOS CI（`.github/workflows/macos-swift-ci.yml`）で `swift build`・`swift test` を確認する。PR は保守者の依頼があるまで作らず、CI 未実行として記録する。
- [ ] T022 [MANUAL] 保守者に quickstart.md の GUI 手順 1〜9 と起動スモーク（3ペインの表示）、ローカルの build/test を依頼し、結果を `checklists/validation.md` に記録する。A-121（背景の右クリックで選択が変わらない）が成り立たなければ修正タスクを追加する。報告がなければ未チェックのまま残す。
- [ ] T023 検証完了後に最新 master を取り込み、spec.md の「反映先」の表のとおり `specs/product/file-operations.md`・`file-list.md`・`contracts/keyboard-and-menus.md`・`contracts/localization.md` への反映を用意する。FR-208〜214・SC-102〜104・EC-141〜145・A-119〜125・US35 の ID の衝突を確認し、衝突ならこの feature の ID を振り直す。保守者の承認後にコミットし、spec.md に凍結の注記を入れる。

## Dependencies & Execution Order

T001 → T002 → T003（承認）→ T004〜T012（Core とコーディネータ。T004→T005、T006→T007、T008→T009 の順）→ T013〜T019 → T020 → T021 → T022 → T023。

T014 は T015・T016 の前提。T017 は T012 と T015（ファイルリストへの編集の依頼の入口）に依存する。T018 は T015・T017 の後。

## Parallel Opportunities

Cloud ではタスクを分割して並列実装しない（AGENTS.md）。[P] は付けない。

## Implementation Strategy

承認 → Core のテストと実装 → コーディネータ → メニューとファイルリスト → ツリー → 静的検査 → CI → 保守者の GUI 確認 → product 反映。
最小の確認単位は「ファイルリストの背景と ⇧⌘N からの作成と名前の編集」（T013〜T016・T018 のファイルリスト側）。

## Execution Notes

- 2026-10-31: Linear TAK-17 を In Progress に更新。作業ブランチ `claude/epic-cray-f3r720`（origin/master bc97861 を含む）。
- 設計文書のみ作成。Sources/Tests と specs/product/ は未変更。
