# Tasks: TAK-79 製品仕様の App テストターゲット

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[quickstart.md](quickstart.md)

## Phase 1: 設計

- [x] T001 `specs/TAK-79-app-tests-spec/` に仕様・計画・タスクを作成して整合性を確認する。
- [x] T002 `specs/TAK-79-app-tests-spec/` の設計を保守者に提示し、実装前の承認を得る。

## Phase 2: US1 ターゲット一覧の反映 (P1)

**Independent Test**: 契約と `Package.swift`、日英の開発ガイドを照合する。

- [x] T003 [US1] 最新の master を確認し、`specs/product/contracts/app-bundle.md` のターゲット一覧に `FolzioAppTests` を加える。既存の対象は維持する。
- [x] T004 [US1] `specs/TAK-79-app-tests-spec/quickstart.md` に従って一覧と各種検査を確認し、結果・未実施理由を `specs/TAK-79-app-tests-spec/tasks.md` に記録する。
- [x] T005 [US1] `specs/product/contracts/app-bundle.md` の差分を保守者に示し、コミット前に承認を得る。

検証記録（2026-11-05）: `Package.swift` と日英の開発ガイドにある 3 つのテストターゲットを契約と照合した。Cloud の `scripts/dev/check-all.sh` は成功（71 テスト）。仕様の形式検査はエラー 0 件、警告 88 件（既存の基準値と同数）。製品仕様の文書のみの変更のため、macOS CI と起動確認の省略を保守者が承認した。製品仕様の差分も承認された。

凍結手順: 全タスクの状態を記録後、保守者に注記案を示して承認を得てから `specs/TAK-79-app-tests-spec/spec.md` に移行済み・凍結の注記を付ける。注記は feature ディレクトリの最後の編集とする。
