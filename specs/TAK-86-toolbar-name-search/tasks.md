# Tasks: TAK-86 ツールバーの名前検索欄

**Input**: `specs/TAK-86-toolbar-name-search/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/toolbar-search-field.md / quickstart.md

**Tests**: Core の判断（`ToolbarLayout`・`ToolbarSearchInput`）にテストを、文言に翻訳の検査を付ける（憲章 原則 IV、R12）。
検索欄の見た目・Return・虫眼鏡・カスタマイズ・VoiceOver は保守者がローカルで確認する。実装は保守者の設計承認の後に行う。

## Phase 1: Setup

- [x] T001 `specs/TAK-86-toolbar-name-search/spec.md` と `checklists/requirements.md` を作り、TAK-86 と保守者の決定（Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/toolbar-search-field.md`・`quickstart.md` に設計と検証方法を記録する
- [ ] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: Foundational（並び・判断・文言）

- [ ] T004 [P] `Tests/FolzioCoreTests/ToolbarLayoutTests.swift` を直す（先に失敗させる）。
  既定の並びのテストを「8つのセット → `NSToolbarFlexibleSpaceItem` → `search`」にし、テストの名前も合わせる。次のテストを加える:
  `search` を含まない有効な保存値はそのまま返り `search` が足されない、`search` を含む保存値はそのまま返る、`search` の重複は最初の1つだけ残る（FR-390、data-model.md）
- [ ] T005 `Sources/FolzioCore/Settings/ToolbarLayout.swift` の `setIdentifiers` の末尾に `"search"` を加え、`defaultOrder` を
  「`search` を除くセット → `flexibleSpaceIdentifier` → `search`」の並びで明示して書き、T004 を通す。`normalized(saved:)` は変えない。
  コメント（英語）を、既定の並びで検索が可変スペースの右に来ることと FR-233・FR-390 に合わせて直す（R8）
- [ ] T006 [P] `Tests/FolzioCoreTests/ToolbarSearchInputTests.swift` を作る（先に失敗させる）。`modalKeyword(fieldText:previousKeyword:)` が、
  文字があれば前後の空白を除いた検索欄の文字を返す（前回のキーワードがあっても検索欄を優先する）、空・空白だけ・改行だけなら前回のキーワードを返す、
  どちらもなければ `nil` を返すことをテストする（FR-386、data-model.md）
- [ ] T007 `Sources/FolzioCore/Search/ToolbarSearchInput.swift` に `public enum ToolbarSearchInput` と
  `public static func modalKeyword(fieldText: String, previousKeyword: String?) -> String?` を実装して T006 を通す。AppKit を import しない。コメントは英語で FR-386 を書く
- [ ] T008 [P] `Sources/FolzioLocalization/TextKey.swift` に `toolbarSearchLabel = "toolbar.searchLabel"`・`toolbarSearchPlaceholder = "toolbar.searchPlaceholder"`・
  `toolbarSearchFindHelp = "toolbar.searchFindHelp"` を加える。`toolbarSearchFindHelp` は `arguments` の `[.text]` の case に加える。
  翻訳者向けの説明を加える（ラベルは既存の「Toolbar group names」の case へ、プレースホルダは「検索欄のプレースホルダとアクセシビリティのラベル」、
  虫眼鏡は「検索欄の虫眼鏡のツールチップ。値はショートカットの表記」）。
  `Resources/ja.lproj/Localizable.strings` に「検索」「名前で検索」「検索…（%1$@）」、`Resources/en.lproj/Localizable.strings` に `Search`・`Search by Name`・`Find… (%1$@)` を加える（FR-389、R9、contracts）
- [ ] T009 `Sources/FolzioApp/Shortcuts/ToolbarShortcutText.swift` の `commands(for:)` に `case .toolbarSearchFindHelp: return [.find]` を加える（FR-237（window-layout.md）、R9）
- [ ] T010 `Tests/FolzioCoreTests/Localization/ShortcutSettingsTextTests.swift` の `toolbarKeys` に `.toolbarSearchFindHelp` を、`toolbarPlainKeys` に
  `.toolbarSearchLabel`・`.toolbarSearchPlaceholder` を加える。既存の検査の前提（キーの形式・固定の記号を含まない）に合わなければ、同じ方法の別のテストにする
- [ ] T011 `scripts/dev/check-all.sh` を実行して成功させ、作業ブランチに push し、CI（`macos-swift-ci.yml`。PR がなければ `workflow_dispatch` で作業ブランチを指定）で
  `swift build` と `swift test` の成功を確かめる。失敗したらログを読んで直し、Phase 3 に進まない。
  既定の並びを手書きしているテストやコードがほかにあれば（`grep -rn "NSToolbarFlexibleSpaceItem\|thumbnailSize" Tests Sources`）、ここで合わせる

## Phase 3: User Story 81 - ツールバーから名前で検索する (P1)

**Goal**: 検索欄に入力して Return で、一覧のフォルダを起点に検索できる

**Independent Test**: quickstart.md の 0〜2・4・8

- [ ] T012 [US81] `Sources/FolzioApp/Search/ToolbarSearchField.swift` に `final class ToolbarSearchField: NSSearchField` を作る。
  この時点では、幅の固定の制約（180pt。`translatesAutoresizingMaskIntoConstraints = false`。サムネイルサイズのスライダーと同じ方法）と、
  検索の `action` を送らない設定だけを持つ。×ボタンと Esc での消去は標準の動作のまま使い、処理を足さない（FR-381・EC-257、R4）。コメントは英語（R1・R3）
- [ ] T013 [US81] `Sources/FolzioApp/App/MainSplitViewController.swift` に `func startToolbarSearch(fieldText: String)` を加える（data-model.md の「検索の開始までの流れ」）。
  `paneCommands.canSearch` と `SearchPattern(keyword:)` を確かめ、`model.listing.folder` を控えて `SearchRoot.validate(_:)` を `Task` で呼ぶ。
  前の検証のタスクは取り消す。終わった時点で、フォルダが同じ・`canSearch` が真・`view.window?.attachedSheet == nil` を確かめ、満たさなければ何もしない。
  成功なら `lastSearchKeyword` を更新して `model.startSearch(_:root:)` を呼び、ファイルリストへフォーカスを移す（`showSearch(_:)` の完了の処理と同じ内容を1つの関数にまとめて共用する）。
  失敗なら T014 の入口でモーダルを開く（FR-382〜FR-385、R5・R6）
- [ ] T014 [US81] `Sources/FolzioApp/Search/SearchPanelController.swift` の `init` に `initialRootError: SearchRootError? = nil` を加え、渡されたら表示の時点で
  既存の `showReason` で理由を表示する（読み上げを含む。FR-384・EC-252）。`MainSplitViewController.showSearch(_:)` の中身を
  `private func presentSearchPanel(keyword: String?, rootError: SearchRootError? = nil)` へ移し、`showSearch(_:)` は `presentSearchPanel(keyword: lastSearchKeyword)` を呼ぶだけにする
  （⌘F の動作を変えない。FR-386）
- [ ] T015 [US81] `Sources/FolzioApp/App/MainToolbarController.swift` に `searchIdentifier`（`"search"`）を加え、`makeItem(for:)` で項目を作る。
  `view` は `ToolbarSearchField`、`label`・`paletteLabel` は `toolbarSearchLabel`、プレースホルダとアクセシビリティのラベルは `toolbarSearchPlaceholder`、`delegate` は `self`。
  `MainToolbarController` を `NSSearchFieldDelegate` に適合させ、`control(_:textView:doCommandBy:)` で `insertNewline(_:)` のときに
  `panes.startToolbarSearch(fieldText: control.stringValue)` を呼んで `true` を返す。ほかのコマンドは `false` を返す（FR-380・FR-382、R1・R3）
- [ ] T016 [US81] 同じファイルの `toolbarDefaultItemIdentifiers` と `toolbarAllowedItemIdentifiers` を、手書きの配列から
  `ToolbarLayout.defaultOrder` と `ToolbarLayout.setIdentifiers + [spaceIdentifier, flexibleSpaceIdentifier]` を `NSToolbarItem.Identifier` にしたものへ変える（R8）
- [ ] T017 [US81] 同じファイルに `applySearchAvailability()` と `applySearchAvailability(to:)` を加え、項目とフィールドの `isEnabled` を `panes.paneCommands.canSearch` にする。
  `applyState(to:)`・`apply(paneLayout:)`・`updateSlideshowAvailability()`・`validateToolbarItem(_:)` から呼ぶ。
  フルスクリーンへの出入りでこれらのどれかが呼ばれることをコードで確かめ、呼ばれなければ呼び出しを足す（FR-388、R7）
- [ ] T018 [US81] 同じファイルの `displayLanguageDidChange()` に、検索の項目の `label`・`paletteLabel`・プレースホルダ・アクセシビリティのラベルの更新を加える。入力済みの文字は変えない（EC-255）

## Phase 4: User Story 82 - 入力したキーワードを持って検索のモーダルへ移る (P2)

**Goal**: 虫眼鏡と、検索欄にフォーカスがある間の ⌘F で、検索欄の文字を引き継いだモーダルが開く

**Independent Test**: quickstart.md の 3・5

- [ ] T019 [US82] `Sources/FolzioApp/App/MainSplitViewController.swift` に `func showSearch(carrying fieldText: String)` を加える。`paneCommands.canSearch` を確かめ、
  `ToolbarSearchInput.modalKeyword(fieldText:previousKeyword: lastSearchKeyword)` を `presentSearchPanel(keyword:)` へ渡す。`lastSearchKeyword` はここでは変えない（FR-386・FR-387）
- [ ] T020 [US82] `Sources/FolzioApp/App/MainToolbarController.swift` に `@objc func showSearch(_ sender: Any?)` を加える。ツールバーにある検索の項目のフィールドの文字
  （項目がなければ空）で `panes.showSearch(carrying:)` を呼ぶ。項目を作るとき、`(field.cell as? NSSearchFieldCell)?.searchButtonCell` の `target` を `self`、`action` を `showSearch(_:)` にする。
  虫眼鏡（`searchButtonCell`）のアクセシビリティのラベルと説明に `ToolbarShortcutText.text(.toolbarSearchFindHelp)` を付け、`displayLanguageDidChange()` で更新する（FR-386・FR-389、R2）
- [ ] T021 [US82] `Sources/FolzioApp/Search/ToolbarSearchField.swift` に、虫眼鏡の矩形（`searchButtonRect(forBounds:)`）だけのツールチップを加える。
  文言を受け取るプロパティ（`searchButtonToolTip`）を持ち、`layout()` と文言の変更で `removeAllToolTips()` の後に `addToolTip(_:owner:userData:)` で付け直す（FR-389、R2）
- [ ] T022 [US82] 同じファイルに `weak var findCommandTarget: AnyObject?` を加え、`supplementalTarget(forAction:sender:)` を上書きして、
  `action` が `showSearch(_:)` のセレクタ（`#selector(MainSplitViewController.showSearch(_:))` と同じ名前）のときだけ `findCommandTarget` を返し、それ以外は `super` を返す。
  `MainToolbarController` が項目を作るときに自分を `findCommandTarget` に設定する。ファイル操作のセレクタは転送しない（FR-386・EC-258、R11）
- [ ] T023 [US82] `MainToolbarController` の `validateMenuItem(_:)` で、`showSearch(_:)` の項目に `panes.paneCommands.canSearch` を返す（「ファイル > 検索…」が検索欄にフォーカスがある間も正しく有効・無効になる。FR-388）

## Phase 5: User Story 83 - 検索欄を含むツールバーを自分の並びにする (P3)

**Goal**: 文字だけの形式とあふれたメニューで検索のモーダルが開き、カスタマイズと保存が既存の規則で働く

**Independent Test**: quickstart.md の 6

- [ ] T024 [US83] `Sources/FolzioApp/App/MainToolbarController.swift` の検索の項目に `menuFormRepresentation`（名前 `toolbarSearchLabel`、`action` `showSearch(_:)`、`target` `self`）を設定し、
  `displayLanguageDidChange()` で名前を更新する（FR-389、R10）
- [ ] T025 [US83] 並びの保存と復元（`restoreSavedConfiguration()`・`saveConfiguration()`）が、`search` を含む並びと含まない並びで既存の規則のまま働くことをコードで確かめる。
  コードの変更が要らなければ、その旨をこのタスクに注記する（FR-390、R8）

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T026 `scripts/dev/check-all.sh` を実行して成功させる（Cloud の検査。docs_private/cloud-agent-workflow.md の 5 章）。T028・T030 の後にも、それぞれもう一度実行する
- [ ] T027 作業ブランチに push し、CI で `swift build` と `swift test` の成功を確かめる。性能テストはログの末尾で件数を確かめる
- [ ] T028 ユーザーガイドと開発の手順書を更新する。日本語と英語を同じコミットで同じ内容にする。
  - `docs/usage.ja.md`・`docs/usage.md` の「ツールバー」に検索欄（既定で右端、カスタマイズで動かせる）を、「名前の検索」の「検索の開始」に、
    検索欄での Return（起点は一覧に表示中のフォルダ）と、虫眼鏡でキーワードを引き継いでモーダルを開けることを加える
  - `docs/development.ja.md`・`docs/development.md` の手動の確認に、検索欄の Return・×ボタン・虫眼鏡を加える
  - README（`README.md`・`README.ja.md`）に検索やツールバーの機能の一覧があれば、両方を同じ内容で直す
  - 公開用リポジトリへ書き出される文書なので、`specs/`・`docs_private/` へリンクしない（AGENTS.md の「書くときの規則」）
- [ ] T029 [MANUAL] 保守者に quickstart.md の GUI 確認（0〜8）を依頼し、結果を `checklists/validation.md` に記録する。確認されるまでこのタスクは未チェックのまま残す。
  未確認の点（research.md の R2・R3・R7・R10・R11）で動かないものがあれば、research.md の代替へ直して再び確認を依頼する
- [ ] T030 最新の `origin/master` を取り込み、`scripts/dev/check-spec-ids.sh` を実行してから、spec.md の「反映先」の表のとおり `specs/product/search.md`・`window-layout.md`・
  `contracts/settings.md`・`contracts/keyboard-and-menus.md`・`contracts/localization.md` へ反映する（`specs/product/README.md` の「書き方のルール」に従う。
  ID の定義は1文にし、条件は子項目に分ける。feature の中だけの参照（research.md の節など）は製品仕様に残さない。GUI 確認で変わった点があれば、その結果で直してから移す）。
  反映の後に `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-all.sh` を実行し、反映した項目と差分を保守者に示して承認を得てからコミットする
- [ ] T031 反映が終わったら、spec.md の冒頭に移行済み・凍結の注記を入れる（`specs/product/README.md` の「feature の spec.md の書き方」）

## Dependencies & Execution Order

- T003（設計の承認）→ Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
- Phase 2: T004 → T005。T006 → T007。T008 → T009 → T010。T011 は T005・T007・T010 の後
- Phase 3: T012 → T015。T014 → T013（モーダルを開く入口を先に作る）。T015 → T016 → T017 → T018（同じファイル）
- Phase 4: T019 → T020 → T023。T021・T022 は T012 の後で、T020 が使う
- Phase 5: T024 は T020 の後（`showSearch(_:)` を使う）
- Phase 6: T026・T027 は Phase 5 の後。T028 は Phase 5 の後。T029 は T027 の後。T030・T031 は PR の最後の作業（docs_private/cloud-agent-workflow.md の 7 章）

## Parallel Example

```text
T004（ToolbarLayoutTests.swift）・T006（ToolbarSearchInputTests.swift）・T008（TextKey.swift・Localizable.strings）は並行できる
```

Cloud ではサブエージェントで実装を分けない（AGENTS.md）。上の並行は順序の制約がないことを示すだけで、1 つのセッションで順に行う。

## Implementation Strategy

- MVP は Phase 2〜3（US81）。検索欄と Return の検索だけで価値がある
- まず Core の並び・判断と文言（T004〜T010）を CI で確かめ（T011）、次に App の変更を User Story の順に行い、CI と保守者の GUI 確認で確かめる
- Cloud には Swift がないため、App の変更はコンパイルの誤りを CI でしか見つけられない。API の名前（`searchButtonCell`・`searchButtonRect(forBounds:)`・
  `supplementalTarget(forAction:sender:)`・`control(_:textView:doCommandBy:)`）は、使う前に既存のコードか公開の文書で確かめる（docs_private/cloud-agent-workflow.md の 4 章）
