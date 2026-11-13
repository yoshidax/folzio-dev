# Tasks: TAK-86 ツールバーの検索欄による名前の絞り込み

**Input**: `specs/TAK-86-toolbar-name-search/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/toolbar-name-filter.md / quickstart.md

**Tests**: Core の判断（`NameFilter`・`BrowserModel` の絞り込み・`ToolbarLayout`・`ToolbarSearchInput`・コマンドの定義）にテストを、文言に翻訳の検査を、
10,000 件の絞り込みに性能テストを付ける（憲章 原則 II・IV、R15・R16）。
検索欄の見た目・入力・虫眼鏡・⌥⌘F・カスタマイズ・VoiceOver は保守者がローカルで確認する。実装は保守者の設計承認の後に行う。

## Phase 1: Setup

- [x] T001 `specs/TAK-86-toolbar-name-search/spec.md` と `checklists/requirements.md` を作り、TAK-86 と保守者の決定（要件の変更を含む Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/toolbar-name-filter.md`・`quickstart.md` に設計と検証方法を記録する
- [x] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: Foundational（Core の型・並び・コマンド・文言）

- [x] T004 [P] `Tests/FolzioCoreTests/NameFilterTests.swift` を作る（先に失敗させる）。空・空白だけは絞り込まない、部分一致、`*`・`?` の名前全体との一致、
  大文字小文字と濁点の合成・分解を区別しない、フォルダ・zip ファイル・zip の中のディレクトリも照合する、`text` は入力のまま保つ、をテストする（FR-381、data-model.md）
- [x] T005 `Sources/FolzioCore/Model/NameFilter.swift` に `public struct NameFilter: Sendable, Equatable` を実装して T004 を通す。
  照合は `SearchPattern(keyword:)` と `matches(fileName:)` を使い、規則を書き直さない。AppKit を import しない。コメントは英語で FR-381 を書く（R2）
- [x] T006 [P] `Tests/FolzioCoreTests/ToolbarSearchInputTests.swift` を作り（先に失敗させる）、`Sources/FolzioCore/Search/ToolbarSearchInput.swift` に
  `public enum ToolbarSearchInput` と `modalKeyword(fieldText:previousKeyword:)` を実装する。文字があれば前後の空白を除いた検索欄の文字（前回のキーワードより優先）、
  空・空白だけなら前回のキーワード、どちらもなければ `nil`（FR-390、data-model.md）
- [x] T007 [P] `Tests/FolzioCoreTests/ToolbarLayoutTests.swift` を直し（先に失敗させる）、`Sources/FolzioCore/Settings/ToolbarLayout.swift` の `setIdentifiers` の末尾に `"nameFilter"` を加え、
  `defaultOrder` を「`nameFilter` を除くセット → `flexibleSpaceIdentifier` → `nameFilter`」の並びで明示して書く。`normalized(saved:)` は変えない。
  テスト: 既定の並び、`nameFilter` を含まない保存値はそのまま返り足されない、含む保存値はそのまま返る、重複は最初の1つ（FR-393、R14）
- [x] T008 `Sources/FolzioCore/Shortcuts/ShortcutCommand.swift` の `ShortcutCommandID` に `filterByName` を（`find` の直後）、`ShortcutCommands.all` に
  `ShortcutCommand(id: .filterByName, defaultCombination: key("f", [.option, .command]), section: .search)` を（`find` の直後）加える。
  `Sources/FolzioCore/Shortcuts/ShortcutCatalog.swift` に、`find` の直後の項目（キー `⌥⌘F`、区分は検索、`parts: [.command(.filterByName)]`）を加える。
  `ShortcutEntry` の ID の型に case が要れば加える（FR-391、R11）
- [x] T009 `Sources/FolzioLocalization/TextKey.swift` に文言のキーを加える（contracts/toolbar-name-filter.md の表の 8 つ）:
  `menuFileFilterByName`・`toolbarNameFilterLabel`・`toolbarNameFilterPlaceholder`・`toolbarNameFilterHelp`・`toolbarNameFilterFindHelp`・`emptyNameFilterNoMatches`・
  `shortcutFilterByName`・`shortcutFilterByNameCondition`。引数を持つ 3 つ（`toolbarNameFilterHelp`・`toolbarNameFilterFindHelp`・`emptyNameFilterNoMatches`）は
  `arguments` の `[.text]` の case に加える。翻訳者向けの説明を加える。`Resources/ja.lproj/Localizable.strings` と `Resources/en.lproj/Localizable.strings` に、表のとおりの文言を加える（FR-392、contracts）
- [x] T010 `Sources/FolzioLocalization/ShortcutText.swift` の3つの対応（名前・条件・メニューのキー）に `filterByName` を加える。
  `Sources/FolzioApp/Shortcuts/ToolbarShortcutText.swift` の `commands(for:)` に `.toolbarNameFilterHelp → [.filterByName]` と `.toolbarNameFilterFindHelp → [.find]` を加える（R8・R11）
- [x] T011 コマンドの数と既定のキーを書いているテストを直す: `Tests/FolzioCoreTests/Shortcuts/ShortcutCommandConsistencyTests.swift` の 32 を 33 にし、既定のキーの表に
  `.filterByName: "⌥⌘F"` を加える。ほかに数や一覧を書いているテスト（`grep -rn "32\|\.find" Tests/FolzioCoreTests/Shortcuts Tests/FolzioCoreTests/Localization`）があれば合わせる。
  `Tests/FolzioCoreTests/Localization/ShortcutSettingsTextTests.swift` に、新しい文言が両言語で訳されていることのテストを加える（引数を持つキーは `toolbarKeys`、持たないキーは `toolbarPlainKeys` と同じ方法）
- [x] T012 `scripts/dev/check-all.sh` を実行して成功させ、作業ブランチに push し、CI（`macos-swift-ci.yml`。PR がなければ `workflow_dispatch` で作業ブランチを指定）で
  `swift build` と `swift test` の成功を確かめる。失敗したらログを読んで直し、Phase 3 に進まない。
  網羅の `switch` で `ShortcutCommandID` を扱う箇所の直し漏れは、ここのビルドで見つける
  - 注記（2026-11-13）: Phase 2 だけでは CI に通らないため、Phase 3〜6 の後に CI で合わせて確かめる。
    新しい文言のうち `toolbarNameFilterLabel`・`toolbarNameFilterPlaceholder` は Phase 3 のツールバーのコードで初めて使われ、
    既存のテスト（`CatalogConsistencyTests.casesAreReferenced`）が、どこからも使われない文言のキーを失敗にするため
  - 結果（2026-11-13）: Phase 3〜6 と合わせて CI で確かめた（下の T033）

## Phase 3: User Story 81 - 表示中の一覧を名前で絞り込む (P1)

**Goal**: 検索欄に入力するたびに、表示中の一覧が名前で絞り込まれ、一覧が替わると解除される

**Independent Test**: quickstart.md の 0〜3・7

- [x] T013 [US81] `Tests/FolzioCoreTests/BrowserModelNameFilterTests.swift` を作る（先に失敗させる。既存の `BrowserModelFolderTests`・`BrowserModelSearchTests` の環境の作り方を使う）。
  (1) 通常のフォルダでファイルとフォルダの行が絞り込まれ `..` が残る、(2) 種類フィルタ・zip の表示と重ねて働く、(3) 1行も残らないと `state == .noMatches` で
  `nameFilterHidesAllRows` が真、行が残るときは偽で従来の状態、(4) 元々空のフォルダは `.empty` のまま、(5) 非表示になった項目が選択から外れ、フォーカスの扱いが種類フィルタと同じ、
  (6) 別のフォルダの選択・フォルダの行を開く・上の階層へ・検索の開始・検索結果の解除・履歴の場所の表示で絞り込みが空になる、(7) `reloadCurrentFolder()` では空にならず、
  増えた項目はその時点の名前で照合される、(8) 検索結果の一覧が絞り込まれ、`listing.search` の件数と検索の進行は変わらない、(9) zip の中の一覧が絞り込まれる
  （FR-381〜FR-386、data-model.md）
- [x] T014 [US81] `Sources/FolzioCore/Browser/BrowserModel.swift` に `nameFilter`・`nameFilterHidesAllRows`・`setNameFilter(_:)` を加え、`rebuildListing()` と `resetForNavigation()` を
  data-model.md のとおりに直して T013 を通す。選択を表示中の行に限る処理は、`setMediaTypeFilter(_:)` と共用する関数にまとめる。コメントは英語（R1・R3・R4）
- [x] T015 [US81] `Tests/FolzioPerformanceTests/NameFilterPerformanceTests.swift` を作る（既存の `PerformanceBaselineTests` の extension にする。別の suite にしない）。
  10,000 件の項目を持つ一覧で `setNameFilter` を呼び、1回が 100ms 以内であることを確かめる（SC-209、R15）
  - 注記（2026-11-13）: 最初の CI（run 43355920499）で、最も遅い 1 文字が 108ms で基準を超えた（同じ実行で既存の性能テストも 3 件が超えており、共有ランナーのぶれも大きい）。
    R15 のとおり軽くした。名前が ASCII だけのときは `SearchPattern.normalize` を `lowercased()` で済ませ（NFC と大文字小文字の畳み込みと同じ結果。`SearchPatternTests` で確かめる）、
    選択が空のときは表示中の行の URL の集合を作らない
- [x] T016 [US81] `Sources/FolzioApp/FileList/FileListViewController.swift` に `applyNameFilter(_ text: String)`・`currentNameFilterText`・`onNameFilterChange`・`observeNameFilter()` を加える
  （`applyMediaTypeFilter(_:)`・`observeMediaTypeFilter()` と同じ形）。`.noMatches` のメッセージの分岐で、`model.nameFilterHidesAllRows` が真なら
  `l10n.text(.emptyNameFilterNoMatches, .text(model.nameFilter.text の前後の空白を除いた文字))` を出す。表示言語の切り替えでメッセージが更新されることを確かめる（FR-386・EC-255、R3・R5）
- [x] T017 [US81] 表示中の一覧を対象にする操作（すべてを選択・矢印キーでの移動・フルスクリーン中の移動・スライドショーの対象）が `listing.files` を読むことをコードで確かめる。
  `allFiles` を直接使う箇所があれば、種類フィルタと同じ扱いになるように直す。直す箇所がなければ、その旨をこのタスクに注記する（FR-387、R1）
  - 注記（2026-11-13）: コードの変更は要らなかった。矢印キーの移動（`BrowserModel.moveFocus`）は `listing.files` を読み、
    スライドショーの対象（`SlideshowSequence`）も `listing.files` から作る。`allFiles` の残りの使用は、検索結果の管理と再読み込みの内部の処理だけ
- [x] T018 [US81] `Sources/FolzioApp/Search/ToolbarSearchField.swift` に `final class ToolbarSearchField: NSSearchField` を作る。この時点では、幅の固定の制約（180pt。
  `translatesAutoresizingMaskIntoConstraints = false`。サムネイルサイズのスライダーと同じ方法）だけを持つ。×ボタンと Esc での消去は標準の動作のまま使う。コメントは英語（R7）
- [x] T019 [US81] `Sources/FolzioApp/App/MainToolbarController.swift` に `nameFilterIdentifier`（`"nameFilter"`）を加え、`makeItem(for:)` で項目を作る。
  `view` は `ToolbarSearchField`、`label`・`paletteLabel` は `toolbarNameFilterLabel`、プレースホルダとアクセシビリティのラベルは `toolbarNameFilterPlaceholder`、`delegate` は `self`。
  `MainToolbarController` を `NSSearchFieldDelegate` に適合させる。`controlTextDidChange(_:)` で、フィールドエディタの `hasMarkedText()` が偽のときに
  `fileList.applyNameFilter(field.stringValue)` を呼ぶ。`control(_:textView:doCommandBy:)` で `insertNewline(_:)` のときにファイルリストへフォーカスを移して `true` を返す
  （フォーカスを移す入口を `MainSplitViewController` に公開の関数として加える）。ツールバーにない検索欄（パレットの見本）の入力は無視する（FR-380・FR-381・FR-383・FR-389、R6・R7）
- [x] T020 [US81] 同じファイルで `fileList.onNameFilterChange` を受け、ツールバーにある検索欄の文字がモデルの文字と違うときだけ書き換える（移動での解除で検索欄が空になる。FR-384、R5）。
  `applyState(to:)` で、新しく入った項目の検索欄にモデルの文字を入れる
- [x] T021 [US81] 同じファイルの `toolbarDefaultItemIdentifiers` と `toolbarAllowedItemIdentifiers` を、手書きの配列から
  `ToolbarLayout.defaultOrder` と `ToolbarLayout.setIdentifiers + [spaceIdentifier, flexibleSpaceIdentifier]` を `NSToolbarItem.Identifier` にしたものへ変える（R14）
- [x] T022 [US81] 同じファイルに `applyNameFilterAvailability()` と `applyNameFilterAvailability(to:)` を加え、項目とフィールドの `isEnabled` を `panes.paneCommands.canSearch` にする。
  `applyState(to:)`・`apply(paneLayout:)`・`updateSlideshowAvailability()`・`validateToolbarItem(_:)` から呼ぶ。フルスクリーンへの出入りでこれらのどれかが呼ばれることをコードで確かめ、
  呼ばれなければ呼び出しを足す。無効にしてもモデルの絞り込みは変えない（FR-388・EC-258、R13）
  - 注記（2026-11-13）: 全画面の出入り（`enterFullScreenPresentation`・`leaveFullScreenPresentation`）はツールバーの更新を呼ばなかったので、
    `MainSplitViewController.onSearchAvailabilityChange` を加えて呼ぶ
- [x] T023 [US81] 同じファイルの `displayLanguageDidChange()` に、項目の `label`・`paletteLabel`・プレースホルダ・アクセシビリティのラベルの更新を加える。入力済みの文字は変えない（EC-255）

## Phase 4: User Story 82 - 入力したキーワードを持って検索のモーダルへ移る (P2)

**Goal**: 虫眼鏡と、検索欄にフォーカスがある間の ⌘F で、検索欄の文字を引き継いだモーダルが開く

**Independent Test**: quickstart.md の 5

- [x] T024 [US82] `Sources/FolzioApp/App/MainSplitViewController.swift` の `showSearch(_:)` の中身を `private func presentSearchPanel(keyword: String?)` へ移し、`showSearch(_:)` は
  `presentSearchPanel(keyword: lastSearchKeyword)` を呼ぶだけにする（⌘F の動作を変えない）。`func showSearch(carrying fieldText: String)` を加え、`paneCommands.canSearch` を確かめて
  `ToolbarSearchInput.modalKeyword(fieldText:previousKeyword: lastSearchKeyword)` を渡す。`lastSearchKeyword` はここでは変えない（FR-390、R9）
- [x] T025 [US82] `Sources/FolzioApp/App/MainToolbarController.swift` に `@objc func showSearch(_ sender: Any?)` を加える。モデルの絞り込みの文字（`fileList.currentNameFilterText`）で
  `panes.showSearch(carrying:)` を呼ぶ。項目を作るとき、`(field.cell as? NSSearchFieldCell)?.searchButtonCell` の `target` を `self`、`action` を `showSearch(_:)` にし、
  アクセシビリティのラベルに `ToolbarShortcutText.text(.toolbarNameFilterFindHelp)` を付ける。`validateMenuItem(_:)` で `showSearch(_:)` の項目に `canSearch` を返す（FR-390・FR-392、R8）
  - 注記（2026-11-13）: 検索欄の文字はモデルの絞り込みと同じなので、モデルの文字（`fileList.currentNameFilterText`）を使う
- [x] T026 [US82] `Sources/FolzioApp/Search/ToolbarSearchField.swift` に、(1) 虫眼鏡の矩形（`searchButtonRect(forBounds:)`）と残りの部分に別々のツールチップを付ける処理
  （文言を受け取る2つのプロパティ。`layout()` と文言の変更で `removeAllToolTips()` の後に `addToolTip(_:owner:userData:)` で付け直す）、
  (2) `weak var findCommandTarget: AnyObject?` と、`showSearch(_:)` のセレクタのときだけそれを返す `supplementalTarget(forAction:sender:)` の上書きを加える。
  ファイル操作のセレクタは転送しない。`MainToolbarController` が項目を作るときと `displayLanguageDidChange()` で文言と `findCommandTarget` を設定する（FR-390・FR-392・EC-257、R8・R10）

## Phase 5: User Story 83 - キーボードだけで絞り込む (P2)

**Goal**: ⌥⌘F とメニューで検索欄へ移れる

**Independent Test**: quickstart.md の 4

- [x] T027 [US83] `Sources/FolzioApp/App/MainToolbarController.swift` に `var canFocusNameFilter: Bool`（ツールバーの項目に `nameFilter` があり、`displayMode` が文字だけでない）と
  `func focusNameFilter()`（検索欄を first responder にして全選択する）を加える。あわせて、絞り込みを解除する3つの時点を加える: ツールバーを利用者が隠したとき、
  `toolbarDidRemoveItem(_:)` で `nameFilter` が外れたとき、`displayMode` が文字だけになったとき。フルスクリーンでツールバーが自動で隠れる経路では解除しないことをコードで確かめる
  （FR-391・FR-393・EC-258、R11・R12）
  - 注記（2026-11-13）: 全画面でのツールバーの自動の非表示は表示オプション（`.autoHideToolbar`）で行い、`NSToolbar.isVisible` を変えない。
    そのため `isVisible` が偽になったときだけ解除すれば、全画面では絞り込みを保つ（EC-258）。外したときの解除は、
    並び替えで外して入れ直す場合に解除しないよう、1回遅らせてツールバーに検索欄が残っていないかを確かめる
- [x] T028 [US83] `Sources/FolzioApp/App/MainSplitViewController.swift` に `@objc func filterByName(_ sender: Any?)` を加える。`paneCommands.canSearch` とツールバーの `canFocusNameFilter` を確かめ、
  ツールバーが隠れていれば表示してから `focusNameFilter()` を呼ぶ（ツールバーのコントローラへの経路は、既存の `onPaneLayoutChange` などと逆向きのクロージャか弱参照で持つ）。
  `validateMenuItem(_:)` に同じ条件を加える（FR-391、R11）
- [x] T029 [US83] `Sources/FolzioApp/App/MainMenu.swift` の「ファイル」メニューの「検索…」の直後に「名前で絞り込む」（`menuFileFilterByName`、`action` は `filterByName(_:)`、`target = nil`、
  既定のキー ⌥⌘F）を加え、割り当ての対応の一覧（`(searchItem, .find)` のある箇所）と表示言語の切り替えの更新に加える（FR-391）

## Phase 6: User Story 84 - 検索欄を含むツールバーを自分の並びにする (P3)

**Goal**: 文字だけの形式とあふれたメニューで検索のモーダルが開き、カスタマイズと保存が既存の規則で働く

**Independent Test**: quickstart.md の 6

- [x] T030 [US84] `Sources/FolzioApp/App/MainToolbarController.swift` の項目に `menuFormRepresentation`（名前 `toolbarNameFilterLabel`、`action` `showSearch(_:)`、`target` `self`）を設定し、
  `displayLanguageDidChange()` で名前を更新する（FR-392）
- [x] T031 [US84] 並びの保存と復元（`restoreSavedConfiguration()`・`saveConfiguration()`）が、`nameFilter` を含む並びと含まない並びで既存の規則のまま働くことをコードで確かめる。
  コードの変更が要らなければ、その旨をこのタスクに注記する（FR-393、R14）
  - 注記（2026-11-13）: コードの変更は要らなかった。`saveConfiguration()` は `ToolbarLayout.defaultOrder` と比べて保存を決め、
    `restoreSavedConfiguration()` は `ToolbarLayout.normalized(saved:)` の結果をそのまま並べる。既定の並びは T021 でデリゲートと同じものになった

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T032 `scripts/dev/check-all.sh` を実行して成功させる（Cloud の検査。docs_private/cloud-agent-workflow.md の 5 章）。T034・T036 の後にも、それぞれもう一度実行する
  - 結果（2026-11-13）: 実装・T034 の文書・性能の修正の後に実行し、いずれも成功した。T036 の後にもう一度実行する
- [x] T033 作業ブランチに push し、CI で `swift build` と `swift test` の成功を確かめる。性能テストは `continue-on-error` なので、ログの末尾で件数と T015 の結果を確かめる
  - 結果（2026-11-13）: [run 43357234870](https://github.com/yoshidax/folzio-dev/actions/runs/43357234870)（`de33779`）で `swift build` と通常のテスト 1,217 件が成功した。
    性能テストは 28 件中 27 件が成功し、名前の絞り込みは最も遅い 1 文字で 64ms（基準 100ms）。
    失敗した 1 件は既存の「24MP の JPEG を 0.5 秒以内にデコード」（0.71 秒）で、この変更はデコードに触れていない。
    別のブランチの [run 43247851486](https://github.com/yoshidax/folzio-dev/actions/runs/43247851486) でも同じテストが 1.0 秒で失敗しており、共有ランナーのぶれと判断した。
    途中の 2 回の実行では、テストの誤り 1 件（T004 のテスト）と、絞り込みの性能の超過（108ms。T015 の注記）を直した
- [x] T034 ユーザーガイドと開発の手順書を更新する。日本語と英語を同じコミットで同じ内容にする。
  - `docs/usage.ja.md`・`docs/usage.md` の「ツールバー」に検索欄（既定で右端、カスタマイズで動かせる）を加える。「名前の検索」の前後に、検索欄での絞り込み
    （入力のたびに反映、`..` は残る、一覧が替わると解除、検索との違い）と、虫眼鏡でキーワードを引き継いでモーダルを開けることを書く。
    「ショートカット一覧」の「検索」の表に ⌥⌘F を加え、変更できるコマンドの数を書いている箇所があれば直す
  - `docs/development.ja.md`・`docs/development.md` の手動の確認に、絞り込み・解除・虫眼鏡・⌥⌘F を加える
  - README（`README.md`・`README.ja.md`）に検索やツールバーの機能の一覧があれば、両方を同じ内容で直す
  - 公開用リポジトリへ書き出される文書なので、`specs/`・`docs_private/` へリンクしない（AGENTS.md の「書くときの規則」）
- [ ] T035 [MANUAL] 保守者に quickstart.md の GUI 確認（0〜8）を依頼し、結果を `checklists/validation.md` に記録する。確認されるまでこのタスクは未チェックのまま残す。
  未確認の点（research.md の R6・R8・R10・R11・R12）で動かないものがあれば、research.md の代替へ直して再び確認を依頼する
- [x] T038 GUI 確認（T035）の指摘を直す（2026-11-13 の保守者の報告。`checklists/validation.md`）
  - 指摘: (1) 検索欄に 1 文字入力するとフォーカスがファイルリストへ移る、(2) 日本語の入力を始めた瞬間にフォーカスが移り、検索欄に戻っても入力できない、
    (3) 虫眼鏡を押しても検索のモーダルが開かず、(2) と同じ状態になる
  - 原因: `FileListViewController.isEditingText` が、ツールバーの検索欄での入力も名前の変更として数えていた（research.md の R13 の訂正）。
    `canSearch` が偽になり、FR-388 の処理が入力中の検索欄を無効にしたため、編集が終わってフォーカスが移った。虫眼鏡も、押した時点で編集が始まり同じく無効になった
  - 修正: 判定を `FileListViewController.isRenaming(firstResponder:)` に分け、ツールバーの検索欄の編集を除く。回帰テスト `Tests/FolzioAppTests/ToolbarSearchFieldEditingTests.swift`
  - 確認: CI の後に、保守者に quickstart.md の 1〜5 を再び確かめてもらう（T035）
- [ ] T036 最新の `origin/master` を取り込み、`scripts/dev/check-spec-ids.sh` を実行してから、spec.md の「反映先」の表のとおり `specs/product/file-list.md`・`window-layout.md`・
  `contracts/settings.md`・`contracts/keyboard-and-menus.md`・`contracts/localization.md` へ反映する（`specs/product/README.md` の「書き方のルール」に従う。
  ID の定義は1文にし、条件は子項目に分ける。feature の中だけの参照は製品仕様に残さない。コマンドの数（32）を書いているほかの箇所も合わせる。GUI 確認で変わった点があれば、その結果で直してから移す）。
  反映の後に `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-all.sh` を実行し、反映した項目と差分を保守者に示して承認を得てからコミットする
- [ ] T037 反映が終わったら、spec.md の冒頭に移行済み・凍結の注記を入れる（`specs/product/README.md` の「feature の spec.md の書き方」）

## Dependencies & Execution Order

- T003（設計の承認）→ Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7
- Phase 2: T004 → T005。T008 → T009 → T010 → T011。T012 は T005・T006・T007・T011 の後
- Phase 3: T013 → T014 → T015。T016 は T014 の後。T018 → T019 → T020 → T021 → T022 → T023（同じファイル）。T019 は T016 の後
- Phase 4: T024 → T025。T026 は T018 の後で、T025 と合わせて働く
- Phase 5: T027 → T028 → T029
- Phase 6: T030 は T025 の後（`showSearch(_:)` を使う）
- Phase 7: T032・T033 は Phase 6 の後。T034 は Phase 6 の後。T035 は T033 の後。T036・T037 は PR の最後の作業（docs_private/cloud-agent-workflow.md の 7 章）

## Parallel Example

```text
T004（NameFilterTests.swift）・T006（ToolbarSearchInput）・T007（ToolbarLayout）は並行できる
```

Cloud ではサブエージェントで実装を分けない（AGENTS.md）。上の並行は順序の制約がないことを示すだけで、1 つのセッションで順に行う。

## Implementation Strategy

- MVP は Phase 2〜3（US81）。検索欄での絞り込みだけで価値がある
- まず Core の型・並び・コマンド・文言（T004〜T011）を CI で確かめ（T012）、次にモデルの絞り込み（T013〜T015）を CI で確かめてから、App の変更を User Story の順に行う
- Cloud には Swift がないため、コンパイルの誤りは CI でしか見つけられない。AppKit の API の名前（`searchButtonCell`・`searchButtonRect(forBounds:)`・
  `supplementalTarget(forAction:sender:)`・`control(_:textView:doCommandBy:)`・`hasMarkedText()`・`toolbarDidRemoveItem(_:)`）は、使う前に既存のコードか公開の文書で確かめる
  （docs_private/cloud-agent-workflow.md の 4 章）
