# Tasks: ファイルリストの削除後の選択

**Input**: `specs/023-select-after-trash/` の spec / plan / research / data-model / contracts / quickstart
**Prerequisites**: 設計レビューの承認。2026-11-17 に保守者が設計を承認。
**Tests**: 憲章 IV に従い Core の判断と異常系を必須とし、App の接続も回帰テストする。
**Organization**: User Story 87 / 88 の順に、同じセッションで順次実行する。

## Format

`- [ ] Tnnn [MANUAL?] [P?] [USnn?] 具体的な作業とファイル`

[MANUAL] は利用者の報告・判断が必要な確認だけに付け、ID の直後に置く。
その分類は設計承認時に固定し、実装中は変更しない。実装・自動検証・文書記録と同じタスクに混ぜない。
[P] はファイルと依存が独立した作業を示すが、本セッションでは並列化しない。
設計承認後、実装中に文書を更新するのはこの tasks.md のチェック・検証記録と、明示した反映タスクだけとする。

## Phase 1: Setup — 設計ゲート

- [X] T001 [MANUAL] `specs/023-select-after-trash/spec.md`・`plan.md`・`tasks.md` と関連設計成果物・analyze の結果をレビューし、auto clarify の採用回答と [MANUAL] 分類を保守者が承認する。
- [X] T002 T001 の承認報告を `specs/023-select-after-trash/tasks.md` の検証記録へ残し、レビュー済みの feature 文書だけをコミットする。

## Phase 2: Foundational — 既存基盤の再利用

新規セットアップ・依存導入・永続化変更はない。既存 FileOperating / SelectionState / BrowserModel の
非同期列挙・検索・preview を再利用する。共通の新規判断は Phase 3 で実装する。

## Phase 3: User Story 87 — 削除後の次行選択 (Priority: P1 / MVP)

**Goal**: FR-399・FR-401・FR-402・FR-087、EC-268〜269、SC-221・SC-223、A-240 を満たす。
**Independent Test**: B 単一→C、B・C→D、B・D→E、末尾を含む削除→選択なし。

- [ ] T003 [P] [US87] `Tests/FolzioCoreTests/PostTrashSelectionTests.swift` に単一・連続・非連続・末尾・空・キャンセル・全失敗・部分失敗・選択外操作・消えた候補・子孫・新着候補除外・`..` を含む残存選択の判断テストを先に追加する。
- [ ] T004 [P] [US87] `Tests/FolzioCoreTests/BrowserModelTrashSelectionTests.swift` と `BrowserModelSearchTests.swift` に先行する監視除去、プレビュー・動画停止、表示条件・選択変更と往復変更、検索中の子孫・遅延結果除外、一覧更新失敗のテストを追加する。
- [ ] T005 [US87] `Sources/FolzioCore/Model/PostTrashSelection.swift` に記録と判断を実装する（「空でなく、全対象が元の選択に含まれる」「表示順を固定し、後から届いた行を足さない」「世代が変わった記録は適用しない」）。URL 集合と線形走査を使い、1万行・5000選択も T003 に加える。
- [ ] T006 [US87] `Sources/FolzioCore/Browser/BrowserModel.swift` に削除前の記録・利用者操作世代・結果適用を接続する。自動の選択制限と利用者操作を区別し、監視通知が先でも適用でき、世代不一致・退避・更新失敗では適用しない。既存 select と検索除外を再利用する。
- [ ] T007 [US87] `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の fileList 起点だけで最初の await 前に記録し、確認・成功元 URL・履歴・検索除外・reload の後に適用する。キャンセル・全件失敗・選択外右クリック・tree 起点では新しい自動選択を行わない。
- [ ] T008 [US87] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の削除後の新しいフォーカスを必要最小限スクロールで可視化し、`ListModeView.swift` の既存追従を再利用する。`Tests/FolzioAppTests/FileListTrashSelectionTests.swift` と `FileListContextClickTests.swift` に fake service と両形式の接続・右クリック・フォーカス保持・確認オンオフの回帰検証を追加する。
- [ ] T009 [US87] `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` の順で検証し、`quickstart.md` 指定の既存性能確認を行って結果をこの tasks.md の検証記録へ残す。
- [ ] T010 [MANUAL] [US87] 保守者が `open .build/Folzio.app` を実行し、`specs/023-select-after-trash/quickstart.md` の Phase 3 の3ペイン・削除・失敗・検索・絞り込み・スクロール・フォーカスの確認を報告する。
- [ ] T011 [US87] T010 の実報告をこの `tasks.md` へ記録し、Phase 3 の実装・テスト・進捗をコミットする。

## Phase 4: User Story 88 — 空選択からの上下キー (Priority: P1)

**Goal**: FR-400 と SC-222 を満たし、末尾削除の選択なしを維持する。
**Independent Test**: 選択なしで ↑→最下部、↓→最上部、空→移動なし、`..` だけならそれを選ぶ。

- [ ] T012 [P] [US88] `Tests/FolzioCoreTests/FocusNavigatorTests.swift` と `Tests/FolzioAppTests/FileListEmptySelectionNavigationTests.swift` に両形式の修飾キーなし ↑・↓、空・`..`、Shift・左右・既存選択中・プレビュー移動の回帰テストを先に追加する。
- [ ] T013 [US88] `Sources/FolzioCore/Layout/FocusNavigator.swift` に通常一覧の空選択の入口判断を設け、`Sources/FolzioApp/FileList/ListModeView.swift`・`ThumbnailModeView.swift` の対象キーだけに接続する。`selected` と `focused` がともに空のときに限定し、full screen / hidden list の経路を保つ。
- [ ] T014 [US88] `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` の順で検証し、この `tasks.md` の検証記録へ結果を残す。
- [ ] T015 [MANUAL] [US88] 保守者が `open .build/Folzio.app` を実行し、`specs/023-select-after-trash/quickstart.md` の Phase 4 の3ペインと、両形式・通常と検索・空行・上下キー・既存キーの回帰確認を報告する。
- [ ] T016 [US88] T015 の実報告をこの `tasks.md` へ記録し、Phase 4 の実装・テスト・進捗をコミットする。

## Phase 5: Polish & Cross-Cutting — 最終検証・反映

- [ ] T017 最終版で `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` を再実行し、この `tasks.md` の検証記録へ結果と対象ビルドを残す。
- [ ] T018 [MANUAL] 保守者が `open .build/Folzio.app` を実行し、`specs/023-select-after-trash/quickstart.md` の最終ビルドの3ペインと主要操作の確認を報告する。
- [ ] T019 T018 の報告をこの `tasks.md` へ記録し、`speckit-converge` で feature と参照製品仕様に照らして残作業を確認し、必要なら workflow 上限3回で追記タスクの実装・検証へ戻る。
- [ ] T020 T019 の残作業がなくなってから `specs/product/README.md` の書き方を再確認し、`scripts/dev/check-spec-ids.sh` 実行後、spec.md の反映先表を `specs/product/file-list.md`・`search.md` へ、feature の `contracts/keyboard-and-menus.md` を製品契約へ反映する。feature の `spec.md` 冒頭に凍結注記を付け、`python3 scripts/dev/check-spec-format.py` と ID 検査を再実行してこの `tasks.md` に記録する（まだコミットしない）。
- [ ] T021 [MANUAL] 保守者が `git diff -- specs` の製品仕様反映・契約差分・feature 凍結注記と変更 ID 一覧を確認し、反映のコミットを承認する。
- [ ] T022 T021 の承認をこの `tasks.md` へ記録し、製品仕様と feature の記録をコミットしてブランチ・検証・残課題を報告する。

## Dependencies & Execution Order

T001 → T002 → T003/T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011
→ T012 → T013 → T014 → T015 → T016 → T017 → T018 → T019 → T020 → T021 → T022。

User Story 88 は空選択を直接作れば単独検証可能だが、削除との通し確認は User Story 87 の後に行う。
各 [MANUAL] は直前の自動検証に依存し、後続の記録・完了コミットをブロックする。
T019 の結果に残作業があれば、T020 以降へは進まない。
設計文書は T001 の承認後、実装 Phase は対応する GUI 報告後にコミットする。
PR 作成・push・master への統合はタスクに含めない。

## Parallel Examples

- US87: T003 と T004 は独立したテストファイルなので並列可能だが、このセッションでは順次行う。
- US88: T012 の Core と App のテストはファイルとして独立するが、このセッションでは順次行う。
- 共有 BrowserModel と UI の変更は依存順に直列で行う。

## Implementation Strategy

まず US87 を MVP として自動検証・GUI 確認・コミットし、次に US88 を同じ手順で仕上げる。
最終検証・起動確認・converge の後にだけ製品仕様を反映する。
GUI をエージェントが起動したことやテスト成功を、保守者の確認報告の代わりには使わない。

## 検証記録

- 2026-11-17: 設計成果物を作成。設計承認待ち。実装・自動検証・GUI 確認は未実施。

- 2026-11-17: 保守者が設計レビューの「実装へ進めてよいですか？」へ `ok` と回答（annotation 063edbda-e4d8-40f3-863c-fefc7c409e54）。T001 承認を受領し、T002 の設計文書をコミットする。
