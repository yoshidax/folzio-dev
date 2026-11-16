# Tasks: 操作ごとの実行前の確認の設定

**Input**: `specs/TAK-105-confirm-move-rename/` の spec.md・plan.md・research.md・data-model.md・contracts/・quickstart.md

**Tests**: 憲章の原則 IV に従い、判断ロジック（操作と設定の対応、移行）と確認モーダルの省略の動作に自動テストを付ける。

## Phase 0: 設計レビュー

- [x] T000 [MANUAL] 保守者が `specs/TAK-105-confirm-move-rename/spec.md`・`plan.md`・`tasks.md` と analyze の結果を確認し、実装開始を承認する（2026-11-16、このチャット）

## Phase 1: Foundational（FolzioCore の判断と保存）

**目的**: すべてのユーザーストーリーが使う、操作と設定の対応・5つの設定の保存・移行を作る

- [ ] T001 `Sources/FolzioCore/Model/Settings.swift` に `ConfirmationTarget`（`copy`・`move`・`rename`・`removeFavorite`・`trash`、設定ウインドウの並び）を追加し、`ConfirmationOptions` を5つの Bool と `isEnabled(_:)`・`setEnabled(_:for:)` に変える（`confirmBeforeFileOperations` は削除）
- [ ] T002 `Sources/FolzioCore/Operations/ConfirmationPolicy.swift` の `isSkippable` を `target(for:origin:) -> ConfirmationTarget?` と `requiresModalWithoutWindow(_:origin:)` に置き換える（data-model.md の表。ツリーのゴミ箱だけ `nil`）
- [ ] T003 `Sources/FolzioCore/Settings/SettingsStore.swift` で5つの新しいキーを読み書きし、未設定のキーは旧キー `fileOps.confirmBeforeExecuting` から引き継ぐ（移動・名前の変更は true）。旧キーは書かない。setter で `Notification.Name.confirmationOptionsDidChange` を送る（research.md R2・R4）
- [ ] T004 [P] `Tests/FolzioCoreTests/ConfirmationPolicyTests.swift` を、操作4種 × ペイン2種の `target` と、親ウインドウなしの `runModal` の要否の表に書き換える
- [ ] T005 [P] `Tests/FolzioCoreTests/SettingsStoreTests.swift` に、既定値、5つの独立した保存、旧キーがオン・オフ・不正な型・未設定のときの引き継ぎ、新しいキーが保存済みなら旧キーを読まないこと、旧キーを書き換えないこと、変更の通知のテストを追加し、既存の `confirmBeforeFileOperations` のテストを置き換える

**Checkpoint**: `swift build` と `swift test --filter FolzioCoreTests` が通る

## Phase 2: User Story 1 - 操作ごとに確認の要否を選ぶ (Priority: P1) 🎯 MVP

**Goal**: 設定ウインドウの5つのチェックボックスで、各操作の確認を別々に切り替えられる

**Independent Test**: quickstart.md の GUI の確認 1〜4

- [ ] T006 [US1] `Sources/FolzioApp/Operations/ConfirmationPresenter.swift` の `confirm` と `confirmRemovingFavorite` を、`ConfirmationPolicy.target` と `ConfirmationOptions.isEnabled` で省略を判断するように変える。親ウインドウがないときは `requiresModalWithoutWindow` に従う（EC-263）
- [ ] T007 [US1] `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` と `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` のコメント・呼び出しから「移動・名前の変更は常に確認」の前提を取り除く（ツリーの名前の変更は `rename` の設定に従う。新規フォルダの名前付け `confirms: false` は変えない）
- [ ] T008 [P] [US1] `Sources/FolzioLocalization/TextKey.swift` と `Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings`・`Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings` で `settings.confirm` を `settings.confirm.copy`・`.move`・`.rename`・`.removeFavorite`・`.trash` に置き換え、`settings.confirm.note` の文言を変える（contracts/localization.md）
- [ ] T009 [P] [US1] `Tests/FolzioCoreTests/Localization/SettingsTextTests.swift` を5つの文言と新しい補足説明の日英に書き換える
- [ ] T010 [US1] `Sources/FolzioApp/Settings/SettingsWindowController.swift` で、確認のチェックボックスを5つにし（FR-223 の並び）、補足説明を「ゴミ箱に入れる前に確認する」の直下に、その文言の先頭に揃えて置き、そのチェックボックスのアクセシビリティのヘルプにする。間隔（FR-222）、Tab の移動順（US40-AS4）、ラベルの言語切り替え、`syncFromStore`、各チェックボックスの保存を対応させる
- [ ] T011 [US1] `Tests/FolzioAppTests/ConfirmationPresenterTests.swift` を新規に作り、`presentSheet` と `fallbackWindow` を差し替えて、5つの設定のうち1つだけをオフにした5通り × 5操作（SC-216）と、ツリーのゴミ箱が設定に関わらず確認されることを確かめる

**Checkpoint**: `swift build` と `swift test` が通る

## Phase 3: User Story 2 - 確認モーダルから、その操作の確認だけを止める (Priority: P2)

**Goal**: 「今後この確認を表示しない」が、そのモーダルの操作の確認だけをオフにし、表示中の設定ウインドウに反映される

**Independent Test**: quickstart.md の GUI の確認 5

- [ ] T012 [US2] `Sources/FolzioApp/Operations/ConfirmationPresenter.swift` で、`target` が `nil` でないモーダルに「今後この確認を表示しない」を出し、オンで閉じたら（キャンセルでも）その `target` だけを `setEnabled(false, for:)` で保存する（FR-395・EC-262）
- [ ] T013 [US2] `Sources/FolzioApp/Settings/SettingsWindowController.swift` で `confirmationOptionsDidChange` を受けて5つのチェックボックスの状態を読み直す（EC-261）
- [ ] T014 [US2] `Tests/FolzioAppTests/ConfirmationPresenterTests.swift` に、移動・名前の変更のモーダルに抑止のチェックボックスが出ること、オンで閉じるとその操作だけがオフになること（SC-218）、ツリーのゴミ箱には出ないこと、親ウインドウなしの移動・名前の変更が確認を経ることのテストを追加する

## Phase 4: User Story 3 - 更新しても確認が黙って消えない (Priority: P2)

**Goal**: 以前の版の設定を引き継ぎ、移動・名前の変更はオンで始まる

**Independent Test**: quickstart.md の GUI の確認 6

- [ ] T015 [US3] T003・T005 の引き継ぎが US85-AS8・AS9 を満たすことを `Tests/FolzioCoreTests/SettingsStoreTests.swift` のテスト名と期待値で確かめ、不足があれば補う（SC-217）

## Phase 5: Polish & Verification

- [ ] T016 [P] `docs/usage.md` と `docs/usage.ja.md` の「ファイル操作」の確認の説明を、操作ごとに省略できることと、ツリーのフォルダのゴミ箱は常に確認することに同じ内容で書き換える
- [ ] T017 `swift build`・`swift test`・`scripts/dev/check-all.sh`・`scripts/make-app.sh` を実行し、結果を `specs/TAK-105-confirm-move-rename/quickstart.md` に記録する
- [ ] T018 [MANUAL] 保守者が古い Folzio を終了して `open .build/Folzio.app` で起動し、3ペインの表示と `specs/TAK-105-confirm-move-rename/quickstart.md` の GUI の確認 1〜6 を行う
- [ ] T019 `specs/product/` の file-operations.md・directory-tree.md・window-layout.md・contracts/settings.md・contracts/localization.md へ spec.md の「反映先」の項目を反映し、`python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行する
- [ ] T020 [MANUAL] 保守者が `specs/product/` への反映の差分を確認し、承認する

## Dependencies & Execution Order

- Phase 0 の承認の後に Phase 1 を始める
- Phase 1（T001〜T005）は全ストーリーの前提。T004・T005 は T001〜T003 と並行に書ける
- US1（T006〜T011）の後に US2（T012〜T014）。T012 と T006 は同じファイルのため順に行う
- US3（T015）は T003・T005 だけに依存し、US1・US2 と並行できる
- T017 はすべての実装の後、T018 は T017 の後、T019 は T018 の後に行う

## Implementation Strategy

1. Phase 1 → US1 で MVP（操作ごとの設定と省略）を作り、`swift test` で確かめる
2. US2・US3 を加え、Phase 5 で文書・検証・GUI 確認・製品仕様への反映を行う
3. Phase ごとに AGENTS.md の検証ゲートを通してコミットする
