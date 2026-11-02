# Tasks: フォルダと zip の行頭アイコンの固定色

**Input**: [spec.md](spec.md)・[plan.md](plan.md)・[research.md](research.md)・[data-model.md](data-model.md)・[quickstart.md](quickstart.md)

形式: `- [ ] Txxx [P?] [USn] 説明（ファイル）`。Cloud では Swift を実行できないため、ビルドとテストは CI で確認する。

## Phase 1: 基盤（Core の判断ロジック）

- [ ] T001 `Sources/FolzioCore/Model/MediaKind.swift` に `ListItemIconTone`（`folderBlue` / `archiveYellow` / `secondary`、`Sendable`）と `ListItemKind.iconTone` を追加する。`.folder`・`.directory` → `folderBlue`、`.archive` → `archiveYellow`、`.parent`・`.media` → `secondary`（data-model.md）。AppKit を import しない。コメントは英語
- [ ] T002 [P] `Tests/FolzioCoreTests/ListItemIconToneTests.swift` に、全 `ListItemKind`（メディアは全 `MediaKind`）の `iconTone` を検証する Swift Testing を追加する（FR-255〜257）

## Phase 2: User Story 1・2 — フォルダは青、zip は黄（P1）

**Independent Test**: フォルダと zip を含む一覧で、フォルダが青、zip が黄で表示される（ライト／ダーク）

- [ ] T003 [US1] `Sources/FolzioApp/Shared/IconCatalog.swift` に固定色 2 つ（青 sRGB(0.00, 0.48, 1.00)、黄 sRGB(0.96, 0.72, 0.00)）と `tintColor(for: ListItemKind) -> NSColor`（`secondary` は `.secondaryLabelColor`）を追加する（FR-255・256、research.md R1・R2）
- [ ] T004 [P] [US2] `Tests/FolzioAppTests/IconCatalogTintTests.swift` に、`tintColor(for:)` の種別ごとの値、青と黄の HSB 明度差が 0.1 以内であること、外観（ライト／ダーク）によらず同じ値であることを検証するテストを追加する（FR-256）
- [ ] T005 [US1] `Sources/FolzioApp/FileList/ListModeView.swift` の非メディア行（`nameCell`）の `.secondaryLabelColor` を `IconCatalog.tintColor(for: file.kind)` に置き換える。メディア行の `nil` は変えない（FR-255・256・257）
- [ ] T006 [US1] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の `showListItemIcon` の `.secondaryLabelColor` を `IconCatalog.tintColor(for: kind)` に置き換える。メディア行・再利用時の `nil` は変えない（FR-255・256・257）

## Phase 3: User Story 3 — 対象外が変わらない（P2）

- [ ] T007 [US3] 変更後に、`..` 行・メディアの汎用アイコン・ツリー（`DirectoryTreeViewController`）の描画コードが変わっていないことを差分で確かめる（FR-257・258）

## Phase 4: 仕上げ

- [ ] T008 `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh` を実行して通す
- [ ] T009 コミットして作業ブランチに push する。PR は保守者の依頼があるまで作らない
- [ ] T010 CI の結果（`swift build`・`swift test`）と、保守者の GUI 確認（quickstart.md）を記録する。**GUI 確認は保守者に依頼し、未実施のまま完了にしない**
- [ ] T011 実装と検証の完了後、変更点を `specs/product/file-list.md` へ反映する（最新の master を取り込み、ID の衝突を確認する。反映内容を示し、承認を得てからコミットする）

## 依存関係

T001 → T002・T003 → T004・T005・T006 → T007 → T008 → T009 → T010 → T011。MVP は T001〜T006。
