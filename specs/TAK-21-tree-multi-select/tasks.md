# Tasks: TAK-21 ツリーでのフォルダの複数選択と一括操作

**Input**: `specs/TAK-21-tree-multi-select/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/tree-selection.md / quickstart.md

**Tests**: Core の判断（対象・可否・重なり）に自動テストを付ける。GUI は保守者がローカルで確認する。実装は保守者の設計承認の後に行う。

## Phase 1: Setup

- [x] T001 `specs/TAK-21-tree-multi-select/spec.md` と `checklists/requirements.md` を作り、TAK-21 と現行仕様の変更点を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/tree-selection.md`・`quickstart.md` に設計と検証方法を記録する
- [x] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: Foundational（全ストーリーの前提）

- [x] T004 `Tests/FolzioCoreTests/TreeBatchTargetsTests.swift` を作り、FR-210 の対象の決定（キーボード／選択中の行の右クリック・ドラッグ／選択外の行）、FR-211 の可否
  （通常のフォルダだけ／ホーム・ボリュームの最上位・お気に入り・見出しを含む／1件と複数）、EC-141 の親子の重なり（直接の子・孫・兄弟・同名の前方一致 `A` と `AB`）、
  1件のときに `FavoriteCommands` の `trashTarget`・`removalTarget`・`renameTarget` と一致することをテストする（先に失敗させる）
- [x] T005 `Sources/FolzioCore/Model/TreeBatchTargets.swift` を実装して T004 を通す（data-model.md、R1・R2）。ディスクを読まない
- [x] T006 `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` に、選択中の行の role の配列と、メニュー・ドラッグを始めた行から `TreeBatchTargets` を作る補助を加え、
  `selectedItem` を使う判断を置き換える準備をする（R7）。この時点では `allowsMultipleSelection` を変えない

## Phase 3: User Story 37 - 複数選択中の表示とメニュー (P2、P1 の前提)

**Goal**: 複数選択でき、主の行のフォルダを表示し、単一の対象を前提とする操作を誤って実行しない

**Independent Test**: quickstart の S2・S3・S7・S9

- [x] T007 [US37] `DirectoryTreeViewController.swift` の `DragAwareOutlineView` に主の行とアンカー（item で保持）を加え、⌘クリック・Shift クリック（`mouseDown`）と
  ↑↓・Shift+↑↓（`keyDown`）を自前で処理する。Control クリック・開閉の三角・修飾キーなしのクリックは `super` に任せる。`allowsMultipleSelection = true` にする
  （FR-208、R4、A-125、data-model.md の TreeSelectionLead）
- [x] T008 [US37] `outlineViewSelectionDidChange` と `trackingEnded` を、主の行が変わったときだけ `model.selectFolder` を呼ぶように変える。⌘クリックで外したときは表示を変えない。
  `syncSelection` で1行を選択したときはアンカーと主の行をその行にする。検索結果の表示中に複数選択の中の行を通常のクリックで選んだときは `clickedRow` と同じく検索結果の表示を終える
  （FR-209・FR-086、R4）
- [x] T009 [US37] `validateMenuItem`・`menuNeedsUpdate`・`rename(_:)`・`paste(_:)`・`movePaste(_:)`・`copyPathname(_:)`・`revealInFinder(_:)`・`addToFavorites(_:)`・
  `removeFavoriteFromMenu(_:)` を `TreeBatchTargets` の `isSingle` に従わせる。`Sources/FolzioApp/App/MainSplitViewController.swift` の `canAddSelectedFolderToFavorites` も複数選択で false にする
  （FR-211（2）（3）・FR-183、R7）。複数を対象にする右クリックメニューは、対象の種類に関わらず通常のフォルダの項目を出す（FR-211（3））
- [x] T010 [US37] ツリーの `selectAll(_:)` を無効にする（A-119、R8）。2行以上の選択で、`outlineViewItemWillCollapse` で隠れる行の選択を外し、`outlineViewItemDidCollapse` で
  結果を検査して戻す。隠れた主の行からのキーボードの移動は見える祖先の行を起点にする。1行の選択の折りたたみは変えない（EC-143・A-124、R9）
- [x] T011 [US37] 名前の編集中に ⌘クリック・Shift クリックで選択を変えたとき、編集を確定することを確かめ、必要なら `finishEditing` を呼ぶ（FR-103・FR-102）

## Phase 4: User Story 35 - 複数のフォルダをまとめて移動・コピーする (P1)

**Goal**: 複数選択からのドラッグで、まとめて移動・コピーする

**Independent Test**: quickstart の S4・S5

- [x] T012 [US35] `DragAwareOutlineView` で `canDragRows(with:at:)` を override し、`rowIndexes` の行の role から作った `TreeBatchTargets.dragURLs` が nil、または対象と
  `rowIndexes` が一致しないときは false を返す（FR-211（1）・FR-162、R5）。`pasteboardWriterForItem` は従来どおり通常のフォルダだけに URL を返す
- [x] T013 [US35] ドラッグ後の選択の復元を、ドラッグ前の選択全体と主の行に広げる。選択外の行からドラッグを中止したとき、ファイルリストの表示が変わらないことを確かめる（FR-210（3）・US35-AS2、R5）
- [x] T014 [US35] ツリーからの移動の完了で、1件以上が成功したらツリーを主の行の単一選択にする。表示中のフォルダが切り替わった場合は同期に任せる。主の行が折りたたみで隠れていれば祖先を展開してから選択する（FR-212、R6）。`Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の
  `internalDrop` からツリーへの通知を加える。コピー・キャンセル・すべて失敗では選択を変えない
- [x] T015 [US35] 宛先の検証が複数のツリーのフォルダで `InternalDropValidation`（EC-16・EC-121）に従うことを `Tests/FolzioCoreTests/InternalDropValidationTests.swift` で確かめ、
  足りないケース（異なる親の複数フォルダ・親と子の同時選択・宛先が選択の1つの配下）を追加する

## Phase 5: User Story 36 - 複数のフォルダをまとめてゴミ箱に入れる (P1)

**Goal**: ⌘⌫ と「ゴミ箱に入れる」で、まとめてゴミ箱に入れる

**Independent Test**: quickstart の S6・S8・S10

- [x] T016 [US36] `moveToTrash(_:)` と `trashFolderFromMenu(_:)` を `TreeBatchTargets.trashURLs` に従わせる。`.overlapping` はエラーを表示して何もしない（EC-141）。
  `.unavailable` は何もしない。お気に入り1件の ⌘⌫ は従来どおり（FR-064）。複数の選択では、メニューの ⌘⌫ の項目の名前を「ゴミ箱に入れる」にする（現行は単一のお気に入りで「お気に入りから削除」に切り替えている）。一部の失敗・外部で消えた項目は既存の `presentFailures` で成功と区別して示す（EC-142）
- [x] T017 [US36] `Sources/FolzioLocalization/TextKey.swift` と `Resources/{ja,en}.lproj/Localizable.strings` に、EC-141 のエラーの見出し・説明と、複数の場所の行の文言を追加する。
  既存の `Tests/FolzioCoreTests/Localization/CatalogConsistencyTests.swift` が通ること
- [x] T018 [US36] `FileOperationCoordinator.trash(_:origin:)` と `Sources/FolzioApp/Operations/ConfirmationPresenter.swift` で、ツリーからの複数のゴミ箱の確認モーダルに
  各フォルダの名前と絶対パス（先頭5件と残りの件数）を示す。1件のときの表示は変えない（FR-079（変更）、A-120、R3）
- [x] T019 [US36] ゴミ箱の完了で FR-212 の選択の更新を行う（T014 と同じ経路）。表示中のフォルダまたは祖先を含む場合は既存の `leaveTrashedFolders` の同期に任せる（FR-079、R6）

## Phase 6: Polish & Cross-Cutting

- [x] T020 Cloud で `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`、
  `python3 -I -m unittest discover -s scripts/dev/tests -p "test_check_git_push.py"` を実行し、結果をこの tasks.md に記録する
- [ ] T021 macOS CI で `swift build`・`swift test` を確認する（PR の作成時、または `workflow_dispatch`）。PR は保守者の依頼があったときだけ作る
- [ ] T022 [MANUAL] 保守者に、起動スモークと quickstart の S1〜S14 をローカルで実行してもらい（SC-102〜SC-104 の確認を含む）、結果を `checklists/validation.md` に記録する。S3・S5・S7 は R4・R5・R9 の設計どおりに動くことを確かめる
- [x] T023 ユーザーガイド `docs/usage.ja.md`・`docs/usage.md` のツリーの操作の説明（お気に入り・⌘Delete の項）に、複数選択（⌘クリック・Shift クリック・Shift+↑↓）と
  一括の移動・コピー・ゴミ箱を両方に同じ構成で追記する。README は機能の概要だけで個別の操作を書いていないため変えない（`README.ja.md` 20〜21 行）
- [ ] T024 検証の完了後に最新の master を取り込み、spec.md の「反映先」の項目を `specs/product/` と `specs/product/contracts/keyboard-and-menus.md` へ反映する。
  ID の衝突を確認し、衝突すればこの feature の ID を振り直す。差分を保守者に示し、承認後にコミットして spec.md を凍結する

## Dependencies & Execution Order

T001 → T002 → T003（承認）→ T004 → T005 → T006 → US37（T007〜T011）→ US35（T012〜T015）→ US36（T016〜T019）→ T020〜T024

US37 は複数選択そのものを有効にするため、P2 だが US35・US36 の前に行う。US35 と US36 は同じ `DirectoryTreeViewController.swift` と `FileOperationCoordinator.swift` を編集するため直列にする。
T014 と T019 は同じ選択の更新の経路を共有する。

## Parallel Opportunities

Cloud ではタスクを分割して並列実装しない（AGENTS.md）。[P] は付けない。

## Implementation Strategy

承認 → Core のテストと実装（T004・T005）→ 複数選択と無効化（US37）→ 移動・コピー（US35）→ ゴミ箱（US36）→ 静的検査・CI → 保守者の GUI 確認 → `specs/product/` への反映。
単一選択の振る舞い（既存の FR-079・FR-103・FR-064・FR-182）が変わらないことを、既存のテストと GUI 確認で確かめる。

## Execution Notes

- 2026-10-31: Linear TAK-21 を In Progress に更新。作業ブランチ `claude/youthful-brahmagupta-ocjb0d`（origin/master bc97861 を含む）
- 2026-10-31: 設計レビュー承認（3回の analyze と修正、R4・R5・R9 の設計変更を含む）。T004〜T019・T023 を実装。Cloud に Swift がないため、
  コンパイルとテスト（T004 の先に失敗させる確認を含む）は未実行で、T021 の CI で確認する
- 2026-10-31: T020 の Cloud の検査結果: `check-no-network.sh` 成功、`check-readme-sync.sh master` 成功、`check-english-comments.sh` 成功、
  `check-skill-sync.sh` 成功、`test_check_git_push.py` 3件成功
- 2026-10-31: 報告した懸念1を修正。⌘クリックで主の行を外した後の ↑↓ が、残った行ではなく主の行を起点にするようにした（`handleArrowKey`。spec の Edge Cases・contracts・quickstart S3 に追記）
- 2026-10-31: T023 で `docs/usage*.md` のツリーのゴミ箱の行にあった「設定で省略可」を、FR-079・FR-024 の「常に確認」に合わせて直した（既存の記述の誤り）
