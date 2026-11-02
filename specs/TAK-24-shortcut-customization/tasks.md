# Tasks: 設定画面でのショートカットキー割り当ての変更

**Input**: `specs/TAK-24-shortcut-customization/` の spec.md、plan.md、research.md、data-model.md、contracts/、quickstart.md

**Prerequisites**: 設計レビューの承認前には実装しない（`docs_private/cloud-agent-workflow.md`）

**Tests**: Core の検証・保存・整合は自動テスト（憲章 原則 IV）。AppKit の動作は quickstart.md の GUI 確認で保守者が確かめる

**Organization**: US48=記録して割り当てる＋タブ（US1・US4）、US49=重複と使えないキーの防止（US2）、US50=既定値に戻す（US3）。Cloud は Issue 単位のため全タスクを順次実行する。[P] は使わない

## Phase 1: Setup

- [X] T001 設計レビューの承認を受け、承認の日付と範囲を `specs/TAK-24-shortcut-customization/quickstart.md` の「結果の記録」へ書く。research.md R3・R4 の API（`performKeyEquivalent(with:)`、`charactersIgnoringModifiers`、`keyEquivalentModifierMask`、`NSTabView`）を Apple の文書で確かめる
- [X] T002 contracts §1 のコマンド 32 個の既定値を現行コードと突き合わせる。`MainMenu.swift`、`FileListViewController.swift`、`MainSplitViewController.swift`、`DirectoryTreeViewController.swift`、`FileContextMenu.swift` の `keyEquivalent` を grep し、「ゴミ箱に入れる」の重複項目など §1 の確認事項の結果を contracts に追記する

## Phase 2: Foundational（Core の割り当ての表）

- [X] T003 `Tests/FolzioCoreTests/Shortcuts/KeyCombinationTests.swift` を追加する。正規化（大文字 → 小文字 + shift、⇧記号の正規化: 押下 ⇧⌘= が既定の ⌘+ と等しい、⌘= と ⌘+ は別、⇧⌘N と ⌘N は別）、表記（`⇧⌘N`、`⌘↓`、`⌘Delete`）、保存形式の往復、不正な文字列の拒否、`hasRequiredModifier`（先に失敗する形で書く。data-model.md）
- [X] T004 `Sources/FolzioCore/Shortcuts/KeyCombination.swift` を追加する（`KeyModifiers`、`KeyCombination`。AppKit を import しない）
- [X] T005 `Tests/FolzioCoreTests/Shortcuts/ShortcutCommandConsistencyTests.swift` を追加する。既定値どうしの重複なし、既定値がすべて修飾要件を満たす、既定値が固定キー・予約キーを含まない、コマンド 32 個の ID が一意、各コマンドの既定値が contracts §1 と一致、`ShortcutEntry` の静的表記とコマンドの既定値の不一致なし（FR-267）
- [X] T006 `Sources/FolzioCore/Shortcuts/ShortcutCommand.swift` を追加する（`ShortcutCommandID`、`ShortcutCommand`、宣言順の一覧、`FixedKeys`、`ReservedKeys`。contracts §1〜3）
- [X] T007 `Tests/FolzioCoreTests/Shortcuts/ShortcutAssignmentsTests.swift` を追加する。検証の順序（修飾 → 固定/予約 → 重複）、自分自身と同じ組み合わせは変更なし、既定値のままのコマンドとの重複、重複する既定値への戻しが `.conflict`、すべて戻す、`zoomIn` の別名（EC-181）、読み込み時の不正値・未知 ID・重複の解消（EC-179、R9）
- [X] T008 `Sources/FolzioCore/Shortcuts/ShortcutAssignments.swift` を追加する（data-model.md の操作と不変条件）
- [X] T009 `Tests/FolzioCoreTests/Shortcuts/ShortcutOverridesStoreTests.swift` を追加し、`Sources/FolzioCore/Settings/SettingsStore.swift` に `shortcutOverrides` を追加する。上書きなしでキーを消す、辞書でない値の無視、往復（FR-262、contracts §5）
- [X] T010 `Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift` の `ShortcutEntry` にコマンド ID の配列と区切りを持たせ、`keys` を割り当てから生成する関数を追加する。コマンドに対応しない項目は静的な表記のまま。固定キーとコマンドのキーが混ざる項目（`endSearch` = `Esc / ⌘[`、`imageZoom` = `⌘+ / ⌘= / ⌘-` など）は、項目をパーツ列（静的な文字列 / コマンド）で表し、パーツを区切りで連結する。ショートカット一覧の説明文・条件文（`Localizable.strings` の `shortcut.*`）にキー記号が含まれていないかを grep で棚卸しし、含まれていれば引数化するか、キーを含まない文にする。既存の `CatalogConsistencyTests` と `ShortcutTextTests` を通す（R7）

## Phase 3: 翻訳

- [X] T011 `Tests/FolzioCoreTests/Localization/ShortcutSettingsTextTests.swift` を追加する。contracts §4 の文言（タブ名・記録・案内・既定値に戻す・すべて戻す・変更済み・エラー 4 種）が日本語・英語で欠けず、引数の数が正しいこと
- [X] T012 `Sources/FolzioLocalization/TextKey.swift` と `Resources/{en,ja}.lproj/Localizable.strings` に contracts §4 の翻訳キーを追加する。ツールバーの 14 個の文言（`toolbar.goBackHelp`・`goForwardHelp`・`showFileListOnlyHelp`・`showPreviewOnlyHelp`・`showImagesOnlyHelp`・`showVideosOnlyHelp`・`zipFilesHelp`・`startSlideshowHelp`・`zoomInHelp`・`zoomToFitHelp`・`zoomOutHelp`・`thumbnails`・`list`・`thumbnailSize`）を、キーの引数を受ける形に変える（R7・R10）。既存の文言の値は、キー表記の部分以外を変えない

## Phase 4: US48 記録して割り当てる＋タブ (P1)

**Goal**: 設定ウインドウをタブ化し、キーを記録して割り当て、全表示へ反映する

**Independent Test**: quickstart.md Q1〜Q5、Q12

- [X] T013 [US48] `Sources/FolzioApp/Shortcuts/ShortcutAssignmentStore.swift` を追加する（MainActor。起動時に `SettingsStore` から読み込み、`assign`/`reset` で保存し、変更を通知する。`NotificationCenter` で `.shortcutAssignmentsDidChange`）
- [X] T014 [US48] `Sources/FolzioApp/Shortcuts/MenuShortcutApplier.swift` を追加する。`register(_:for:)` で `NSMenuItem`（弱参照）とコマンド ID を結び付け、登録時と変更通知のたびに登録済みの全項目へ `keyEquivalent`・`keyEquivalentModifierMask` を設定する。`item.identifier`（文言の更新が使用）は変えない。`zoomIn` の別名項目は主キーが既定値のときだけ有効にする（R2、EC-181）
- [X] T015 [US48] `MainMenu.swift`、`FileListViewController.swift`（`installViewMenuItems`）、`MainSplitViewController.swift`（`installFocusMenuItems`、`goBack`/`goForward` の項目）、`DirectoryTreeViewController.swift`、`FileContextMenu.swift` の各メニュー項目を、組み立て直後に `MenuShortcutApplier.register` で登録して適用する（コンテキストメニューはメニューを作り直すたびに登録する）。`MainMenu.bind` の識別子には触れない。キーの直書きは残さない。予約キー（⌘Q ⌘W ⌘, と編集メニューの標準キー）と Return の項目は対象外のまま
- [X] T016 [US48] ツールバーのツールチップとアクセシビリティラベル（`MainToolbarController.swift`。TAK-23 で `l10n.text(.toolbar…Help)` を使う箇所が約 20 か所に増えた。カスタマイズの変更通知後・言語切り替え後も更新する）、ショートカット一覧ウインドウ（`ShortcutCheatSheetWindowController.swift` ほか）を割り当ての表から生成する。変更通知で更新し、一覧は先頭の可視項目を保つ（FR-261、R7）
- [X] T017 [US48] `Sources/FolzioApp/Shortcuts/ShortcutRecorderRow.swift` を追加する。コマンド名・現在のキー・状態・「記録」・「既定値に戻す」・エラーの 1 行。記録中は `performKeyEquivalent`/`keyDown` を横取りし、押された文字と修飾キーを `KeyCombination.normalized` に通して候補にし、修飾キーだけの入力は無視、Esc で取消、フォーカス喪失・ウインドウ閉鎖・言語変更で取消（FR-258、R3、EC-178）
- [X] T018 [US48] `Sources/FolzioApp/Settings/ShortcutSettingsViewController.swift` を追加する。区分の見出しと 32 行を `NSScrollView` に並べ、下部に「すべて既定値に戻す」を固定する。Tab / ⇧Tab の巡回、行ごとのアクセシビリティ（名前・キー・状態）、エラーの読み上げ（FR-257・265）
- [X] T019 [US48] `SettingsWindowController.swift` を `NSTabView` の 2 タブ（「一般」「ショートカット」）にする。「一般」は現行の `makeContentView()` の内容・間隔・Tab 順・補足説明をそのまま移す。開いたとき常に「一般」。タブ切り替えで高さを各タブに合わせ、記録中なら取り消す。言語切り替えで両タブを更新する（FR-255、US48-AS5〜7）

## Phase 5: US49 重複と使えないキーの防止 (P1)

**Goal**: 記録時に拒否の理由を示し、割り当てない

**Independent Test**: quickstart.md Q6・Q7・Q9

- [X] T020 [US49] 記録行の検証結果（`.missingModifier`、`.reserved`/`.fixed`、`.conflict`）を contracts §4 のエラー文に対応づけて行に表示し、記録中のまま次の入力を待つ。同じ組み合わせの再入力は記録を終えるだけにする。エラーは色以外に記号と文言で示し、読み上げる（FR-259・260・265、US49-AS1〜5）

## Phase 6: US50 既定値に戻す (P2)

**Goal**: 1 つ・すべてを既定値に戻す

**Independent Test**: quickstart.md Q10・Q11

- [X] T021 [US50] 行の「既定値に戻す」（既定値のままなら無効）と「すべて既定値に戻す」を実装する。既定値が重複するときは戻さずに contracts §4 の文言で案内する。「すべて」は確認なしで上書きを消す（FR-263、A-158）

## Phase 7: Polish & 検証

- [X] T022 Cloud の検査（quickstart.md「自動の検証」の Cloud の行）を実行し、結果を quickstart.md に記録する。新しいコードコメントは英語で書く
- [X] T023 作業ブランチに push し、保守者の依頼で PR を作ったら CI（`swift build`・`swift test`）の結果を GitHub MCP で確認して quickstart.md に記録する。性能テストはログの末尾で合否を確かめる
- [X] T024 [MANUAL] 保守者が quickstart.md の GUI の確認 Q1〜Q17 を日本語・英語で行い、結果（実行日・OS・合否）を報告する。報告を `specs/TAK-24-shortcut-customization/checklists/validation.md` に記録する（SC-125〜131）
- [X] T025 `speckit-converge` を実行し、追加のタスクがあれば実装と検証を繰り返す
- [X] T026 `README.md` と `README.ja.md` のキー表（⌘/、⌘1 / ⌘2、⌘+ など）の見出しまたは直前の文に「既定のキー。設定の「ショートカット」で変更できる」旨を同じコミットで両言語に入れる。`docs/usage.md`・`docs/usage.ja.md` にも同じ注記と、保存先の節への `shortcuts.overrides` を足す（公開版のため `specs/` などへのリンクは張らない）。構造を1対1で保ち、`scripts/check-readme-sync.sh master` を通す（AGENTS.md「README の英語版と日本語版」）
- [ ] T027 PR の最後の作業として（`keyboard-and-menus.md` のツールバーのツールチップの表には「既定のキー。割り当てに従う」と注記する） `git merge origin/master` で最新の master を取り込み、ID の衝突を確かめてから、spec.md の「反映先」を `specs/product/window-layout.md`・`contracts/settings.md`・`contracts/keyboard-and-menus.md`・`contracts/localization.md` へ反映し、spec.md の冒頭に移行済み・凍結の注記を入れる。差分を保守者に示し、承認後にコミットする

## Phase 8: 仕様の変更（未設定の許可。2026-11-02、保守者の相談）

- [X] T028 [US50] `ShortcutAssignments` に未設定（`ShortcutOverride.unset`、保存値 `none`、`unsetting(_:)`、`isUnset(_:)`）を加え、`combination(for:)` を Optional にする。重複の判定から未設定を除き、未設定のコマンドの別名を無効にする。`ShortcutAssignmentsTests`・`ShortcutCommandConsistencyTests` にテストを足す（入れ替えの 3 手、解放されたキー、保存と読み込み、未設定の別名）（FR-268、EC-186・187、SC-132）
- [X] T029 [US50] 翻訳（`settings.shortcuts.clear`・`clearFor`・`unset`）と `ShortcutSettingsTextTests` を足し、ショートカット一覧・ツールチップ・設定画面の行が未設定を「未設定」と表示する。`MenuShortcutApplier` は未設定のコマンドの項目からキーを外す（FR-268）
- [X] T030 [US50] 行に「未設定にする」ボタンを足し、キーの下に「変更済み」を置く列の構成に直す（コマンド名 160pt、キー 110pt）。Tab 順は記録 → 未設定にする → 既定値に戻す（FR-257・268）
- [X] T031 `docs/usage.md`・`docs/usage.ja.md` に「未設定にする」を足す。quickstart.md に Q17（入れ替え）を足す

## Dependencies

- T001・T002 → T003〜T010（T003→T004、T005→T006→T007→T008→T009→T010 の順。テストを先に書く）→ T011→T012 → T013〜T021 → T022〜T027（T026 の README は T025 の後、T027 の前）
- T014 は T013 の後、T015 は T014 の後、T016 は T012・T013 の後、T017 は T008・T013 の後、T018 は T017 の後、T019 は T018 の後、T020・T021 は T017 の後
- 同じファイルを触るタスクは直列で行う（Cloud は並列実装をしない）
