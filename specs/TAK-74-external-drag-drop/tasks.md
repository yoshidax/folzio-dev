# Tasks: TAK-74 他のアプリとのドラッグ&ドロップ

**Input**: `specs/TAK-74-external-drag-drop/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/external-drag-drop.md / quickstart.md

**Tests**: Core の判断（操作の決定）と、App のマスク・file URL の判定・受け取った印に自動テストを付ける。GUI は保守者がローカルで確認する。
実装は保守者の設計承認の後に行う。

**注意**: `scripts/check-no-network.sh` は `Sources` の中の `http`・`https://` の文字列を、コメントを含めて拒否する。URL の例は `Tests` にだけ書く。

## Phase 1: Setup

- [x] T001 `specs/TAK-74-external-drag-drop/spec.md` と `checklists/requirements.md` を作り、TAK-74 と保守者の決定（Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/external-drag-drop.md`・`quickstart.md` に設計と検証方法を記録する
- [ ] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: Foundational（全ストーリーの前提）

- [ ] T004 `Tests/FolzioCoreTests/ExternalDropPolicyTests.swift` を作り、data-model.md の表のすべての組み合わせ（option・command・allOnSameVolume。Option と ⌘ の同時はコピー）と、
  優先する操作が許可されないときの切り替え・`nil`（EC-238）をテストする（FR-346）。`allOnSameVolume` は、一時フォルダの中の項目で true、
  存在しない項目を含むときに false（値が取れなければ false。EC-237）をテストする（先に失敗させる）
- [ ] T005 `Sources/FolzioCore/Operations/ExternalDropPolicy.swift` を実装して T004 を通す（FR-346・EC-237・EC-238、R3・R4）。
  `operation(option:command:allOnSameVolume:allowsMove:allowsCopy:) -> Operation?` と `allOnSameVolume(_:destination:) -> Bool`
  （`URLResourceValues.volumeIdentifier` を比べる。UI スレッドで呼ばない旨をコメントに書く）
- [ ] T006 `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の `internalDrop(_:to:copy:)` を `drop(_:to:copy:)` に改名し、
  `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` と `Sources/FolzioApp/FileList/FileListViewController.swift` の呼び出しを直す（FR-347、R5。動作は変えない）

## Phase 3: User Story 75 - Folzio の項目を他のアプリへ渡す (P1)

**Goal**: ツリー・リスト形式・サムネイル形式から、Finder・ブラウザ・Dock のゴミ箱へドラッグして移動・コピー・アップロード・ゴミ箱を行える

**Independent Test**: quickstart.md の「Folzio からアプリ外へ」

- [ ] T007 [US75] `DirectoryTreeViewController.swift`（1061 行付近）・`Sources/FolzioApp/FileList/ListModeView.swift`（263 行付近）・`Sources/FolzioApp/FileList/ThumbnailModeView.swift`（600 行付近）の
  `setDraggingSourceOperationMask(_:forLocal: false)` を `[.copy, .move, .generic, .delete]` にする（サムネイル形式は新しく設定する）。`forLocal: true` は変えない（FR-344、R2）。
  共通の値は `Sources/FolzioApp/Shared/ExternalDrag.swift` の定数にする
- [ ] T008 [US75] `Sources/FolzioApp/Shared/InternalDrag.swift` に、通し番号ごとの「Folzio のビューで受け取った」印（`markAccepted(_:)`・`wasAccepted(_:)`）を加え、
  ツリー・リスト形式・サムネイル形式のアプリ内の `acceptDrop` で印を残す。ツリーの `draggingSession(_:endedAt:operation:)`（1762 行付近）で、
  操作がない場合に加えて印がない場合（アプリ外へドロップした場合）も `pendingOperationSources` を消す。`.delete` で終わっても Folzio は何も削除せず、
  結果は FSEvents に任せる旨をコメントに書く（FR-219・EC-236、R2・R7）
- [ ] T009 [US75] `Tests/FolzioAppTests/ExternalDragTests.swift` を作り、3つのビューの `draggingSourceOperationMask(forLocal: false)` が T007 の値、`forLocal: true` が `[.copy, .move]`
  であることと、T008 の印が通し番号ごとに分かれることをテストする

## Phase 4: User Story 76 - Finder の項目を Folzio のフォルダへ受け取る (P1)

**Goal**: Finder の file URL を、FR-163 と同じ宛先へ、Finder の規則で移動・コピーできる。file URL 以外は受け付けない

**Independent Test**: quickstart.md の「Finder から Folzio へ」と「file URL 以外のドラッグ」

- [ ] T010 [US76] `Sources/FolzioApp/Shared/ExternalDrag.swift` に、`urls(_:)`（`InternalDrag.urls(_:)` が nil で、ペーストボードに file URL があるときだけ返す。
  `.urlReadingFileURLsOnly`。FR-348、R6）と、ホバー中の `operation(_:destination:) -> NSDragOperation`・ドロップ時の `dropOperation(_:destination:)` を実装する。
  `InternalDropValidation.validate` と `ExternalDropPolicy.allOnSameVolume` を detached task で求め、通し番号・URL の配列・宛先・Option・⌘ ごとにキャッシュする
  （`InternalDrag.operation` と同じ方式、FR-345・FR-346、R4）。移動を返すときは、マスクに `.move` があれば `.move`、なければ `.generic`
- [ ] T011 [US76] `Tests/FolzioAppTests/ExternalDragTests.swift` に、名前付きの `NSPasteboard`（`NSPasteboard(name:)`、テストの後に `releaseGlobally()`）を使い、
  file URL だけ・file URL と画像データ・画像データだけ・file URL でない URL だけ・文字列だけの場合に、file URL の判定が正しいこと（file URL があるときだけ返す）をテストする
  （FR-348・US76-AS6）。判定はペーストボードを受け取る関数に分けてテストできるようにする。3つのビューの登録した型が `[.fileURL]` のままであることも確かめる（R6）
- [ ] T012 [US76] `DirectoryTreeViewController.swift` の `validateDrop`・`acceptDrop`（1777〜1857 行付近）のアプリ外の経路を `ExternalDrag` に置き換える。
  宛先はアプリ内と同じ判定（実在するフォルダ行・利用可能なお気に入り。FR-345）を共通の関数にして両方で使う。受け取りは `coordinator.drop(urls, to:, copy:)`（FR-347、R5）。
  不要になる `fileURLs(from:)` を消す
- [ ] T013 [US76] `ListModeView.swift`（684〜700 行付近）と `ThumbnailModeView.swift`（1043〜1065 行付近）の `validateDrop`・`acceptDrop` に、アプリ外の経路を加える
  （FR-345・FR-346）。宛先の判定（フォルダの行・アイコンだけ、zip の中を除く）はアプリ内と同じ。受け取りはアプリ内と同じ `onInternalDrop` の経路
  （`FileListViewController.swift` の 128〜135 行付近）を使い、名前を `onDrop` に変える
- [ ] T014 [US76] `Tests/FolzioCoreTests/InternalDropValidationTests.swift` に、アプリ外から受け取る場合と同じ入力（Folzio の表示と関係のない場所の項目を、表示中のフォルダへ移動・コピー、
  元の親への移動）のケースが既存のテストで足りるかを確かめ、足りなければ追加する（EC-16・EC-121、US76-AS5）

## Phase 5: Polish & Cross-Cutting

- [ ] T015 `docs/usage.ja.md`・`docs/usage.md` のドラッグ&ドロップの説明に、Finder・ブラウザ・ゴミ箱との受け渡し（移動・コピーの決まり方）を両方に同じ構成で追記する。
  `README.md`・`README.ja.md` の機能の概要（29 行・28 行付近）に、他のアプリとの受け渡しを同じ内容で加える（同じコミット）
- [ ] T016 Cloud で `scripts/dev/check-all.sh` を実行し、結果をこの tasks.md の Execution Notes に記録する
- [ ] T017 macOS CI で `swift build`・`swift test` を確認する（`workflow_dispatch`、または保守者の依頼で作った PR）。性能テストはログの末尾で件数を確かめる
- [ ] T018 [MANUAL] 保守者に、起動スモークと quickstart.md の手動の確認をローカルで実行してもらい、結果と未検証の点（research.md R2・R4・R6・R8）の答えを
  `checklists/validation.md` に記録する。期待と違う点があれば、仕様か設計を直してから進める
- [ ] T019 検証の完了後に最新の master を取り込み、spec.md の「反映先」の項目を `specs/product/file-operations.md`・`directory-tree.md` へ反映する。
  反映の前と後に `scripts/dev/check-spec-ids.sh`、反映後に `python3 scripts/dev/check-spec-format.py` を実行する。ID が衝突すればこの feature の ID を振り直す。
  差分を保守者に示し、承認後にコミットして spec.md を凍結する

## Dependencies & Execution Order

T001 → T002 → T003（承認）→ T004 → T005 → T006 → US75（T007〜T009）→ US76（T010〜T014）→ T015〜T019

- US76 は T005（`ExternalDropPolicy`）と T006（`drop`）に依存する
- US75 と US76 は同じ3つのビューのファイルを編集するため直列にする

## Parallel Opportunities

Cloud ではタスクを分割して並列実装しない（AGENTS.md）。[P] は付けない。

## Implementation Strategy

承認 → Core のテストと実装（T004・T005）→ アプリ外へのドラッグ（US75）→ アプリ外からの file URL（US76）→ 静的検査・CI → 保守者の GUI 確認 → `specs/product/` への反映。
アプリ内のドラッグの規則が変わらないことを、既存のテストと GUI 確認（SC-184）で確かめる。

## Execution Notes

- 2026-11-07: Linear TAK-74 を In Progress に更新。作業ブランチ `claude/affectionate-carson-yaiayj`（origin/master c8840c8 を含む）
- 2026-11-07: 保守者の決定（spec の Clarifications）を記録し、spec・plan・tasks を作成
- 2026-11-07: speckit-analyze で、ブラウザの画像の取り込み（旧 US77）にキーボードの手段がない（憲章 原則 III、CRITICAL）ことが分かった。保守者の決定でこの feature から外し、
  別の Issue で扱う（A-204）。あわせて分析の MEDIUM・LOW の指摘（U1→T008・R7、U2→EC-236・R8、G1→quickstart、A1→FR-346、T1→各タスクの ID）を反映した。
  旧 US77 に関わる G2（打ち切りのテスト）・G3（用語対応表）は、範囲外になったため不要
