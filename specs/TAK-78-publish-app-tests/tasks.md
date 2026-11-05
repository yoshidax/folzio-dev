# Tasks: TAK-78 公開書き出しでの App テスト

**Input**: [spec.md](spec.md)、[plan.md](plan.md)、[quickstart.md](quickstart.md)

## Phase 1: 設計

- [x] T001 `specs/TAK-78-publish-app-tests/` に仕様・計画・検証手順を作成し、整合性を確認する。
- [x] T002 `specs/TAK-78-publish-app-tests/` の設計を保守者に示し、実装前の承認を得る。

## Phase 2: US1 公開検査 (P1)

**Independent Test**: 一時公開先の成功・失敗ケースと macOS の実テスト選択を確認する。

- [x] T003 [US1] `scripts/dev/tests/test_publish_folzio.py` に Swift の呼び出し順と通常・性能テストの失敗を観測する一時フィクスチャと回帰テストを追加する。失敗時の後続検査とステージング未実行を検証する。
- [x] T004 [US1] `scripts/dev/publish.sh` の通常テストを CI と同じ非並列・性能テスト除外の実行に変更し、性能テストをその後に実行する。
- [x] T005 [US1] `specs/product/overview.md` と `specs/product/contracts/scripts.md` に FR-311 の公開検査と異常終了を反映し、`specs/product/README.md` の件数を更新する。反映前に ID の重複を確認する。

## Phase 3: US2 公開手順 (P2)

**Independent Test**: 実行順と公開手順を照合する。

- [x] T006 [US2] `docs_private/repository-and-release.md` に通常・性能テストの順序と同期後失敗時の状態を記す。
- [x] T007 [US2] `specs/product/overview.md` に FR-312 を反映する。

## Phase 4: 検証とレビュー

- [x] T008 `specs/TAK-78-publish-app-tests/quickstart.md` に従って回帰テスト、仕様検査と macOS 実テストを実施し、結果または未実施の理由を `specs/TAK-78-publish-app-tests/tasks.md` に記録する。
- [x] T009 `specs/product/` の反映差分と検証結果を保守者に示し、コミット前に承認を得る。

検証記録（2026-11-05）: Cloud の `scripts/dev/check-all.sh` は成功（71 テスト）。製品仕様の形式検査はエラー 0 件、警告 88 件（既存の基準値と同数）。レビューでは rsync の代替を用いた 12 件の成功と、元の Core のみのコマンドに戻すと新規 3 件が失敗することを確認した。最新コミット `ef305ba` の公開回帰テストと macOS 検証は、保守者が実施し問題なしと報告した。

製品仕様の反映差分と検証状況は保守者に提示し、2026-11-05 に承認された。

凍結手順: 全タスクの状態と検証結果を記録し、保守者に注記案を示して承認を得た後、`specs/TAK-78-publish-app-tests/spec.md` に移行済み・凍結の注記を付ける。注記は feature ディレクトリの最後の編集とする。未確認の検証を成功扱いにしない。
