# Tasks: TAK-17 フォルダの新規作成

**Input**: `specs/TAK-17-new-folder/` の設計文書。
**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/new-folder.md / quickstart.md。
**Tests**: Core の自動テスト必須（憲章 原則 IV）。実装は保守者の設計承認後。

## Phase 1: Setup

- [x] T001 `specs/TAK-17-new-folder/spec.md` と checklists/requirements.md を作成し、TAK-17 の判断4点（名前・⇧⌘N・作成先・背景の範囲）を保守者の回答で Clarifications に記録する。
- [x] T002 `specs/TAK-17-new-folder/plan.md`・research.md・data-model.md・contracts/new-folder.md・quickstart.md に設計と検証方法を記録する。
- [x] T003 設計レビュー（analyze の結果を含む）で保守者の承認を得る。未承認なら T004 以降に進まない。

## Phase 2: Foundational（Core。全ストーリーの前提）

- [x] T004 `Tests/FolzioCoreTests/NameValidationTests.swift` に `newFolderName(baseName:existingNames:)` のテストを追加する（空き → 既定名、既定名あり → 「 2」、大文字小文字違い・ファイル名・隠し項目名との一致、「 2」もあれば「 3」、`uniqueName` の既存の挙動が変わらないこと）。
- [x] T005 `Sources/FolzioCore/Operations/NameValidation.swift` に `newFolderName(baseName:existingNames:)` を実装する（research.md R2）。
- [x] T006 `Tests/FolzioCoreTests/FileOperationServiceTests.swift` に `createFolder(in:baseName:)` のテストを追加する（FixtureKit の一時ディレクトリで、成功時の URL と実在・空であること、既定名あり → 連番、作成先なし → destinationNotFound、作成先がファイル、書き込み不可 → systemFailure で何も作られない、既存の項目が変わらないこと）。
- [x] T007 `Sources/FolzioCore/Operations/FileOperationService.swift` の `FileOperating` に `createFolder(in:baseName:)` を追加して実装する（detached task、`withIntermediateDirectories: false`、作成時の同名は次の番号で再試行。research.md R1・R3）。
- [x] T008 `Tests/FolzioCoreTests/FavoriteCommandsTests.swift` と `ListItemCommandsTests.swift` に、`newFolderTarget` と `contextMenu(for:roots:)` の新しい構成（通常のフォルダ・ルート・お気に入り・見出し）、`allowsNewFolder`（通常・zip の中・検索結果）のテストを追加する。既存の構成のテストは新しい構成に合わせて更新する。
- [x] T009 `Sources/FolzioCore/Model/FavoriteCommands.swift` に `TreeContextMenuItem.newFolder`・`newFolderTarget(_:)`・メニューの先頭の項目を、`Sources/FolzioCore/Model/ListItemCommands.swift` に `allowsNewFolder` を実装する（research.md R5、data-model.md）。
- [x] T010 `Tests/FolzioCoreTests/ShortcutCatalogTests.swift` の件数を 45 にして `newFolder` の位置を確かめ、`Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift` に `newFolder`（⇧⌘N、files、duplicate の後）を追加する。
- [x] T011 `Sources/FolzioLocalization/TextKey.swift`・`ShortcutText.swift`・`Resources/{ja,en}.lproj` に「新規フォルダ」「名称未設定フォルダ」とショートカット一覧の説明・条件を両言語で追加する（contracts/new-folder.md の localization.md）。`Tests/FolzioCoreTests/Localization/` の網羅テストが通るようにする。
- [x] T012 `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` に `createFolder(in:) async -> URL?`（失敗の表示・再読み込み・`onFoldersChanged`）と、`rename` の確認を省く引数を追加する（research.md R4、data-model.md「作成後の反映」）。

## Phase 3: User Story 35 — 整理先のフォルダをその場で作る (P1)

**Goal**: ツリー・お気に入り・ファイルリストの背景・「ファイル」メニュー・⇧⌘N から作成し、行内で名前を付けられる。
**Independent Test**: quickstart.md の GUI 手順 1〜9。

- [x] T013 [US35] `Sources/FolzioApp/App/MainMenu.swift` の「ファイル」の先頭に「新規フォルダ」（⇧⌘N、target nil、`MainMenu.bind`）と区切りを追加する（research.md R6）。
- [x] T014 [US35] `Sources/FolzioApp/FileList/ListModeView.swift`・`ThumbnailModeView.swift` に、右クリックの位置に項目があるかの判定と、名前の編集の開始に「作成直後」の印を付けて `onRename` に渡す経路を追加する（research.md R7・R8）。
- [x] T015 [US35] `Sources/FolzioApp/FileList/FileListViewController.swift` に `newFolder(_:)`・`revealDisplayedFolderInFinder(_:)`・作成した URL の選択と名前の編集の開始（ツリーからの依頼用の入口を含む）と `validateMenuItem` の条件（`allowsNewFolder`・読み込めないフォルダ・名前の変更中）を追加する（FR-208・210・212）。
- [x] T016 [US35] `Sources/FolzioApp/FileList/FileContextMenu.swift` で背景の右クリックのときだけ専用メニュー（新規フォルダ / ─ / ペースト / 移動ペースト / ─ / Finder に表示）に作り直し、項目の右クリックでは従来のメニューに戻す（FR-213）。
- [x] T017 [US35] `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` に `newFolder(_:)`・`newFolderFromMenu(_:)`・右クリックメニューの項目・`validateMenuItem` の条件（見つからないお気に入り・名前の変更中）、作成先の展開と新しい行の編集、編集の状態の「作成直後」の印と確定時の確認の省略を追加する（FR-208・210・211、research.md R9）。
- [x] T018 [US35] `Sources/FolzioApp/App/MainSplitViewController.swift` で、ファイルリストの名前の確定の「作成直後」の印を `coordinator.rename` の確認の省略に結び、ツリーのお気に入りの項目からファイルリストへの編集の依頼とフォーカスの移動を結線する（FR-210 の（3））。
- [x] T019 [US35] 変更した Swift ファイルのコメントを英語で書く（AGENTS.md「コードコメント（英語）」）。
- [x] T024 [US35] `docs/usage.md` と `docs/usage.ja.md` の操作の表に新規フォルダ（⇧⌘N・ファイルメニュー・右クリック）の行を両言語で追加する（README の英語版と日本語版の規則に準じる）。
- [x] T025 [US35] 保守者の GUI 確認での指摘（作成直後の名前の編集が一瞬で解除され、既定名のまま残る。FR-210・FR-211 に反する）を直す。`Sources/FolzioApp/FileList/FileListViewController.swift` の `beginNamingNewFolder` で、`ListModeView.hasAppliedRow(for:)`・`ThumbnailModeView.hasAppliedItem(for:)` によりビューが新しい行を反映したことを確かめてから編集を始める。
- [x] T026 [US35] 保守者の GUI 確認での指摘（ツリーでも作成直後の名前の編集が一瞬で解除される）を直す。`Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` の `startProbes` で、サブフォルダの確認の結果が編集中の行に届いたときは行を読み直さず、編集の終了時に反映する（お気に入りの表示の更新と同じ扱い。R51）。

## Phase 4: Polish & Cross-Cutting

- [x] T020 Cloud で `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、`python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` を実行し、結果をこの tasks.md に記録する。
- [x] T021 macOS CI（`.github/workflows/macos-swift-ci.yml`）で `swift build`・`swift test` を確認する。PR は保守者の依頼があるまで作らず、CI 未実行として記録する。
- [x] T022 [MANUAL] 保守者に quickstart.md の GUI 手順 1〜9 と起動スモーク（3ペインの表示）、ローカルの build/test を依頼し、結果を `checklists/validation.md` に記録する。A-121（背景の右クリックで選択が変わらない）が成り立たなければ修正タスクを追加する。報告がなければ未チェックのまま残す。
- [x] T023 検証完了後に最新 master を取り込み、spec.md の「反映先」の表のとおり `specs/product/file-operations.md`・`file-list.md`・`contracts/keyboard-and-menus.md`・`contracts/localization.md` への反映を用意する。FR-208〜214・SC-102〜104・EC-141〜145・A-119〜125・US35 の ID の衝突を確認し、衝突ならこの feature の ID を振り直す。保守者の承認後にコミットし、spec.md に凍結の注記を入れる。

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
- 設計文書を作成し、push（2026-10-31）。保守者の「OK」で設計とお気に入りの扱い（表示していなければ作成だけ）を承認。
- T004〜T019・T024 を実装。Cloud では Swift を実行できないため、ビルドとテストは未確認（T021 の macOS CI で確認する）。
  テストを先に書き（T004・T006・T008・T010）、続けて実装した。
- 実装中の追加の判断: ツリーで作成直後の名前を編集している間に親の読み直し（FSEvents・作成の通知）が届くと、既存の `applyListing` は
  編集を確定してしまう。作成直後の編集に限り、新しいフォルダが残っていれば読み直しを編集の終了まで遅らせる（research.md R9 の補足）。
- T020（Cloud の検査）: check-no-network・check-readme-sync master・check-english-comments・check-skill-sync・test_check_git_push.py（3件）が成功。
- T021: PR [yoshidax/folzio-dev#15](https://github.com/yoshidax/folzio-dev/pull/15) を作成し、Linear を In Review にして PR のリンクを追加。
  macOS CI は workflow_dispatch の run 41232851823 と PR の run 41232985596（どちらも 78a19c8）が成功。ビルド成功、通常のテスト 863 件成功、
  性能テスト 27 件成功（ログ末尾で確認）。
- 並行する TAK-21（ツリーの複数選択）のコミットが FR-208〜212・EC-141 を使っている。T023 の反映時に master と照合し、TAK-21 が先にマージされていれば
  この feature の ID を振り直す。
- 2026-11-01 保守者の GUI 確認: 作成直後に名前の編集が一瞬始まり、「名称未設定フォルダ」のまま解除される。仕様（FR-211 は FR-103 と同じく
  Return・ほかの場所のクリックで確定、Esc で取り消し）どおりではなく、実装の不具合と判断（仕様は変更しない）。
  原因: ビューへの一覧の反映は Observation の後のターンに行われ、URL が変わった一覧の反映は表を作り直して編集を取り消す
  （`ListModeView.applyModel` の `finishRenaming(commit: false)`、サムネイルのセル再利用時の `endRenaming(commit: false)`）。
  実装は反映を待たずに編集を始めていた。T025 で、新しい行の反映を確かめてから編集を始めるように直した。
- 2026-11-01 保守者の GUI 確認: ファイルリスト（T025）は期待どおり。ツリーは改善せず。
  原因: 新しい子の行を作ると、サブフォルダの有無の確認（`SubfolderProbe`）がその行に対して非同期で走る。空のフォルダなので結果がすぐ届き、
  `startProbes` が `reloadItem(node)` で行を読み直す。行を読み直すとセルが作り直されて編集欄が消え、`controlTextDidEndEditing` で
  新しいセルの元の名前のまま確定（変更なし）になっていた。T026 で、編集中の行への結果は `needsReloadAfterEdit` にして、編集の終了時の
  `reloadItem` で反映するようにした。T025 の原因（一覧の反映待ち）とは別の経路。
- 修正後の macOS CI: 2773048（T025）は run 41267321726、9b4c309（T026）は run 41267822219 で、どちらもビルド・通常のテスト・性能テスト 27 件が成功
  （性能テストはログ末尾で確認）。ツリーの修正の GUI 確認は保守者の報告待ち。
- 2026-11-01 保守者の報告「動作確認は完了しました。期待通り動作しました」で T022 を完了とし、checklists/validation.md に記録した。
- T023: origin/master（bc97861）は作業開始時から進んでおらず、取り込む変更はなかった。FR-208〜214・SC-102〜104・EC-141〜145・A-119〜125・US35 は
  master と重複しない（`grep ... | uniq -d` で重複なし）。並行する TAK-21 の PR が同じ番号を使っているため、先にマージされた側に合わせて
  後からマージする側が振り直す。反映の差分を保守者に提示し、承認を待つ。
- 2026-11-01 保守者が反映を承認し、TAK-17 を先にマージすると決定。ID は振り直さない（TAK-21 側が振り直す）。反映を d06362b でコミット・push。
