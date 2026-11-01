# Tasks: 設定ウインドウのセクション間隔の統一と確認オプションの補足説明の分離

**Input**: `specs/TAK-20-settings-section-spacing/` の spec.md、plan.md、research.md、data-model.md、contracts/、quickstart.md

**Prerequisites**: 設計レビューの承認前には実装しない（`docs_private/cloud-agent-workflow.md`）

**Tests**: 翻訳の値の回帰テストを追加する。見た目は quickstart.md の GUI 確認で保守者が確かめる

**Organization**: US1=US39、US2=US40。Cloud は Issue 単位のため全タスクを順次実行する。[P] は使わない

## Phase 1: Setup

- [x] T001 設計レビューの承認を受け、承認の日付と範囲を `specs/TAK-20-settings-section-spacing/quickstart.md` の「結果の記録」へ書く。research.md の「API の存在の確認」の API を Apple の文書で確かめる

## Phase 2: Foundational（翻訳の単位）

- [x] T002 `Tests/FolzioCoreTests/Localization/SettingsTextTests.swift` を追加し、`settings.confirm` と `settings.confirm.note` の日本語・英語の値が data-model.md の表と一致すること、主文に括弧（`（` `(`）を含まないことを検証する（先に失敗することを確認できる形で書く。FR-223（1）（2）、SC-112）
- [x] T003 `Sources/FolzioLocalization/TextKey.swift` に `settingsConfirmNote = "settings.confirm.note"` と英語の説明を追加し、`Sources/FolzioLocalization/Resources/{ja,en}.lproj/Localizable.strings` の `settings.confirm` の値を主文だけにして、`settings.confirm.note` を追加する（data-model.md）

## Phase 3: US1 区分の間隔の統一 (P1)

**Goal**: 区分の前の間隔を揃え、「ファイル操作」の大きな空白をなくす

**Independent Test**: quickstart.md Q1・Q4

- [x] T004 [US1] `Sources/FolzioApp/Settings/SettingsWindowController.swift` で、確認のチェックボックスの最小の高さ 60pt の制約を削除し、区分の前に `setCustomSpacing(20, after:)` を設定する（言語の行・ループの後。スライドショーの前は T006 の補足説明の後）（FR-222（1）〜（3）、R1・R2）
- [x] T005 [US1] 同じファイルで、ウインドウの高さの下限 320pt を外し、`resizeToFitContent()` で上端を保って `fittingSize.height` に合わせる。初期化時と `updateLocalizedLabels()` の最後で呼ぶ（FR-222（4）、EC-155、R6）

## Phase 4: US2 確認の項目の補足説明 (P1)

**Goal**: 変えられる設定と常に適用される説明を2行に分ける

**Independent Test**: quickstart.md Q2〜Q7

- [x] T006 [US2] `Sources/FolzioApp/Settings/SettingsWindowController.swift` に補足説明のラベル（折り返し・11pt・`secondaryLabelColor`・選択不可・フォーカス不可）をコンテナに入れて確認のチェックボックスの直下に置き、`setCustomSpacing(4, after:)` とチェックボックスの文言の位置から求めた字下げ（範囲外は 20pt）で配置する。補足説明の後に区分の前の間隔 20pt を設定する（FR-223（2）（3）、R4）
- [x] T007 [US2] 同じファイルに `WrappingCheckbox`（`KeyViewCheckbox` の subclass。幅から高さを計算する）を追加して確認のチェックボックスに使う（EC-153、R3）
- [x] T008 [US2] 同じファイルの `updateLocalizedLabels()` で補足説明の文言と、確認のチェックボックスの `setAccessibilityHelp` を更新し、補足説明のラベルを `setAccessibilityElement(false)` にする。Tab の鎖（`nextKeyView`）は変えない（FR-223（4）、US40-AS4、R5）

## Phase 5: Polish & 検証

- [x] T009 Cloud の検査（quickstart.md「自動の検証」の Cloud の行）を実行し、結果を quickstart.md に記録する
- [x] T010 作業ブランチに push し、保守者の依頼で PR を作ったら CI（`swift build`・`swift test`）の結果を GitHub MCP で確認して quickstart.md に記録する。性能テストはログの末尾で合否を確かめる
- [x] T011 [MANUAL] 保守者が quickstart.md の GUI の確認 Q1〜Q7 を日本語・英語で行い、結果（実行日・OS・合否）を報告する。報告を `specs/TAK-20-settings-section-spacing/checklists/validation.md` に記録する（SC-110・111）
- [x] T012 `speckit-converge` を実行し、追加のタスクがあれば実装と検証を繰り返す
- [x] T013 PR の最後の作業として `git merge origin/master` で最新の master を取り込み、ID の衝突を確かめてから、spec.md の「反映先」を `specs/product/window-layout.md`・`contracts/settings.md`・`contracts/localization.md` へ反映し、spec.md の冒頭に移行済み・凍結の注記を入れる。差分を保守者に示し、承認後にコミットする

## Dependencies

- T002 → T003（テストを先に書く）→ T004〜T008（T006 は T004 の間隔の設定の後、T008 は T006 の後）→ T009〜T013
- 同じファイル（`SettingsWindowController.swift`）を触る T004〜T008 は直列で行う
