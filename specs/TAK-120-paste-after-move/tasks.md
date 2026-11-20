# Tasks: コピー元を移動した後もペーストできるようにする

**Input**: `specs/TAK-120-paste-after-move/` の spec.md・plan.md・research.md・data-model.md・quickstart.md

**Tests**: 憲章の原則 IV に従い、参照の作成と解決（`FolzioCore`）と、クリップボードの読み書き・ペーストに自動テストを付ける。

**方針の変更（2026-11-20）**: 当初の「移動の後にクリップボードを書き換える」設計（コミット 7474d21）は、実装の前に、
Finder と同じくファイルの参照を置く設計に置き換えた（spec.md の Clarifications、research.md R0）。

## Phase 0: 設計レビュー

- [X] T000 [MANUAL] 保守者が `specs/TAK-120-paste-after-move/spec.md`・`plan.md`・`tasks.md` と analyze の結果を確認し、実装開始を承認する（2026-11-20、このチャット。analyze の B1 は GUI の確認 8 で確かめる）

## Phase 1: Foundational（FolzioCore の参照）

**目的**: 項目の参照を作り、今の場所へ解決する

- [X] T001 `Sources/FolzioCore/Operations/ClipboardFileReferences.swift` を新規に作り、`ClipboardFileEntry`・`ClipboardFileResolution` と、`entries(for:)`（`CFURLCreateFileReferenceURL`、作れなければパス）・`resolve(_:)`（`CFURLCreateFilePathURL`、解決できなければ `.missing(name:)`）を置く（FR-413・FR-414、data-model.md、research.md R2・R4）
- [X] T002 [P] `Tests/FolzioCoreTests/ClipboardFileReferencesTests.swift` を新規に作り、作った文字列が `file:///.file/id=` で始まること、名前の変更・別のフォルダへの移動・フォルダの中の項目の移動の後に新しいパスへ解決されること、削除した項目が `.missing` になり名前が付くこと（US94-AS9）、存在しない項目はパスの file URL になること（EC-282）、パスの file URL はそのパスに解決されること（EC-285）、順序を保つことを確かめる

**Checkpoint**: `swift build` と `swift test --filter ClipboardFileReferencesTests` が通る（Cloud では CI）

## Phase 2: User Story 1 - 移動した後もコピーしたファイルをペーストする (Priority: P1) 🎯 MVP

**Goal**: Folzio のコピーで参照とファイル名を置き、ペーストで今の場所へ解決する

**Independent Test**: quickstart.md の GUI の確認 1〜9

- [X] T003 [US1] `Sources/FolzioApp/Shared/PasteboardFileURLs.swift` に、`ClipboardFileEntry` の並びを項目ごとの `NSPasteboardItem`（`.fileURL` と `.string`）として書く処理（版が渡された値と違えば書かない。EC-281）と、各項目の `.fileURL`・`.string` の文字列を読む処理を加える。既存の `fileURLs(in:)` はドラッグのために残す（research.md R3・R5）
- [X] T004 [US1] `Sources/FolzioApp/FileList/FileListViewController.swift` の `copy(_:)` と `Sources/FolzioApp/Tree/DirectoryTreeViewController.swift` の `copyFolders(_:to:)` を、対象と版を取ってから `Task.detached` で `ClipboardFileReferences.entries(for:)` を呼び、UI スレッドで T003 の書き込みをする形に変える（FR-413、research.md R3）
- [X] T005 [US1] `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の `paste(into:move:pasteboard:parentWindow:)` の file URL の場合を、T003 で項目を読み、`Task.detached` で `ClipboardFileReferences.resolve(_:)` を呼び、見つかった項目をコピー・移動し、`.missing` の項目をその失敗とまとめて示す形に変える（FR-414・EC-283、research.md R4）
- [X] T006 [US1] `Tests/FolzioAppTests/ExternalDragTests.swift` の `PasteboardFileURLsTests` に、一意の名前のクリップボードで、項目ごとに参照とファイル名が書かれること、版が変わっていれば書かないこと（EC-281）、書いた項目を `fileURLs(in:)` でも読めること（ドラッグと Finder の読み取り）を加える
- [X] T007 [US1] `Tests/FolzioAppTests/ClipboardPasteTests.swift` を新規に作り、一意の名前のクリップボードで、コピー → 移動ペースト → ペースト（US94-AS1）、コピー → 名前の変更 → ペースト（US94-AS2）、コピー → フォルダの移動 → ペースト（US94-AS3）、パスの file URL のペースト（EC-285）、削除した項目を含む複数の項目のペーストで、ほかの項目がペーストされること（EC-283）、ペーストの後もクリップボードの中身が変わらないこと（SC-236）を確かめる
- [X] T008 [P] [US1] `docs/usage.md` と `docs/usage.ja.md` のコピー・ペーストの説明に、Finder と同じく、コピーした後に移動・名前の変更・ゴミ箱に入れた項目もペーストできること（別のボリュームへ移動・削除した項目は除く）を同じ内容で追記する

**Checkpoint**: `swift build` と `swift test` が通る（Cloud では CI）

## Phase 3: Polish & Verification

- [X] T009 `scripts/dev/check-all.sh` を実行し、push 後の CI（`swift build`・`swift test`）の結果を `specs/TAK-120-paste-after-move/quickstart.md` に記録する
- [X] T010 [MANUAL] 保守者が古い Folzio を終了して `scripts/make-app.sh` の後に `open .build/Folzio.app` で起動し、3ペインの表示と `specs/TAK-120-paste-after-move/quickstart.md` の GUI の確認 1〜9（ゴミ箱、Finder・テキストエディタとの受け渡し、別のボリュームを含む）を行う（2026-11-20、保守者の報告「期待通り」。checklists/validation.md）
- [ ] T011 `specs/product/file-operations.md` へ spec.md の「反映先」の項目を反映し、spec.md に移行済み・凍結の注記を入れ、`python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行する
- [ ] T012 [MANUAL] 保守者が `specs/product/` への反映の差分を確認し、承認する

## Dependencies & Execution Order

- T000 の承認の後に Phase 1 を始める
- T001 の後に T002・T003。T003 の後に T004・T005。T003 の後に T006。T004・T005 の後に T007
- T008 はいつでも書ける
- T009 は T007 の後。T010 は T009 の後。T011 は T010 の後（反映の直前に `origin/master` を取り込む）

## Implementation Strategy

- 1つの User Story だけなので、Phase 1〜2 をまとめて実装し、CI と GUI の確認を経て反映する
- Cloud では並列の実装をしない（docs_private/cloud-agent-workflow.md の 7 章）
