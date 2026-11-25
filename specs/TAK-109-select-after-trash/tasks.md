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

- [X] T003 [P] [US87] `Tests/FolzioCoreTests/PostTrashSelectionTests.swift` に単一・連続・非連続・末尾・空・キャンセル・全失敗・部分失敗・選択外操作・消えた候補・子孫・新着候補除外・`..` を含む残存選択の判断テストを先に追加する。
- [X] T004 [P] [US87] `Tests/FolzioCoreTests/BrowserModelTrashSelectionTests.swift` と `BrowserModelSearchTests.swift` に先行する監視除去、プレビュー・動画停止、表示条件・選択変更と往復変更、検索中の子孫・遅延結果除外、一覧更新失敗のテストを追加する。
- [X] T005 [US87] `Sources/FolzioCore/Model/PostTrashSelection.swift` に記録と判断を実装する（「空でなく、全対象が元の選択に含まれる」「表示順を固定し、後から届いた行を足さない」「世代が変わった記録は適用しない」）。URL 集合と線形走査を使い、1万行・5000選択も T003 に加える。
- [X] T006 [US87] `Sources/FolzioCore/Browser/BrowserModel.swift` に削除前の記録・利用者操作世代・結果適用を接続する。自動の選択制限と利用者操作を区別し、監視通知が先でも適用でき、世代不一致・退避・更新失敗では適用しない。既存 select と検索除外を再利用する。
- [X] T007 [US87] `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の fileList 起点だけで最初の await 前に記録し、確認・成功元 URL・履歴・検索除外・reload の後に適用する。キャンセル・全件失敗・選択外右クリック・tree 起点では新しい自動選択を行わない。
- [X] T008 [US87] `Sources/FolzioApp/FileList/ThumbnailModeView.swift` の削除後の新しいフォーカスを必要最小限スクロールで可視化し、`ListModeView.swift` の既存追従を再利用する。`Tests/FolzioAppTests/FileListTrashSelectionTests.swift` と `FileListContextClickTests.swift` に fake service と両形式の接続・右クリック・フォーカス保持・確認オンオフの回帰検証を追加する。
- [X] T009 [US87] `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` の順で検証し、`quickstart.md` 指定の既存性能確認を行って結果をこの tasks.md の検証記録へ残す。
- [X] T010 [MANUAL] [US87] 保守者が `open .build/Folzio.app` を実行し、`specs/023-select-after-trash/quickstart.md` の Phase 3 の3ペイン・削除・失敗・検索・絞り込み・スクロール・フォーカスの確認を報告する。
- [X] T011 [US87] T010 の実報告をこの `tasks.md` へ記録し、Phase 3 の実装・テスト・進捗をコミットする。

## Phase 4: User Story 88 — 空選択からの上下キー (Priority: P1)

**Goal**: FR-400 と SC-222 を満たし、末尾削除の選択なしを維持する。
**Independent Test**: 選択なしで ↑→最下部、↓→最上部、空→移動なし、`..` だけならそれを選ぶ。

- [X] T012 [P] [US88] `Tests/FolzioCoreTests/FocusNavigatorTests.swift` と `Tests/FolzioAppTests/FileListEmptySelectionNavigationTests.swift` に両形式の修飾キーなし ↑・↓、空・`..`、Shift・左右・既存選択中・プレビュー移動の回帰テストを先に追加する。
- [X] T013 [US88] `Sources/FolzioCore/Layout/FocusNavigator.swift` に通常一覧の空選択の入口判断を設け、`Sources/FolzioApp/FileList/ListModeView.swift`・`ThumbnailModeView.swift` の対象キーだけに接続する。`selected` と `focused` がともに空のときに限定し、full screen / hidden list の経路を保つ。
- [X] T014 [US88] `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` の順で検証し、この `tasks.md` の検証記録へ結果を残す。
- [X] T015 [MANUAL] [US88] 保守者が `open .build/Folzio.app` を実行し、`specs/023-select-after-trash/quickstart.md` の Phase 4 の3ペインと、両形式・通常と検索・空行・上下キー・既存キーの回帰確認を報告する。
- [X] T016 [US88] T015 の実報告をこの `tasks.md` へ記録し、Phase 4 の実装・テスト・進捗をコミットする。

## Phase 5: Polish & Cross-Cutting — 最終検証・反映

- [X] T017 最終版で `swift build` → `swift test` → `scripts/dev/check-all.sh` → `scripts/make-app.sh` を再実行し、この `tasks.md` の検証記録へ結果と対象ビルドを残す。
- [X] T018 [MANUAL] 保守者が `open .build/Folzio.app` を実行し、`specs/023-select-after-trash/quickstart.md` の最終ビルドの3ペインと主要操作の確認を報告する。
- [X] T019 T018 の報告をこの `tasks.md` へ記録し、`speckit-converge` で feature と参照製品仕様に照らして残作業を確認し、必要なら workflow 上限3回で追記タスクの実装・検証へ戻る。
- [X] T020 T019 の残作業がなくなってから `specs/product/README.md` の書き方を再確認し、`scripts/dev/check-spec-ids.sh` 実行後、spec.md の反映先表を `specs/product/file-list.md`・`search.md` へ、feature の `contracts/keyboard-and-menus.md` を製品契約へ反映する。feature の `spec.md` 冒頭に凍結注記を付け、`python3 scripts/dev/check-spec-format.py` と ID 検査を再実行してこの `tasks.md` に記録する（まだコミットしない）。
- [X] T021 [MANUAL] 保守者が `git diff -- specs` の製品仕様反映・契約差分・feature 凍結注記と変更 ID 一覧を確認し、反映のコミットを承認する。
- [X] T022 T021 の承認をこの `tasks.md` へ記録し、製品仕様と feature の記録をコミットしてブランチ・検証・残課題を報告する。

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

- Phase 3: T003〜T008 の実装と回帰検証を実施。未実装 API による red を確認後、Core の12テスト・App の削除/右クリック11テストが通過。追加の境界テストを含めて Phase 検証へ進む。

- Phase 3 自動検証: `swift build` 成功。`swift test` は終了コード0、Core 1156件（127スイート）と性能28件の成功サマリーを確認。
  App の一括実行は終了コード0でも完了サマリーが記録されなかったため、22スイートを個別実行して117件すべての完了・成功を確認した。
  一括実行ログが途中で終わる原因の診断・既存テスト基盤の変更は行っていない。
- `scripts/dev/check-all.sh` は全項目成功。`scripts/make-app.sh` 成功、`git diff --check` 成功。
  ログ: `/tmp/folzio-tak109-build.log`、`/tmp/folzio-tak109-test.log`、`/tmp/folzio-tak109-app-suites/`、
  `/tmp/folzio-tak109-check-all.log`、`/tmp/folzio-tak109-make-app.log`。
- 選択判断の1万行・5000選択: 単独検証31ms、全テスト中62ms。既存性能テストの基準は変更していない。
- 手動確認対象: 設計コミット `bdba64a` + Phase 3 未コミット差分、`.build/Folzio.app`。
  実行ファイル SHA-256: `27ce1491a545872f547089bbf9accf00a89d3c21a88c630d920ab67760b97b86`。ビルド環境: macOS 26.7.3 / arm64。
- T010 の保守者による GUI 確認待ち。アプリは起動していない。T010・T011 は未チェックで維持し、
  Phase 4 は T010 の報告と T011 のコミット後に進む。

- 2026-11-18: 保守者の指示により Computer Use 検証を中止。作業用ビルドの起動と3ペイン表示、
  テスト用ツリーの表示までは確認したが、削除シナリオは Computer Use では未実施。専用の使い捨て fixture を削除した。
- 保守者から T015 の確認報告を受領: リスト形式の末尾削除は期待どおり、サムネイル形式は削除後の ↑・↓ が
  ともに先頭へ移動して不一致。T015 は未完了のままとし、指摘に対応する T012〜T014 を先に進める。
  T010 全ケースの完了や T011 のコミットは推定せず、元の [MANUAL] 分類と未チェックを維持する。

- 2026-11-18: T012 の AppKit 再現テストで、サムネイルの末尾削除後の ↑ が先頭を選ぶ失敗を確認。
  ビューの非同期更新を待った再現ではリスト形式は通過し、サムネイルの ↑ だけが失敗した。
- T013: 通常のファイルリストの空選択・修飾キーなしの上下キーに限る Core の入口判断を追加し、
  サムネイルへ接続した。リスト形式は標準 NSTableView の動作を回帰テストで確認できたため維持する。
  Shift・左右・既存選択中・full screen / hidden list の経路は従来どおり。
  修正後は上下キー・空・`..`・既存移動の App 4テストと Core の移動テストが通過。

- 2026-11-18 Phase 4 自動検証: `swift build` 成功。Core 1158件（127スイート）成功。
  全体の `swift test` は、既存のスライドショー候補抽出20万件が200ms基準に対して200.2165msとなり終了コード1。
  同テストを含む `SlideshowPerformanceTests` を単独再実行し、5件成功、当該測定106.352msで通過した。
  性能の基準値・対象実装には変更なし。ほかの性能27件は最初の実行で成功。
  App は一括実行の完了サマリーがないため23スイートを個別実行し、121件すべての完了・成功を確認した。
- `scripts/dev/check-all.sh`、`scripts/make-app.sh`、`git diff --check` 成功。
  ログ: `/tmp/folzio-tak109-phase4-build.log`、`/tmp/folzio-tak109-phase4-test.log`、
  `/tmp/folzio-tak109-phase4-perf-retry.log`、`/tmp/folzio-tak109-phase4-app-suites/`、
  `/tmp/folzio-tak109-phase4-check-all.log`、`/tmp/folzio-tak109-phase4-make-app.log`。
- T015 の再確認対象: `bdba64a` + Phase 3・4 未コミット差分の `.build/Folzio.app`。
  実行ファイル SHA-256: `e5c23a76378cf64e809334c32b4dbae4d44f9683e1a0897f3c8a51af88e08911`。
  Computer Use は中止済みで、修正版のアプリをエージェントは起動していない。
  T015・T016 は保守者の再確認まで未チェックで維持する。

- 2026-11-18: 保守者から「修正されていることを確認しました」と再確認報告を受領。
  先のリスト形式の成功報告と合わせ、末尾削除後の ↑・↓ の挙動は両表示形式で確認済み。
  T015 のうち検索結果・空行・既存キーを含む確認全体と、T010 の Phase 3 全ケースの確認範囲は、
  以前の「私が確認しました」の範囲を保守者へ確認中。
  未確認のケースを推定せず、T010・T015 の全体チェック、T011・T016 の完了コミットは保留する。

- 2026-11-18: 保守者が Phase 3 の「複数削除・検索／絞り込み・キャンセル／失敗時なども確認済み」と回答
  （annotation c1fa8f07-7a3a-46c2-a8fa-54e8a2164479）。T010 の確認範囲を確定した。
  先のリスト形式と修正後のサムネイル形式の成功報告と合わせ T015 の報告も受領済みとする。
  既存の自動検証と GUI 報告を記録し、Phase 3、Phase 4 の順にコミットする。

- Phase 3 は `8845a14` にコミット済み。確認済みの上下キー処理・回帰テストと T016 の記録を Phase 4 としてコミットする。

- 最終検証（`6c27712`）: `swift build`、`swift test`（Core 1158件・性能28件）、
  App の23スイート個別実行（121件）、`scripts/dev/check-all.sh`、`scripts/make-app.sh` がすべて成功。
  今回の性能テストは再試行なしで全件成功。一括 App ログの完了サマリー欠落は継続するため個別完了を確認した。
- T018: 再作成前の保守者確認済みアプリと、最終アプリの全8ファイルの SHA-256 が完全一致した。
  2026-11-18 の保守者による両形式の起動・主要操作・修正確認と Phase 3 全ケースの確認報告を、
  同一アーティファクトの最終起動確認として紐付けた。GUI の再起動や Computer Use の再実施は行っていない。
  manifest: `/tmp/folzio-tak109-confirmed-app-manifest.json`、`/tmp/folzio-tak109-final-app-manifest.json`。
  検証ログ: `/tmp/folzio-tak109-final-build.log`、`/tmp/folzio-tak109-final-test.log`、
  `/tmp/folzio-tak109-final-app-suites/`、`/tmp/folzio-tak109-final-check-all.log`、
  `/tmp/folzio-tak109-final-make-app.log`。

- Converge: 機能要件5・成功基準3・受け入れシナリオ9・エッジケース2・前提1の20項目、
  主要設計判断6件、憲章5原則を実装・自動検証・保守者報告と照合。実装の missing / partial / contradicts /
  unrequested および各 severity の指摘は0件。Converge 自体は tasks.md を変更せず終了し、ここに進捗を記録した。
  残りは既存 T020〜T022 の製品仕様反映・承認・コミットのみで、追加の実装タスクはない。
- T020: ID 事前検査成功後、反映先表の20項目と横断の操作契約を製品仕様へ反映し、
  README の領域索引に削除後の選択4件を追記、feature 冒頭に凍結注記を準備した。
  反映差分は保守者の承認待ちで、まだコミットしない。

- T020 検証: 反映先の20定義が feature の決定済み本文と一致することを照合。製品仕様の形式検査はエラー0・警告84（基準値84）、反映後の ID 検査と差分検査も成功。T021 の反映承認待ち。

- 2026-11-18: 保守者が製品仕様への反映コミットに `ok` と回答
  （annotation e144b52f-2eb8-4121-bb78-3eb9ad651a40）。T021 の承認を受領した。
  反映・凍結注記・全タスク完了の記録を T022 としてコミットし、作業ブランチと検証結果を報告する。
