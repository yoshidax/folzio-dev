# Tasks: コピー元を移動した後もペーストできるようにする

**Input**: `specs/TAK-120-paste-after-move/` の spec.md・plan.md・research.md・data-model.md・quickstart.md

**Tests**: 憲章の原則 IV に従い、付け替えと版の判断（`FolzioCore`）と、移動・名前の変更・ペーストからの書き換えに自動テストを付ける。

## Phase 0: 設計レビュー

- [ ] T000 [MANUAL] 保守者が `specs/TAK-120-paste-after-move/spec.md`・`plan.md`・`tasks.md` と analyze の結果を確認し、実装開始を承認する

## Phase 1: Foundational（FolzioCore の判断）

**目的**: 覚えたファイルの並びを、移動の対応と版から付け替える純粋な型を作る

- [ ] T001 `Sources/FolzioCore/Model/ClipboardFileRecord.swift` を新規に作り、`changeCount` と `urls` を持ち、`relocated(by:currentChangeCount:)` で、版が違えば nil、変わる URL がなければ nil、それ以外は `RenamedFolder.rebaseOrSelf` を順に適用した並びを返す（FR-413・FR-414、data-model.md、research.md R1・R3）
- [ ] T002 [P] `Tests/FolzioCoreTests/ClipboardFileRecordTests.swift` を新規に作り、項目そのもの・子孫（EC-286）・名前の前方が一致する兄弟（付け替えない）・関係のない項目と順序（US94-AS5）・版の違い（US94-AS6）・変わる URL がない場合・複数の対応の順の適用（EC-283 の別名を含む）を確かめる

**Checkpoint**: `swift build` と `swift test --filter ClipboardFileRecordTests` が通る（Cloud では CI）

## Phase 2: User Story 1 - 移動した後もコピーしたファイルをペーストする (Priority: P1) 🎯 MVP

**Goal**: Folzio の移動・名前の変更の後、クリップボードを移動後の場所へ書き換える

**Independent Test**: quickstart.md の GUI の確認 1〜10

- [ ] T003 [US1] `Sources/FolzioApp/Shared/PasteboardFileURLs.swift` に、クリップボードの名前ごとの `ClipboardFileRecord` の記録を置く。`write(_:to:)` は書いた後の版で記録し、`remember(_:in:)`（ペーストで読んだ並びを記録）と `relocate(by:in:)`（版だけを読み、付け替えた並びがあれば `write` で書き直す）を加える（FR-414、research.md R1・R4・R5）
- [ ] T004 [US1] `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` の `transferItems` が、移動に成功した項目ごとの `RenamedFolder`（元の場所と `succeeded` の最初の URL）を返すようにし、`transfer` と `transferReceived` と `Tests/FolzioAppTests/FileTransferCancellationTests.swift` を追従させる（research.md R2。EC-281・EC-283・EC-284）
- [ ] T005 [US1] `Sources/FolzioApp/Operations/FileOperationCoordinator.swift` に書き換える先のクリップボード（既定 `.general`）の property を置き、`paste(into:move:pasteboard:parentWindow:)` で読んだ file URL を `remember` する。`transfer` の `.move` の後と `rename` の成功の後に `relocate` を呼ぶ。ゴミ箱に入れる・複製・コピー・フォルダの新規作成・画像の受け取りでは呼ばない（FR-413）
- [ ] T006 [US1] `Tests/FolzioAppTests/ClipboardRelocationTests.swift` を新規に作り、一意の名前のクリップボードで、Folzio のコピー → 移動ペースト → 書き換え（US94-AS1）、別のアプリが置いた file URL のペースト → 移動ペースト（US94-AS2）、名前の変更（US94-AS3）、フォルダのドロップによる移動と子孫（US94-AS4）、一部だけの移動（US94-AS5）、版が変わった後は書き換えないこと（US94-AS6）、ゴミ箱に入れても書き換えないこと（US94-AS7）、記録のないクリップボードは書き換えないこと（US94-AS8）、衝突の中止と「両方残す」（EC-281・EC-283）、続けた移動ペースト（EC-285）を確かめる（SC-235・SC-236）
- [ ] T007 [P] [US1] `docs/usage.md` と `docs/usage.ja.md` のコピー・ペーストの説明に、Folzio で移動・名前の変更をした後も続けてペーストできること（Folzio の外での移動と、ゴミ箱に入れた項目は対象外）を同じ内容で追記する

**Checkpoint**: `swift build` と `swift test` が通る（Cloud では CI）

## Phase 3: Polish & Verification

- [ ] T008 `scripts/dev/check-all.sh` を実行し、push 後の CI（`swift build`・`swift test`）の結果を `specs/TAK-120-paste-after-move/quickstart.md` に記録する
- [ ] T009 [MANUAL] 保守者が古い Folzio を終了して `scripts/make-app.sh` の後に `open .build/Folzio.app` で起動し、3ペインの表示と `specs/TAK-120-paste-after-move/quickstart.md` の GUI の確認 1〜10（Finder でのペーストの SC-237 を含む）を行う
- [ ] T010 `specs/product/file-operations.md` へ spec.md の「反映先」の項目を反映し、spec.md に移行済み・凍結の注記を入れ、`python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行する
- [ ] T011 [MANUAL] 保守者が `specs/product/` への反映の差分を確認し、承認する

## Dependencies & Execution Order

- T000 の承認の後に Phase 1 を始める
- T001 の後に T002・T003。T003・T004 の後に T005。T005 の後に T006
- T007 はいつでも書ける
- T008 は T006 の後。T009 は T008 の後。T010 は T009 の後（反映の直前に `origin/master` を取り込む）

## Implementation Strategy

- 1つの User Story だけなので、Phase 1〜2 をまとめて実装し、CI と GUI の確認を経て反映する
- Cloud では並列の実装をしない（docs_private/cloud-agent-workflow.md の 7 章）
