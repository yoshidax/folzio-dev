# Tasks: ファイルリストの右クリックの対象をツリーに合わせる

**Input**: `specs/TAK-115-file-list-context-target/` の spec.md・plan.md・research.md・quickstart.md

**Tests**: 憲章の原則 IV に従い、右クリックメニューの対象の決め方（`FolzioCore`）と、各 action の対象に自動テストを付ける。

**方針の変更（2026-11-16）**: T001〜T007 は当初の「右クリックで選択を変える」方式の実装（03fca52）である。GUI の確認の前に保守者が
「選択を変えずに、右クリックした項目を対象にする」方式へ改めたため、Phase 3 以降でその実装を置き換える（spec.md の Clarifications、research.md）。

## Phase 0: 設計レビュー

- [x] T000 [MANUAL] 保守者が `specs/TAK-115-file-list-context-target/spec.md`・`plan.md`・`tasks.md` と analyze の結果を確認し、実装開始を承認する（2026-11-16、このチャット）

## Phase 1: Foundational（FolzioCore の判断）

**目的**: リスト形式とサムネイル形式が共有する、右クリック時の新しい選択の決め方を作る

- [x] T001 `Sources/FolzioCore/Model/ContextClickSelection.swift` を新規に作り、右クリックした項目の位置（背景なら nil）と今の選択の位置の集合から、新しい選択（その項目だけ）または「変えない」（nil）を返す純粋な関数を置く（FR-397、research.md R2）
- [x] T002 [P] `Tests/FolzioCoreTests/ContextClickSelectionTests.swift` を新規に作り、選択外の項目（単一選択中・複数選択中・選択なし）、選択中の項目（単一・複数選択の一部）、背景、範囲外の位置の各場合を確かめる

**Checkpoint**: `swift build` と `swift test --filter ContextClickSelectionTests` が通る

## Phase 2: User Story 1 - 右クリックした項目を操作する (Priority: P1) 🎯 MVP

**Goal**: 2つの形式で、選択外の項目の右クリックがメニューを出す前にその項目を選択する

**Independent Test**: quickstart.md の GUI の確認 1〜9

- [x] T003 [US1] `Sources/FolzioApp/FileList/ListModeView.swift` の `FileListTableView` で `menu(for:)` を override し、右クリックした行について `ContextClickSelection` が新しい選択を返したら、`ListModeView` 側の処理で選択を変えてから `super.menu(for:)` を返す。名前の編集中なら先に一覧へ first responder を戻して編集を終える（research.md R1・R3・R4。EC-265）
- [x] T004 [US1] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の `ThumbnailCollectionView.menu(for:)` で、右クリックした項目について `ContextClickSelection` が新しい選択を返したら、`selectionIndexPaths` を設定し、`selectionAnchor` をその項目にして `selectionDidChange(newlySelected:)` を呼ぶ。名前の編集中なら先に編集を終える（research.md R1・R3・R4。EC-265）
- [x] T005 [US1] `Tests/FolzioAppTests/FileListContextClickTests.swift` を新規に作り、リスト形式とサムネイル形式のそれぞれで、選択外の項目の右クリックで `BrowserModel` の選択とフォーカスのある項目がその項目だけになること、選択中の項目の右クリックで複数選択が保たれること、背景の右クリックで選択が変わらないことを確かめる（SC-219・SC-220 の選択の部分）
- [x] T006 [P] [US1] `docs/usage.md` と `docs/usage.ja.md` の「表示形式と列」（View Modes and Columns）に、選択していない項目を右クリックするとその項目が選択され、メニューの操作の対象になることを同じ内容で追記する

**Checkpoint**: `swift build` と `swift test` が通る

## Phase 3: Polish & Verification（当初の方式）

- [x] T007 `swift build`・`swift test`・`scripts/dev/check-all.sh`・`scripts/make-app.sh` を実行し、結果を `specs/TAK-115-file-list-context-target/quickstart.md` に記録する

## Phase 4: 設計の見直しのレビュー

- [x] T011 [MANUAL] 保守者が改めた `spec.md`・`plan.md`・`research.md`・`tasks.md` を確認し、実装の開始を承認する（2026-11-16、このチャット）

## Phase 5: Foundational（FolzioCore の判断の置き換え）

- [x] T012 `Sources/FolzioCore/Model/ContextClickSelection.swift` を `Sources/FolzioCore/Model/ContextMenuTarget.swift` に置き換え、右クリックした項目の位置（背景なら nil）と選択中の位置の集合から、「背景」「選択中の全体」「その項目だけ」を返す（FR-397、research.md R1）
- [x] T013 [P] `Tests/FolzioCoreTests/ContextClickSelectionTests.swift` を `Tests/FolzioCoreTests/ContextMenuTargetTests.swift` に置き換え、選択外の項目（単一選択中・複数選択中・選択なし）、選択中の項目、背景、範囲外の位置を確かめる

## Phase 6: User Story 1 - 右クリックした項目を操作する (Priority: P1)

- [x] T014 [US1] `Sources/FolzioApp/FileList/ListModeView.swift` と `Sources/FolzioApp/FileList/ThumbnailModeView.swift` から、右クリックで選択を変える処理（T003・T004）を取り除き、右クリックした項目の位置を返すプロパティを置く（リスト形式は `clickedRow`、サムネイル形式は `lastMenuLocation`）
- [x] T015 [US1] `Sources/FolzioApp/FileList/FileListViewController.swift` に、URL の一覧・操作の可否・名前を変える項目・中を表示する項目をまとめた `OperationTarget` と、`sender` が右クリックメニュー（とそのサブメニュー）の項目なら記録した対象を、そうでなければ選択を返す処理を置く。「中を表示」「開く」「このアプリケーションで開く」「ゴミ箱に入れる」「名前を変更」「複製」「コピー」「パス名をコピー」「Finder に表示」の action と `validateMenuItem(_:)` をそれに従わせる（FR-397・A-239・EC-264、research.md R2・R3）
- [x] T016 [US1] `Sources/FolzioApp/FileList/FileContextMenu.swift` の `menuNeedsUpdate(_:)` で、名前の編集を確定して終え（EC-265）、`ContextMenuTarget` で対象を決めて `FileListViewController` に記録し、「コピー」の文言と「このアプリケーションで開く」のサブメニューを対象から作る。`menuDidClose(_:)` でサムネイル形式の枠を消す（research.md R2・R5・R6）
- [x] T017 [US1] `Sources/FolzioApp/FileList/ListModeView.swift` に名前を変える項目の URL を受け取る `beginRenaming` を加え、`Sources/FolzioApp/FileList/ThumbnailModeView.swift` に URL を指定して名前の編集を始める入口を置く。`FileListViewController.rename(_:)` から対象の項目で呼ぶ（FR-398、research.md R4）
- [x] T018 [US1] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` で、メニューを表示している間、右クリックした選択外の項目に枠を描く（FR-397、research.md R5）
- [x] T019 [US1] `Tests/FolzioAppTests/FileListContextClickTests.swift` を書き換え、リスト形式とサムネイル形式のそれぞれで、選択外の項目の右クリックで選択が変わらないこと、右クリックメニューの各項目の対象がその項目だけであること、選択中の項目の右クリックでは選択全体が対象であること、メニューバーの項目（右クリックメニュー以外の `sender`）は選択を対象にすること、`..` で操作が淡色になることを確かめる（SC-219・SC-220・A-239・EC-264）
- [x] T020 [P] [US1] `docs/usage.md` と `docs/usage.ja.md` の右クリックの説明（T006 で追記したもの）を、選択を変えずに右クリックした項目を対象にする内容に同じ内容で書き換える

## Phase 7: Polish & Verification

- [x] T021 `swift build`・`swift test`・`scripts/dev/check-all.sh`・`scripts/make-app.sh` を実行し、結果を `specs/TAK-115-file-list-context-target/quickstart.md` に記録する
- [x] T008 [MANUAL] 保守者が古い Folzio を終了して `open .build/Folzio.app` で起動し、3ペインの表示と `specs/TAK-115-file-list-context-target/quickstart.md` の GUI の確認 1〜10 を行う（2026-11-16、保守者の報告「問題なし」。checklists/validation.md）
- [x] T009 `specs/product/file-list.md` へ spec.md の「反映先」の項目を反映し、`python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行する
- [ ] T010 [MANUAL] 保守者が `specs/product/` への反映の差分を確認し、承認する

## Dependencies & Execution Order

- T011 の承認の後に Phase 5 を始める
- T012 の後に T014〜T018。T015 の後に T016・T017（`OperationTarget` を使う）
- T019 は T014〜T018 の後。T020 はいつでも書ける
- T021 はすべての実装の後、T008 は T021 の後、T009 は T008 の後に行う

## Implementation Strategy

1. Phase 5 → Phase 6 で、右クリックメニューの対象の切り替えを作り、`swift test` で確かめる
2. Phase 7 で文書・検証・GUI 確認・製品仕様への反映を行う
3. Phase ごとに AGENTS.md の検証ゲートを通してコミットする
