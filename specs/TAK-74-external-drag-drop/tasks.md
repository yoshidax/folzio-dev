# Tasks: TAK-74 他のアプリとのドラッグ&ドロップ

**Input**: `specs/TAK-74-external-drag-drop/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/external-drag-drop.md / quickstart.md

**Tests**: Core の判断（操作の決定・ファイル名）と、App の型の登録・マスク・データの判定・画像の保存に自動テストを付ける。GUI は保守者がローカルで確認する。
実装は保守者の設計承認の後に行う。

**注意**: `scripts/check-no-network.sh` は `Sources` の中の `http`・`https://` の文字列を、コメントを含めて拒否する。URL の例は `Tests` にだけ書く。

## Phase 1: Setup

- [x] T001 `specs/TAK-74-external-drag-drop/spec.md` と `checklists/requirements.md` を作り、TAK-74 と保守者の決定（Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/external-drag-drop.md`・`quickstart.md` に設計と検証方法を記録する
- [ ] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: Foundational（全ストーリーの前提）

- [ ] T004 `Tests/FolzioCoreTests/ExternalDropPolicyTests.swift` を作り、data-model.md の表のすべての組み合わせ（option・command・allOnSameVolume）と、
  優先する操作が許可されないときの切り替え・`nil`（EC-238）をテストする。`allOnSameVolume` は、一時フォルダの中の項目で true、
  存在しない項目を含むときに false（値が取れなければ false）をテストする（先に失敗させる）
- [ ] T005 `Sources/FolzioCore/Operations/ExternalDropPolicy.swift` を実装して T004 を通す（R3・R4）。`operation(option:command:allOnSameVolume:allowsMove:allowsCopy:) -> Operation?` と
  `allOnSameVolume(_:destination:) -> Bool`（`URLResourceValues.volumeIdentifier` を比べる。UI スレッドで呼ばない旨をコメントに書く）
- [ ] T006 `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の `internalDrop(_:to:copy:)` を `drop(_:to:copy:)` に改名し、
  `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` と `Sources/FolzioApp/FileList/FileListViewController.swift` の呼び出しを直す（R5。動作は変えない）

## Phase 3: User Story 75 - Folzio の項目を他のアプリへ渡す (P1)

**Goal**: ツリー・リスト形式・サムネイル形式から、Finder とブラウザへドラッグして移動・コピー・アップロードできる

**Independent Test**: quickstart.md の「Folzio からアプリ外へ」

- [ ] T007 [US75] `DirectoryTreeViewController.swift`（1061 行付近）・`Sources/FolzioApp/FileList/ListModeView.swift`（263 行付近）・`Sources/FolzioApp/FileList/ThumbnailModeView.swift`（600 行付近）の
  `setDraggingSourceOperationMask(_:forLocal: false)` を `[.copy, .move, .generic, .delete]` にする（サムネイル形式は新しく設定する）。`forLocal: true` は変えない（FR-344、R2）。
  共通の値は `Sources/FolzioApp/Shared/ExternalDrag.swift` の定数にする
- [ ] T008 [US75] `Tests/FolzioAppTests/ExternalDragTests.swift` を作り、3つのビューの `draggingSourceOperationMask(forLocal: false)` が T007 の値、`forLocal: true` が `[.copy, .move]` であることをテストする
- [ ] T009 [US75] ツリーの `draggingSession(_:endedAt:operation:)` で、`.delete` で終わっても Folzio が何も削除しないことをコメントで明記し、既存の `pendingOperationSources` の消去を
  ドロップ先がアプリ外の場合にも行う（アプリ外への移動は coordinator を通らないため、FR-219 の記録が残らないようにする）。結果は FSEvents（EC-236）に任せる

## Phase 4: User Story 76 - Finder の項目を Folzio のフォルダへ受け取る (P1)

**Goal**: Finder の file URL を、FR-163 と同じ宛先へ、Finder の規則で移動・コピーできる

**Independent Test**: quickstart.md の「Finder から Folzio へ」

- [ ] T010 [US76] `Sources/FolzioApp/Shared/ExternalDrag.swift` に、登録する型（`.fileURL`・`NSFilePromiseReceiver.readableDraggedTypes`・`.png`・`.tiff`）、
  `ExternalDragPayload` の種類の判定（`NSPasteboard` を受け取り、file URL → file promise → 画像データの順。どれもなければ nil。EC-241・R9）、
  ホバー中の操作の決定（`operation(_:destination:) -> NSDragOperation`）を実装する。
  `InternalDrag.urls(_:)` が nil のときだけ使う。file URL のときは、`InternalDropValidation.validate` と `ExternalDropPolicy.allOnSameVolume` を detached task で求め、
  `draggingSequenceNumber`・URL・宛先・修飾キーごとにキャッシュする（`InternalDrag.operation` と同じ方式、R4）。移動を返すときは、マスクに `.move` があれば `.move`、なければ `.generic`
- [ ] T011 [US76] `Tests/FolzioAppTests/ExternalDragTests.swift` に、名前付きの `NSPasteboard`（`NSPasteboard(name:)`、テストの後に `releaseGlobally()`）で、file URL だけ・file URL と画像データ・
  画像データと URL・URL だけ・文字列だけの種類の判定をテストする（EC-241、US77-AS3）
- [ ] T012 [US76] 3つのビューの `registerForDraggedTypes` を T010 の型の一覧にする（R9）。既存の `Tests/FolzioAppTests/ThumbnailDropTargetTests.swift`（サムネイルの画像のビューが登録を持たない）が通ること。
  T008 のテストに、3つのビューの登録した型を加える
- [ ] T013 [US76] `DirectoryTreeViewController.swift` の `validateDrop`・`acceptDrop`（1777〜1857 行付近）のアプリ外の経路を、`ExternalDrag` に置き換える。
  宛先はアプリ内と同じ判定（実在するフォルダ行・利用可能なお気に入り。FR-345）を共通の関数にして両方で使う。file URL の受け取りは
  `coordinator.drop(urls, to:, copy:)`（R5）。ドロップ時の操作は、ホバー中と同じく `ExternalDropPolicy` で決め直す。不要になる `fileURLs(from:)` を消す
- [ ] T014 [US76] `ListModeView.swift`（684〜700 行付近）と `ThumbnailModeView.swift`（1043〜1065 行付近）の `validateDrop`・`acceptDrop` に、アプリ外の経路を加える。
  宛先の判定（フォルダの行・アイコンだけ、zip の中を除く）はアプリ内と同じ。`onExternalDrop`（`ExternalDragPayload` と宛先を渡す）を加え、
  `FileListViewController.swift`（128〜135 行付近）で coordinator へつなぐ
- [ ] T015 [US76] `Tests/FolzioCoreTests/InternalDropValidationTests.swift` に、アプリ外から受け取る場合と同じ入力（Folzio の表示と関係のない場所の項目を、表示中のフォルダへ移動・コピー、
  元の親への移動）のケースが既存のテストで足りるかを確かめ、足りなければ追加する（EC-16・EC-121、US76-AS5）

## Phase 5: User Story 77 - Web ブラウザの画像を Folzio のフォルダへ保存する (P2)

**Goal**: ブラウザの画像を、file promise または画像データから、ファイルとして宛先へ保存できる

**Independent Test**: quickstart.md の「ブラウザの画像を Folzio へ」

- [ ] T016 [P] [US77] `Tests/FolzioCoreTests/ImportedImageNameTests.swift` を作り、FR-350 の規則をテストする: 拡張子の置き換え（`cat.jpg` → `cat.png`）、クエリ付きの URL、
  パーセントエンコード（`%E7%8C%AB.jpg` → `猫.png`）、拡張子のない名前、末尾が `/` の URL、`data:` の URL、`.` で始まる名前、URL がない場合の
  「<接頭辞> yyyy-MM-dd HH.mm.ss.png」（タイムゾーンを固定して日時の書式を確かめる）（先に失敗させる）
- [ ] T017 [US77] `Sources/FolzioCore/Operations/ImportedImageName.swift` を実装して T016 を通す（R8）。名前の検証は `validateNewName`（`Sources/FolzioCore/Operations/NameValidation.swift`）を使う
- [ ] T018 [US77] `Sources/FolzioCore/Operations/OperationFailureReason.swift` に `importTimedOut` を追加し、`Sources/FolzioLocalization/TextKey.swift` と
  `Resources/{ja,en}.lproj/Localizable.strings` に、その理由の文言と画像の既定の接頭辞（「画像」/`Image`）を追加する。
  既存の `Tests/FolzioCoreTests/Localization/` のテストが通ること（R11）
- [ ] T019 [US77] `Sources/FolzioApp/Operations/ExternalImport.swift` を作る（`ImportSession`、data-model.md、R6・R7）。
  一時フォルダは `FileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: 宛先, create: true)` を detached task で作る。
  file promise は `receivePromisedFiles(atDestination:options:operationQueue:reader:)` を専用の `OperationQueue` で受け、約束ごとに URL か Error を集め、60 秒で残りを `importTimedOut` にする。
  画像データは ImageIO で PNG にして（既に PNG ならそのまま）、`ImportedImageName` の名前で一時フォルダに書く。どの結果でも最後に一時フォルダを消す
- [ ] T020 [US77] `FileOperationCoordinator.swift` に、書き出したファイルを宛先へコピーする入口（例: `importFiles(_:failures:to:)`）を加える。
  既存の `transfer` の確認・衝突・失敗の経路を使い、書き出しの失敗を同じ結果の表示にまとめ（EC-240）、書き出しが1件も成功しなければ確認を出さずに失敗だけを示す。
  一時フォルダは `notifyFoldersChanged` の対象から外す（R10）
- [ ] T021 [US77] 3つのビューの `acceptDrop` で、`ExternalDragPayload` の `filePromises`・`imageData` を、ペーストボードからその場で読み出して（R6）`ExternalImport` に渡す。
  ホバー中は `.copy`（マスクに `.copy` がなければ受け付けない）を返す（FR-345・FR-348・FR-349）
- [ ] T022 [US77] `Tests/FolzioAppTests/ExternalDragTests.swift` に、画像データ（テストで作った小さな TIFF と PNG）から PNG のファイルが一時フォルダに書かれ、
  `ImportSession` の終了後に一時フォルダが残らないことをテストする（FR-349・SC-183）

## Phase 6: Polish & Cross-Cutting

- [ ] T023 `docs/usage.ja.md`・`docs/usage.md` のドラッグ&ドロップの説明に、Finder・ブラウザとの受け渡し（移動・コピーの決まり方、画像の保存、ゴミ箱）を両方に同じ構成で追記する。
  `README.md`・`README.ja.md` の機能の概要（29 行・28 行付近）に、他のアプリとの受け渡しを同じ内容で加える（同じコミット）
- [ ] T024 Cloud で `scripts/dev/check-all.sh` を実行し、結果をこの tasks.md の Execution Notes に記録する
- [ ] T025 macOS CI で `swift build`・`swift test` を確認する（`workflow_dispatch`、または保守者の依頼で作った PR）。性能テストはログの末尾で件数を確かめる
- [ ] T026 [MANUAL] 保守者に、起動スモークと quickstart.md の手動の確認をローカルで実行してもらい、結果と未検証の点（research.md R2・R6・R7・R9）の答えを
  `checklists/validation.md` に記録する。期待と違う点があれば、仕様か設計を直してから進める
- [ ] T027 検証の完了後に最新の master を取り込み、spec.md の「反映先」の項目を `specs/product/file-operations.md`・`directory-tree.md` へ反映する。
  反映の前と後に `scripts/dev/check-spec-ids.sh`、反映後に `python3 scripts/dev/check-spec-format.py` を実行する。ID が衝突すればこの feature の ID を振り直す。
  差分を保守者に示し、承認後にコミットして spec.md を凍結する

## Dependencies & Execution Order

T001 → T002 → T003（承認）→ T004 → T005 → T006 → US75（T007〜T009）→ US76（T010〜T015）→ US77（T016〜T022）→ T023〜T027

- US76 は T005（`ExternalDropPolicy`）と T006（`drop`）に依存する
- US77 は US76 の `ExternalDrag`（T010）と3つのビューのアプリ外の経路（T013・T014）に依存する
- US75 と US76 は同じ3つのビューのファイルを編集するため直列にする

## Parallel Opportunities

Cloud ではタスクを分割して並列実装しない（AGENTS.md）。[P] は、T016 が Core の新しいファイルだけを扱い、ほかのタスクと独立していることを示すだけにする。

## Implementation Strategy

承認 → Core のテストと実装（T004・T005）→ アプリ外へのドラッグ（US75、MVP の1つ目）→ アプリ外からの file URL（US76、MVP の2つ目）→ 画像の保存（US77）→
静的検査・CI → 保守者の GUI 確認 → `specs/product/` への反映。アプリ内のドラッグの規則が変わらないことを、既存のテストと GUI 確認（SC-185）で確かめる。

## Execution Notes

- 2026-11-07: Linear TAK-74 を In Progress に更新。作業ブランチ `claude/affectionate-carson-yaiayj`（origin/master c8840c8 を含む）
- 2026-11-07: 保守者の決定（spec の Clarifications の6件）を記録し、spec・plan・tasks を作成
