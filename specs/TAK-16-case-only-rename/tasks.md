# Tasks: TAK-16 大文字小文字だけの改名

**Input**: `specs/TAK-16-case-only-rename/` の設計文書。
**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/rename.md / quickstart.md。
**Tests**: Core の自動テスト必須。実装は保守者の設計承認後。

## Phase 1: Setup

- [x] T001 `specs/TAK-16-case-only-rename/spec.md` と checklists/requirements.md を作成し、TAK-16 と現行仕様の変更点を検査する。
- [x] T002 `specs/TAK-16-case-only-rename/plan.md`・research.md・data-model.md・contracts/rename.md・quickstart.md に設計と検証方法を記録する。
- [x] T003 `specs/TAK-16-case-only-rename/plan.md` の保守者レビューと実装承認を得る。未承認なら T004 以降に進まない。

## Phase 2: Foundational

- [x] T004 `Sources/FolzioCore/Operations/NameValidation.swift` の existingNames の契約を英語コメントで明記し、「元項目の保存名と完全一致するエントリだけを除外する」「別項目の競合比較は大文字小文字を無視する」を Coordinator と Service の実装に適用する準備をする。公開 API は変更しない。

## Phase 3: User Story 1 — ファイル (P1)

**Goal**: 自己ファイルの表記変更を許可し、別項目との競合を全 resolution で拒否する。
**Independent Test**: photo.png → Photo.png / photo.PNG の成功と保存名・内容、別項目の競合拒否を確認する。

- [x] T005 [US1] `Tests/FolzioCoreTests/NameValidationTests.swift` に元項目を除いた集合での自己 case-only 許可と、別項目を含む集合での duplicate を別テストとして追加する。空入力・禁止文字・先頭ドット・拡張子の既存確認は維持する（FR-025・EC-14・SC-096）。
- [ ] T006 [US1] `Tests/FolzioCoreTests/FileOperationServiceTests.swift` に case-only と拡張子表記のみの改名を追加し、成功 URL・contentsOfDirectory の完全一致名・内容保存を確認する。host volume の性質を判定し記録する（SC-096）。
- [ ] T007 [US1] `Tests/FolzioCoreTests/FileOperationServiceTests.swift` に別項目の同名/大小文字違い、hard link・symlink・dangling symlink、同じ表記の no-op、元消失・列挙不可・書き込み不可の異常系を追加する。競合は abort/replace/keepBoth の全値で双方を保持する（FR-025・EC-14・SC-097）。大小文字違いの別項目共存は case-sensitive volume で実施し、条件不足なら未検証として記録する。
- [x] T008 [US1] `Sources/FolzioCore/Operations/FileOperationService.swift` の rename に兄弟の完全一致による自己除外と比較を実装する。列挙失敗を握りつぶさず、競合は全 resolution で sameNameExists とする。自己 case-only の target 存在だけでは拒否しない。既存の moveItem で入力表記の成功 URL を返す。copy/move の解決規則を維持する（FR-025・EC-14）。
- [ ] T009 [US1] `Tests/FolzioCoreTests/SearchRenameLedgerTests.swift` に case-only のファイル URL 更新を追加し、`Sources/FolzioApp/Operations/FileOperationCoordinator.swift` から既存の確認・検索結果・履歴の通知が通ることを確認する。必要な調整だけを行う（FR-027・SC-097）。

## Phase 4: User Story 2 — フォルダ (P1)

**Goal**: 同じ処理を一覧とツリーの通常フォルダに適用し、表示中の子孫を保つ。
**Independent Test**: Album → album と別兄弟 ALBUM への競合、子ファイルの内容・表示先の継続。

- [ ] T010 [US2] `Tests/FolzioCoreTests/NameValidationTests.swift` と FileOperationServiceTests.swift にフォルダの自己 case-only、別フォルダ/ファイル/リンクとの競合、中身の保存を追加する。禁止文字・先頭ドット・パッケージ化の拒否と拡張子確認なしを維持する（FR-103・EC-14・SC-096/097）。
- [ ] T011 [US2] `Tests/FolzioCoreTests/RenamedFolderTests.swift` と SearchRenameLedgerTests.swift に case-only の親/祖先 URL 置換を追加する。`Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の既存のフォルダ通知を使い、必要な Core の修正を行う（FR-104・FR-105・SC-097）。
- [ ] T012 [US2] `specs/TAK-16-case-only-rename/quickstart.md` の両ボリュームの手順を保守者に実行依頼し、ツリー/一覧/サムネイル/検索の表示・選択・展開・スクロール・プレビュー・履歴、常時確認・キャンセルの結果をこの tasks.md に記録する（FR-103・FR-104・A-39・US1-AS39・SC-096/097）。

## Phase 5: Polish & Cross-Cutting

- [ ] T013 `scripts/check-no-network.sh`、scripts/check-readme-sync.sh master、scripts/dev/check-english-comments.sh、scripts/dev/tests/test_check_git_push.py を Cloud で実行し、この tasks.md に結果を記録する。
- [ ] T014 `.github/workflows/macos-swift-ci.yml` で swift build/test を確認する。保守者の PR 依頼があるまでは PR を作らず、CI 未実行として記録する。case-only の moveItem が実機で失敗する場合は実装を完了扱いせず設計を見直す。
- [ ] T015 `specs/TAK-16-case-only-rename/quickstart.md` の起動スモークとローカル build/test を保守者に実行依頼し、結果をこの tasks.md に記録する。未確認なら未チェックのまま残す。
- [ ] T016 検証完了後に最新 master を取り込み、`specs/product/file-operations.md`・directory-tree.md に spec.md の反映表の変更を用意する。SC-096/097 の衝突を確認し、衝突ならこの feature の未マージ ID だけを振り直す。反映差分の承認後にコミットし spec.md を凍結する。

## Dependencies & Execution Order

T001 → T002 → T003 → T004 → US1 (T005–T009) → US2 (T010–T012) → T013–T016。

US2 は同じ Service を使うため実装順では US1 に依存するが、フォルダの受け入れ確認は独立して行える。T006 の macOS 成功確認で改名手法を検証してから範囲を広げる。US1 を最小の検証単位とするが、TAK-16 の完了には両 story が必要。

## Parallel Opportunities

Cloud ではタスクを分割して並列実装しない（AGENTS.md）。US1/US2 とも同じテスト・Service ファイルを編集するため直列で実施する。[P] は付けない。静的検査の独立した読み取りのみ同時実行可能。

## Implementation Strategy

承認 → テスト → 最小のファイル改名 → macOS の保存表記確認 → フォルダと表示反映 → 回帰検証 → product 反映。大文字小文字を区別しないボリュームで旧パスの存在を失敗と判定しない。

## Execution Notes

- 2026-10-31: Linear TAK-16 を In Progress に更新。origin/master bfe63d5 を work に取り込み。
- 設計文書のみ作成。Sources/Tests と specs/product/ は未変更。承認・Swift/CI・GUI の検証は未完了。
- 共有 agent context ツールはサーバー側 Tool not found のため取得不可。
- git の実ブランチは work。SPECIFY_FEATURE_DIRECTORY を渡す補助スクリプトの BRANCH 出力は feature ディレクトリ名になるため、実ブランチは git branch --show-current を正とする。
- work は push 許可リストの接頭辞に一致しないため未 push。push 段階で保守者の許可を得て許可された名前へ移す。

- 設計段階の Cloud 検査: check-no-network / check-english-comments / test_check_git_push.py (3 tests) / git diff --check は成功。README 同期はローカル master が未作成で既定コマンドが失敗し、取得済み origin/master を基準に再実行して成功。タスク形式・16 個の連番・文書内リンクを検査。T013 は実装後の再実行を要するため未チェック。

- 保守者の ok により設計承認済み。speckit-implement 開始。ファイルの回帰テストと最小の Service 変更を追加。T006/T007 は macOS 実行および残る異常系の確認後にチェックする。
