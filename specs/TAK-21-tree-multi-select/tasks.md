# Tasks: TAK-21 ツリーでのフォルダの複数選択と一括操作

**Input**: `specs/TAK-21-tree-multi-select/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/tree-selection.md / quickstart.md

**Tests**: Core の判断（対象・可否・重なり）に自動テストを付ける。GUI は保守者がローカルで確認する。実装は保守者の設計承認の後に行う。

## Phase 1: Setup

- [x] T001 `specs/TAK-21-tree-multi-select/spec.md` と `checklists/requirements.md` を作り、TAK-21 と現行仕様の変更点を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/tree-selection.md`・`quickstart.md` に設計と検証方法を記録する
- [x] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: Foundational（全ストーリーの前提）

- [x] T004 `Tests/FolzioCoreTests/TreeBatchTargetsTests.swift` を作り、FR-217 の対象の決定（キーボード／選択中の行の右クリック・ドラッグ／選択外の行）、FR-218 の可否
  （通常のフォルダだけ／ホーム・ボリュームの最上位・お気に入り・見出しを含む／1件と複数）、EC-146 の親子の重なり（直接の子・孫・兄弟・同名の前方一致 `A` と `AB`）、
  1件のときに `FavoriteCommands` の `trashTarget`・`removalTarget`・`renameTarget` と一致することをテストする（先に失敗させる）
- [x] T005 `Sources/FolzioCore/Model/TreeBatchTargets.swift` を実装して T004 を通す（data-model.md、R1・R2）。ディスクを読まない
- [x] T006 `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` に、選択中の行の role の配列と、メニュー・ドラッグを始めた行から `TreeBatchTargets` を作る補助を加え、
  `selectedItem` を使う判断を置き換える準備をする（R7）。この時点では `allowsMultipleSelection` を変えない

## Phase 3: User Story 38 - 複数選択中の表示とメニュー (P2、P1 の前提)

**Goal**: 複数選択でき、主の行のフォルダを表示し、単一の対象を前提とする操作を誤って実行しない

**Independent Test**: quickstart の S2・S3・S7・S9

- [x] T007 [US38] `DirectoryTreeViewController.swift` の `DragAwareOutlineView` に主の行とアンカー（item で保持）を加え、⌘クリック・Shift クリック（`mouseDown`）と
  ↑↓・Shift+↑↓（`keyDown`）を自前で処理する。Control クリック・開閉の三角・修飾キーなしのクリックは `super` に任せる。`allowsMultipleSelection = true` にする
  （FR-215、R4、A-132、data-model.md の TreeSelectionLead）
- [x] T008 [US38] `outlineViewSelectionDidChange` と `trackingEnded` を、主の行が変わったときだけ `model.selectFolder` を呼ぶように変える。⌘クリックで外したときは表示を変えない。
  `syncSelection` で1行を選択したときはアンカーと主の行をその行にする。検索結果の表示中に複数選択の中の行を通常のクリックで選んだときは `clickedRow` と同じく検索結果の表示を終える
  （FR-216・FR-086、R4）
- [x] T009 [US38] `validateMenuItem`・`menuNeedsUpdate`・`rename(_:)`・`paste(_:)`・`movePaste(_:)`・`copyPathname(_:)`・`revealInFinder(_:)`・`addToFavorites(_:)`・
  `removeFavoriteFromMenu(_:)` を `TreeBatchTargets` の `isSingle` に従わせる。`Sources/FolzioApp/App/MainSplitViewController.swift` の `canAddSelectedFolderToFavorites` も複数選択で false にする
  （FR-218（2）（3）・FR-183、R7）。複数を対象にする右クリックメニューは、対象の種類に関わらず通常のフォルダの項目を出す（FR-218（3））
- [x] T010 [US38] ツリーの `selectAll(_:)` を無効にする（A-126、R8）。2行以上の選択で、`outlineViewItemWillCollapse` で隠れる行の選択を外し、`outlineViewItemDidCollapse` で
  結果を検査して戻す。隠れた主の行からのキーボードの移動は見える祖先の行を起点にする。1行の選択の折りたたみは変えない（EC-148・A-131、R9）
- [x] T011 [US38] 名前の編集中に ⌘クリック・Shift クリックで選択を変えたとき、編集を確定することを確かめ、必要なら `finishEditing` を呼ぶ（FR-103・FR-102）

## Phase 4: User Story 36 - 複数のフォルダをまとめて移動・コピーする (P1)

**Goal**: 複数選択からのドラッグで、まとめて移動・コピーする

**Independent Test**: quickstart の S4・S5

- [x] T012 [US36] `DragAwareOutlineView` で `canDragRows(with:at:)` を override し、`rowIndexes` の行の role から作った `TreeBatchTargets.dragURLs` が nil、または対象と
  `rowIndexes` が一致しないときは false を返す（FR-218（1）・FR-162、R5）。`pasteboardWriterForItem` は従来どおり通常のフォルダだけに URL を返す
- [x] T013 [US36] ドラッグ後の選択の復元を、ドラッグ前の選択全体と主の行に広げる。選択外の行からドラッグを中止したとき、ファイルリストの表示が変わらないことを確かめる（FR-217（3）・US36-AS2、R5）
- [x] T014 [US36] ツリーからの移動の完了で、1件以上が成功したらツリーを主の行の単一選択にする。表示中のフォルダが切り替わった場合は同期に任せる。主の行が折りたたみで隠れていれば祖先を展開してから選択する（FR-219、R6）。`Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の
  `internalDrop` からツリーへの通知を加える。コピー・キャンセル・すべて失敗では選択を変えない
- [x] T015 [US36] 宛先の検証が複数のツリーのフォルダで `InternalDropValidation`（EC-16・EC-121）に従うことを `Tests/FolzioCoreTests/InternalDropValidationTests.swift` で確かめ、
  足りないケース（異なる親の複数フォルダ・親と子の同時選択・宛先が選択の1つの配下）を追加する

## Phase 5: User Story 37 - 複数のフォルダをまとめてゴミ箱に入れる (P1)

**Goal**: ⌘⌫ と「ゴミ箱に入れる」で、まとめてゴミ箱に入れる

**Independent Test**: quickstart の S6・S8・S10

- [x] T016 [US37] `moveToTrash(_:)` と `trashFolderFromMenu(_:)` を `TreeBatchTargets.trashURLs` に従わせる。`.overlapping` はエラーを表示して何もしない（EC-146）。
  `.unavailable` は何もしない。お気に入り1件の ⌘⌫ は従来どおり（FR-064）。複数の選択では、メニューの ⌘⌫ の項目の名前を「ゴミ箱に入れる」にする（現行は単一のお気に入りで「お気に入りから削除」に切り替えている）。一部の失敗・外部で消えた項目は既存の `presentFailures` で成功と区別して示す（EC-147）
- [x] T017 [US37] `Sources/FolzioLocalization/TextKey.swift` と `Resources/{ja,en}.lproj/Localizable.strings` に、EC-146 のエラーの見出し・説明と、複数の場所の行の文言を追加する。
  既存の `Tests/FolzioCoreTests/Localization/CatalogConsistencyTests.swift` が通ること
- [x] T018 [US37] `FileOperationCoordinator.trash(_:origin:)` と `Sources/FolzioApp/Operations/ConfirmationPresenter.swift` で、ツリーからの複数のゴミ箱の確認モーダルに
  各フォルダの名前と絶対パス（先頭5件と残りの件数）を示す。1件のときの表示は変えない（FR-079（変更）、A-127、R3）
- [x] T019 [US37] ゴミ箱の完了で FR-219 の選択の更新を行う（T014 と同じ経路）。表示中のフォルダまたは祖先を含む場合は既存の `leaveTrashedFolders` の同期に任せる（FR-079、R6）

## Phase 6: Polish & Cross-Cutting

- [x] T020 Cloud で `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、
  `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` を実行し、結果をこの tasks.md に記録する
- [x] T021 macOS CI で `swift build`・`swift test` を確認する（PR の作成時、または `workflow_dispatch`）。PR は保守者の依頼があったときだけ作る
- [x] T022 [MANUAL] 保守者に、起動スモークと quickstart の S1〜S14 をローカルで実行してもらい（SC-105〜SC-107 の確認を含む）、結果を `checklists/validation.md` に記録する。S3・S5・S7 は R4・R5・R9 の設計どおりに動くことを確かめる
- [x] T023 ユーザーガイド `docs/usage.ja.md`・`docs/usage.md` のツリーの操作の説明（お気に入り・⌘Delete の項）に、複数選択（⌘クリック・Shift クリック・Shift+↑↓）と
  一括の移動・コピー・ゴミ箱を両方に同じ構成で追記する。README は機能の概要だけで個別の操作を書いていないため変えない（`README.ja.md` 20〜21 行）
- [x] T024 検証の完了後に最新の master を取り込み、spec.md の「反映先」の項目を `specs/product/` と `specs/product/contracts/keyboard-and-menus.md` へ反映する。
  ID の衝突を確認し、衝突すればこの feature の ID を振り直す。差分を保守者に示し、承認後にコミットして spec.md を凍結する

## Dependencies & Execution Order

T001 → T002 → T003（承認）→ T004 → T005 → T006 → US38（T007〜T011）→ US36（T012〜T015）→ US37（T016〜T019）→ T020〜T024

US38 は複数選択そのものを有効にするため、P2 だが US36・US37 の前に行う。US36 と US37 は同じ `DirectoryTreeViewController.swift` と `FileOperationCoordinator.swift` を編集するため直列にする。
T014 と T019 は同じ選択の更新の経路を共有する。

## Parallel Opportunities

Cloud ではタスクを分割して並列実装しない（AGENTS.md）。[P] は付けない。

## Implementation Strategy

承認 → Core のテストと実装（T004・T005）→ 複数選択と無効化（US38）→ 移動・コピー（US36）→ ゴミ箱（US37）→ 静的検査・CI → 保守者の GUI 確認 → `specs/product/` への反映。
単一選択の振る舞い（既存の FR-079・FR-103・FR-064・FR-182）が変わらないことを、既存のテストと GUI 確認で確かめる。

## Execution Notes

- 2026-10-31: Linear TAK-21 を In Progress に更新。作業ブランチ `claude/youthful-brahmagupta-ocjb0d`（origin/master bc97861 を含む）
- 2026-10-31: 設計レビュー承認（3回の analyze と修正、R4・R5・R9 の設計変更を含む）。T004〜T019・T023 を実装。Cloud に Swift がないため、
  コンパイルとテスト（T004 の先に失敗させる確認を含む）は未実行で、T021 の CI で確認する
- 2026-10-31: T020 の Cloud の検査結果: `check-no-network.sh` 成功、`check-readme-sync.sh master` 成功、`check-english-comments.sh` 成功、
  `check-skill-sync.sh` 成功、`test_check_git_push.py` 3件成功
- 2026-10-31: 報告した懸念1を修正。⌘クリックで主の行を外した後の ↑↓ が、残った行ではなく主の行を起点にするようにした（`handleArrowKey`。spec の Edge Cases・contracts・quickstart S3 に追記）
- 2026-10-31: 報告した懸念2を修正。FR-219 のためのツリーの操作の記録を、ドロップせずに終わったドラッグ（`draggingSession endedAt` の操作なし）と、同じ対象の操作の終了（キャンセル・検証での拒否・コピーを含む。`FileOperationCoordinator.onOperationFinished`）で必ず消すようにした。ツリーの操作かどうかは、対象の集合が記録と一致するかで判断する
- 2026-10-31: T023 で `docs/usage*.md` のツリーのゴミ箱の行にあった「設定で省略可」を、FR-079・FR-024 の「常に確認」に合わせて直した（既存の記述の誤り）
- 2026-10-31: T021 の CI（workflow_dispatch）。1回目 run 41233582341（f4fc424）: build 成功、通常のテスト 865 件中 1 件失敗
  （`BrowserModelTests.swift:22` の言語変更中の列挙。100ms の遅延と 20ms の待機に依存する既存のテストで、この feature は `BrowserModel` に触れていない）。
  2回目 run 41234498612（d658759）: build・通常のテスト・性能テスト（`Test run with 27 tests passed`）すべて成功。
  新規の `TreeBatchTargetsTests` と `InternalDropValidationTests` の追加分は両方の実行で成功
- 2026-11-01: T022 の GUI の確認。保守者が S1〜S14 をすべて確認し、期待どおりと報告（`checklists/validation.md`）。OS は未回答。ローカルの swift build・swift test と `scripts/dev/tests` は、保守者から実行完了の報告あり
- 2026-11-01: TAK-17（PR yoshidax/folzio-dev#15）のマージ後の master（f288320）を `git merge origin/master` で取り込んだ（テキストの競合なし）。
  ID を振り直した（FR-208〜212 → FR-215〜219、SC-102〜104 → SC-105〜107、EC-141〜143 → EC-146〜148、A-119〜125 → A-126〜132、US35〜37 → US36〜38）。
  ソースとテストは master にない行だけを置き換え、TAK-17 の ID を参照するコメントは変えていない
- 2026-11-01: TAK-17 との相互作用を修正。複数を対象にする右クリックメニューの先頭に「新規フォルダ」を加え（`TreeBatchTargets.contextMenu`）、
  複数を対象にするときは右クリックの「新規フォルダ」を無効にした。⇧⌘N・「ファイル > 新規フォルダ」は単一選択でだけ有効（保守者の決定、spec の Clarifications）。
  この変更の CI と GUI（S9 の ⇧⌘N と、TAK-17 の quickstart の手順 1・4・6）は未確認
- 2026-11-01: T024 の `specs/product/` への反映を保守者が承認。directory-tree.md・file-operations.md・contracts/keyboard-and-menus.md・README.md に反映し、spec.md に移行済み・凍結の注記を入れた。反映後に ID の重複がないことを確かめた
