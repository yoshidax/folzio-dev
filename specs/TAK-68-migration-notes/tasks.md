# Tasks: 完了 feature の仕様反映と凍結注記

**Input**: `specs/TAK-68-migration-notes/spec.md`、`plan.md`、`research.md`、`data-model.md`、`quickstart.md`

## Phase 1: 前提の確認

- [x] T001 `specs/product/README.md` の書き方と `.specify/memory/constitution.md` の仕様管理を確認する
- [x] T002 `scripts/dev/check-spec-ids.sh` で `specs/product/` の反映前の重複を確認する
- [x] T003 `specs/TAK-10-unbounded-counters/spec.md` と `Sources/FolzioCore/Operations/NameValidation.swift`、既存テストを照合する

## Phase 2: User Story 1 - 大きな連番の仕様を確認する (P1)

**Independent Test**: FR-018・FR-025 の追加内容が TAK-10 の仕様、実装、既存テストと一致する。

- [x] T004 [US1] 最新 `master` を取り込み、`scripts/dev/check-spec-ids.sh` で反映前に重複を確認する
- [x] T005 [US1] `specs/product/file-operations.md` の FR-018・FR-025 に `specs/TAK-68-migration-notes/spec.md` の不足分を反映し、既存内容を保持する
- [x] T006 [US1] `specs/TAK-10-unbounded-counters/spec.md`、`Sources/FolzioCore/Operations/NameValidation.swift`、`Tests/FolzioCoreTests/NameValidationTests.swift` と `Tests/FolzioCoreTests/FileOperationServiceTests.swift` に照らし、製品仕様の意味と範囲を確認する
- [x] T007 [US1] `scripts/dev/check-spec-ids.sh` と `scripts/dev/check-spec-format.py` で製品仕様の反映後の ID と形式を検証する

## Phase 3: User Story 2 - 完了済み feature を識別する (P1)

**Independent Test**: 対象の移行先を照合し、4件の先頭注記と変更していない本文を確認する。

- [x] T008 [US2] `specs/005-codex-speckit-support/spec.md` に製品仕様の対象外と凍結の注記を付け、現在の Codex 運用文書を示す
- [x] T009 [US2] `specs/TAK-46-fixed-icon-colors/spec.md` の製品仕様への反映を確認し、凍結注記を付ける
- [x] T010 [US2] `specs/TAK-49-video-seek-keys-normal-view/spec.md` の製品仕様への反映を確認し、既存の対応表を保持して凍結注記を付ける
- [x] T011 [US2] TAK-10 の製品仕様への反映を確認後、`specs/TAK-10-unbounded-counters/spec.md` の先頭に凍結注記を付ける
- [x] T012 [US2] `specs/` の完了済み feature の先頭注記と反映状況を確認し、対象4件以外の未注記があれば状態を調べて報告する
- [x] T013 [US2] `specs/TAK-49-video-seek-keys-normal-view/spec.md` を含む対象の差分が先頭注記のみであることを確認する

## Phase 4: 検証・レビュー・凍結

- [x] T014 `scripts/dev/check-all.sh` と `specs/TAK-68-migration-notes/quickstart.md` の照合を実行する
- [x] T015 `specs/product/file-operations.md` と feature 注記の完成差分を保守者に示し、コミット前の承認を得る（`docs_private/cloud-agent-workflow.md` 7章）
- [ ] T016 [MANUAL] 必要な `swift build`・`swift test`・macOS CI について `docs_private/cloud-agent-workflow.md` の手順に従い、実施結果または保守者のスキップ指示を記録する
- [ ] T017 [MANUAL] 保守者が `scripts/make-app.sh` と `open .build/Folzio.app` で起動・3ペインを確認するか、スキップを明示する
- [ ] T018 `specs/TAK-68-migration-notes/tasks.md` に検証と保守者の判断を記録し、凍結手順を除く未完了事項を解消する
- [ ] T019 `specs/TAK-68-migration-notes/spec.md` の凍結注記案を含む最終差分を保守者に示して承認を得る

## 依存関係と実装戦略

- T001〜T003 → US1 の T004〜T007 → T011〜T015。既存の注記 T008〜T010 は事前に実施済み。
- 設計の承認後に製品仕様へ反映する。T015 の承認後に差分を変更した場合は再承認を得る。
- T016〜T018 の完了または保守者のスキップ指示を記録してから T019 で注記案を含む最終差分の承認を得る。
- T019 の承認を `tasks.md` の最後の更新として記録し、`specs/TAK-68-migration-notes/spec.md` の先頭に承認済みの移行済み・凍結注記を付ける。以後は同 feature ディレクトリを編集しない。注記の存在は PR で確認する。
- Cloud では Issue 内をサブエージェントに分割しない。アプリコードの変更は予定しない。
