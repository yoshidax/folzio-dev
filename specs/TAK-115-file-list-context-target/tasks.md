# Tasks: ファイルリストの右クリックの対象を Finder に合わせる

**Input**: `specs/TAK-115-file-list-context-target/` の spec.md・plan.md・research.md・quickstart.md

**Tests**: 憲章の原則 IV に従い、新しい選択の決め方（`FolzioCore`）と、2つの一覧のビューの結線に自動テストを付ける。

## Phase 0: 設計レビュー

- [x] T000 [MANUAL] 保守者が `specs/TAK-115-file-list-context-target/spec.md`・`plan.md`・`tasks.md` と analyze の結果を確認し、実装開始を承認する（2026-11-16、このチャット）

## Phase 1: Foundational（FolzioCore の判断）

**目的**: リスト形式とサムネイル形式が共有する、右クリック時の新しい選択の決め方を作る

- [ ] T001 `Sources/FolzioCore/Model/ContextClickSelection.swift` を新規に作り、右クリックした項目の位置（背景なら nil）と今の選択の位置の集合から、新しい選択（その項目だけ）または「変えない」（nil）を返す純粋な関数を置く（FR-397、research.md R2）
- [ ] T002 [P] `Tests/FolzioCoreTests/ContextClickSelectionTests.swift` を新規に作り、選択外の項目（単一選択中・複数選択中・選択なし）、選択中の項目（単一・複数選択の一部）、背景、範囲外の位置の各場合を確かめる

**Checkpoint**: `swift build` と `swift test --filter ContextClickSelectionTests` が通る

## Phase 2: User Story 1 - 右クリックした項目を操作する (Priority: P1) 🎯 MVP

**Goal**: 2つの形式で、選択外の項目の右クリックがメニューを出す前にその項目を選択する

**Independent Test**: quickstart.md の GUI の確認 1〜9

- [ ] T003 [US1] `Sources/FolzioApp/FileList/ListModeView.swift` の `FileListTableView` で `menu(for:)` を override し、右クリックした行について `ContextClickSelection` が新しい選択を返したら、`ListModeView` 側の処理で選択を変えてから `super.menu(for:)` を返す。名前の編集中なら先に一覧へ first responder を戻して編集を終える（research.md R1・R3・R4。EC-265）
- [ ] T004 [US1] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の `ThumbnailCollectionView.menu(for:)` で、右クリックした項目について `ContextClickSelection` が新しい選択を返したら、`selectionIndexPaths` を設定し、`selectionAnchor` をその項目にして `selectionDidChange(newlySelected:)` を呼ぶ。名前の編集中なら先に編集を終える（research.md R1・R3・R4。EC-265）
- [ ] T005 [US1] `Tests/FolzioAppTests/FileListContextClickTests.swift` を新規に作り、リスト形式とサムネイル形式のそれぞれで、選択外の項目の右クリックで `BrowserModel` の選択とフォーカスのある項目がその項目だけになること、選択中の項目の右クリックで複数選択が保たれること、背景の右クリックで選択が変わらないことを確かめる（SC-219・SC-220 の選択の部分）
- [ ] T006 [P] [US1] `docs/usage.md` と `docs/usage.ja.md` の「表示形式と列」（View Modes and Columns）に、選択していない項目を右クリックするとその項目が選択され、メニューの操作の対象になることを同じ内容で追記する

**Checkpoint**: `swift build` と `swift test` が通る

## Phase 3: Polish & Verification

- [ ] T007 `swift build`・`swift test`・`scripts/dev/check-all.sh`・`scripts/make-app.sh` を実行し、結果を `specs/TAK-115-file-list-context-target/quickstart.md` に記録する
- [ ] T008 [MANUAL] 保守者が古い Folzio を終了して `open .build/Folzio.app` で起動し、3ペインの表示と `specs/TAK-115-file-list-context-target/quickstart.md` の GUI の確認 1〜9 を行う
- [ ] T009 `specs/product/file-list.md` へ spec.md の「反映先」の項目を反映し、`python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行する
- [ ] T010 [MANUAL] 保守者が `specs/product/` への反映の差分を確認し、承認する

## Dependencies & Execution Order

- Phase 0 の承認の後に Phase 1 を始める
- T001 の後に T003・T004（同じ判断を使う）。T003 と T004 は別のファイルのため並行できる
- T005 は T003・T004 の後。T006 はいつでも書ける
- T007 はすべての実装の後、T008 は T007 の後、T009 は T008 の後に行う

## Implementation Strategy

1. Phase 1 → US1 で MVP（2つの形式の右クリックの選択）を作り、`swift test` で確かめる
2. Phase 3 で文書・検証・GUI 確認・製品仕様への反映を行う
3. Phase ごとに AGENTS.md の検証ゲートを通してコミットする
