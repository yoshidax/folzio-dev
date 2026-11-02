# Tasks: リスト形式の列の表示・非表示

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[research.md](research.md)、[data-model.md](data-model.md)、[quickstart.md](quickstart.md)
**Issue**: [TAK-47](https://linear.app/takyoshida/issue/TAK-47/)
**Tests**: Core のロジックと異常系にテストを付ける（憲章 IV）。Cloud では `swift build` / `swift test` を実行できないため CI で確認する。

形式: `- [ ] T### [P?] [US?] 説明（ファイル）`。`[P]` は別ファイルで並行可。US の番号は spec.md の User Story 1〜3 に対応する。

## Phase 1: Foundational（全 Story の前提）

- [ ] T001 `ListColumn`（name / creationDate / kind / size / modificationDate、この順が表示順）と `ListColumnVisibility`（`name` は常に含む。既定は name・creationDate・kind）を `Sources/FolzioCore/Model/ListColumn.swift` に追加する
- [ ] T002 [P] `MediaFile` に `modificationDate: Date?`（既定 nil）を追加する（`Sources/FolzioCore/Model/MediaFile.swift`）
- [ ] T003 `DirectoryLister` の読み取りキー（fileKeys / mediaKeys / folderKeys）に `contentModificationDateKey` を足し、ファイル行・フォルダ行の `modificationDate` に渡す（`Sources/FolzioCore/FileSystem/DirectoryLister.swift`）
- [ ] T004 [P] `ArchiveIndex` の項目とフォルダ行に、entry の更新日時を `modificationDate` として渡す（`Sources/FolzioCore/Archive/ArchiveIndex.swift`。既存の `creationDate` は変えない）
- [ ] T005 [P] 列名・メニュー文言の `TextKey`（サイズ、変更日）を日英で追加する。列名は並べ替えメニューと共用する（`Sources/FolzioLocalization/TextKey.swift`）

## Phase 2: User Story 1 — 列見出しの右クリックで列を選ぶ（P1）

**Goal**: 見出しの右クリックでポップアップが開き、チェックで列を即座に表示・非表示できる。
**Independent Test**: quickstart の手動確認 1〜3・7。

- [ ] T006 [P] [US1] `ListColumnVisibility` のテスト: 既定、`name` が外せない、切り替え（`Tests/FolzioCoreTests/ListColumnVisibilityTests.swift`）
- [ ] T007 [US1] `ViewSettings` に `visibleColumns` を追加する（既定は T001 の既定。`Sources/FolzioCore/Model/Settings.swift`）
- [ ] T008 [US1] `ListModeView` にサイズ・変更日の列（`size`、`modificationDate`）を追加し、`visibleColumns` と検索中の場所列（FR-084）で `isHidden` を決める（`Sources/FolzioApp/FileList/ListModeView.swift`）
- [ ] T009 [US1] セルの表示を追加する: サイズは `ByteCountFormatter`（.file）、フォルダ・`..` と取得不能は `--`、変更日は `l10n.dateTime`（nil は `--`）。表示言語の切り替え時の再描画（`displayLanguageDidChange`、`refreshVisibleLocalizedCells`）にも加える（同ファイル）
- [ ] T010 [US1] `tableView.headerView?.menu` に、5 項目（チェック付き、ファイル名は無効）の `NSMenu` を設定し、`menuNeedsUpdate` でチェックを更新する。選択で `visibleColumns` を更新して即座に反映し、行の右クリックのメニュー（`tableView.menu`）は変えない（同ファイル。`FileListTableView` の `menu(for:)` の影響を確認する）
- [ ] T011 [P] [US1] サイズ文字列の整形（フォルダ・0 バイトのファイル）を Core の関数にしてテストする場合は `Tests/FolzioCoreTests/` に置く。整形が AppKit なしで書ける範囲を Core に置く

## Phase 3: User Story 2 — サイズと変更日で並べ替える（P2）

**Goal**: サイズ・変更日の見出しのクリックと「表示 > 並べ替え」で並べ替えられる。
**Independent Test**: quickstart の手動確認 3〜5。

- [ ] T012 [P] [US2] 並べ替えのテスト: サイズ・変更日の昇順・降順、値なし（フォルダ・`..`・nil）は昇順・降順とも末尾、同値は名前の自然順、`sortedMerge` と整合（`Tests/FolzioCoreTests/SortingTests.swift` に追記）
- [ ] T013 [US2] `SortColumn` に `size` / `modificationDate` を追加し、`Sorting.swift` の `precedes` / `comparePrimary` で値なしを末尾に置く規則を日付とサイズに一般化する（`Sources/FolzioCore/Model/Settings.swift`、`Sources/FolzioCore/Model/Sorting.swift`）
- [ ] T014 [US2] `ListModeView` の `sortEntries` とソート記述子の対応にサイズ・変更日を加え、「表示 > 並べ替え」メニューにも出す。列が非表示でも並べ替えは維持する（`Sources/FolzioApp/FileList/ListModeView.swift`）
- [ ] T015 [P] [US2] `DirectoryLister` が変更日を返すテストと、zip の項目の更新日時のテストを追加する（`Tests/FolzioCoreTests/DirectoryListerTests.swift`、`Tests/FolzioCoreTests/ArchiveIndexTests.swift`。既存のファイル名に合わせる）

## Phase 4: User Story 3 — 列の表示状態を保存する（P2）

**Goal**: 再起動後も列の状態が復元される。
**Independent Test**: quickstart の手動確認 6。

- [ ] T016 [US3] `SettingsStore.viewSettings` に `visibleColumns` の保存・復元（キー `view.list.visibleColumns`、rawValue の配列）を実装する。未知の値は捨て、`name` を補い、型が違う・欠落は既定にする（`Sources/FolzioCore/Settings/SettingsStore.swift`）
- [ ] T017 [P] [US3] `SettingsStore` のテスト: 保存と復元、未知の列を無視、壊れた値は既定、`name` の補完、新しい `view.sort.column`（size など）の読み込み（`Tests/FolzioCoreTests/SettingsStoreTests.swift`）
- [ ] T018 [US3] 列の切り替えで `visibleColumns` を保存する経路を、既存の表示設定の保存（`BrowserModel` 経由）に接続する。保存経路は実装時に確認する（`Sources/FolzioCore/Browser/BrowserModel.swift`、`ListModeView.swift`）

## Phase 5: 仕上げと反映

- [ ] T019 `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh` を実行する。新規コメントは英語で書く
- [ ] T020 README に列の説明があれば `README.md` と `README.ja.md` の両方へ同じ変更を入れる。なければ変更しない
- [ ] T021 保守者の依頼で PR を作り、CI（`swift build`・`swift test`）の結果を確認する。起動スモークと quickstart の手動確認は保守者に依頼する
- [ ] T022 実装と検証が終わったら、`git merge origin/master` の後、spec.md の「反映先」の表に従って `specs/product/file-list.md`（と overview.md の FR-003）へ反映する。ID の重複を確認し（`specs/product/README.md`、`docs_private/cloud-agent-workflow.md` 7 章）、差分を保守者に示して承認を得てからコミットする

## Dependencies

- Phase 1 → 全 Story。T003・T004 は T002 の後
- US1（T006〜T011）→ US2 の T014（列の追加が前提）。US2 の Core（T012・T013）は US1 と並行できる
- US3 の T016 は T007 の後。T018 は T010 の後
- 並行できるもの: T002/T004/T005、T006/T011、T012/T015、T017

## Implementation Strategy

1. MVP は Phase 1 + US1（列の選択と表示）。次に US2（並べ替え）、US3（保存）
2. 作業の区切りでコミットし、作業ブランチ（`claude/jolly-ptolemy-1b91ys`）へ push する
3. 設計レビューで保守者の承認を得るまで、実装（Phase 2 以降）に着手しない
