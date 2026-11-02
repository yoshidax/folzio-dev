# Tasks: ツールバーのボタンセット単位のカスタマイズ

**Input**: `specs/TAK-23-toolbar-reorder/` の spec.md、plan.md、research.md、data-model.md、contracts/toolbar-labels.md、quickstart.md。

**Prerequisites**: 設計は承認済み（2026-11-02。英語ラベルの案も承認）。保守者の macOS は 26.6.2（25G83）。

**Tests**: Core の並び順の正規化（R-3 の段2・3 を採った場合）とローカライズ整合性を自動検証する。AppKit の挙動は quickstart.md の実機検証で記録する。

**Organization**: US1=並び替え、US2=セットの分離不可、US3=並び順・構成の保存、US4=標準のカスタマイズ機能の許容（FR-009・010 のラベルとツールチップを含む）。
Cloud は Issue 単位のため全タスクを順次実行し、[P] は使用しない。

**担当の表記**: 【Cloud】Agent が編集・Cloud の検査で完了できる。【実機】保守者の macOS でのみ確認できる。【CI】macOS の CI でビルド・テストを確認する。
Cloud では `swift build`・`swift test`・GUI を実行しない（AGENTS.md）。

## Phase 1: Setup

- [x] T001 【Cloud】`specs/TAK-23-toolbar-reorder/research.md` の R-3 に、保守者の macOS が 26.6.2（25G83）であること、および Apple Forums の displayMode の不具合は macOS 26 beta 2 で修正済みのため OS 固有の既知不具合の可能性は下がる（ただし項目の並びは別の事象で、この版でも再現している）ことを追記する。
- [ ] T002 【実機】SDK のヘッダー `NSToolbar.h` で `configuration` と `setConfiguration(_:)` に `API_DEPRECATED` が付くかを確認し、結果を `specs/TAK-23-toolbar-reorder/research.md` の R-1 の「未確認」に追記する（保守者に依頼。段2 を採るか決める入力になる）。

## Phase 2: Foundational（すべてのストーリーの前提）

**復元の段0 を最初に行う。** 結果で、T005 の分岐（段1・2・3 のどれを実装するか）が決まる。

- [ ] T003 【Cloud】`Sources/FolzioApp/App/MainToolbarController.swift` と `Sources/FolzioApp/App/MainWindowController.swift` に、**一時的な**診断ログを追加する。`allowsUserCustomization = true` と `autosavesConfiguration = true` を有効にした状態で、起動直後の `toolbar.items` の識別子を、`MainToolbarController.init` の後、`window.toolbar` 割り当ての直後、次の run loop（`DispatchQueue.main.async`）の3点で `NSLog` に出す。ログの接頭辞は `[TAK-23 spike]`。ログは `#if DEBUG` で囲み、T005 で必ず取り除く。`allowsUserCustomization = true` と `autosavesConfiguration = true` の設定は T009 の変更と同じ内容なので残す（取り除くのはログだけ。`autosavesConfiguration` は T005・T009 で最終の値にする）。
- [ ] T004 【実機】保守者がローカルで `swift build` を行い（コンパイルエラーがあれば共有する）、`scripts/make-app.sh` でビルドし、(a) カスタマイズして並び替え、(b) 終了、(c) 再起動して `[TAK-23 spike]` のログ3点を確認する。結果（3点の識別子の並び）を `specs/TAK-23-toolbar-reorder/research.md` の R-3 に記録する。`defaults read local.folzio.Folzio "NSToolbar Configuration MainToolbar"` の出力も併記する。
- [ ] T005 【Cloud】T004 の結果で復元の方式を決め、`specs/TAK-23-toolbar-reorder/research.md` の R-3 と `plan.md` の Phase 1-3 に「採用した段」と根拠を記録する。T003 の診断ログを取り除く。分岐は次のとおり:
  - ログで、`window.toolbar` 割り当て後は保存した並びで、その後に既定へ戻る → 戻す処理を特定して直す（段1）。T012〜T013 は不要
  - ログで、割り当て後から既定の並び（読み込みが効かない） → T002 の結果が非推奨でなければ段2（T012）。非推奨なら段3（T013）
  - 段2 を実装して直らなければ、段3 へ進む（T012 の変更は取り除く）
- [ ] T006 【Cloud】`Sources/FolzioApp/App/MainToolbarController.swift` の状態管理を作り直す（R-2、plan Phase 1-1）。(1) `historyControl`・`paneLayoutControl`・`mediaTypeFilterControl`・`zipVisibilityControl`・`viewModeControl`・`previewZoomControl`・`slideshowButton`・`sizeItem`・`previewZoomItem` のプロパティを廃止し、`toolbar.items` から識別子で項目を引き `view` を取り出すアクセサ（例: `control(for:)`）に置き換える。(2) `itemForItemIdentifier` は呼ばれるたびに新しい項目と control（サムネイルサイズのスライダーも項目ごとに新規）を返し、`willBeInsertedIntoToolbar == true` のときだけ現在の状態を適用する。`false` のときは状態を適用せず参照も保持しない。(3) `toolbarWillAddItem` と `toolbarDidRemoveItem` で、その識別子の状態を再適用する。`toolbarWillAddItem` の時点では項目がまだ `toolbar.items` に入っていない見込みなので、通知の `userInfo["item"]`（`NSToolbarItem`）の `view` へ直接適用するか、次の run loop で `toolbar.items` から引き直して適用する（アクセサだけに頼らない）。(4) `sizeSlider` のプロパティも廃止し、`init` にある初期設定（`minValue`・`maxValue`・`isContinuous`・`controlSize`・`target`・`action`・ツールチップ・アクセシビリティ・幅 120pt の制約）を、スライダーを生成する側へ移す（項目ごとに新規作成する。制約は `addSubview` の後に有効化する）。(5) `apply(...)`・`applyHistoryAvailability`・`applyZoomAvailability`・`NSToolbarItemValidation`・`displayLanguageDidChange` を、アクセサ経由に書き換える。`toolbar.items` に該当がなければ何もしない。コメントは英語で書く（AGENTS.md）。**この後、保守者がローカルで `swift build` を実行して結果を共有する**（Cloud は Swift をコンパイルできず、CI は PR の作成時にしか動かないため、コンパイルエラーの早期発見のチェックポイントとする）。
- [ ] T007 【Cloud】`Sources/FolzioCore/Settings/ToolbarLayout.swift` を新規に追加し（T005 で段2・3 を採った場合）、data-model.md の `ToolbarLayout` を実装する。`allowed`（8種＋`NSToolbarSpaceItem`・`NSToolbarFlexibleSpaceItem` の識別子文字列）、`defaultOrder`（history, paneLayout, slideshow, previewZoom, mediaTypeFilter, zipVisibility, viewMode, thumbnailSize, NSToolbarFlexibleSpaceItem）、`normalized(saved:)`（「空配列・未知の識別子・型が配列でない値は、既定の並びを返す」「スペース類は複数回出現してよい」）。Core は AppKit を import しない。段1 を採った場合はこのタスクを行わない。
- [ ] T008 【Cloud】`Tests/FolzioCoreTests/ToolbarLayoutTests.swift` を新規に追加する（T007 を行った場合）。空配列・未知の識別子・重複・スペースの複数回・型違いの値で、`normalized(saved:)` が data-model.md の規則どおりであることを検証する。期待値は data-model.md から照合し、実装の値をそのまま期待値にしない。

## Phase 3: US1 ボタンセットをドラッグして並び替える (P1 / MVP)

**Goal**: セットをドラッグして並び替えられ、動作・状態が保たれる（FR-001・004・006）。

**Independent Test**: quickstart Q1〜Q3。

- [ ] T009 【Cloud】[US1] `Sources/FolzioApp/App/MainToolbarController.swift` の `init` で `allowsUserCustomization = true` にし、`toolbarAllowedItemIdentifiers` に `.space`・`.flexibleSpace` を含めた8種＋スペースを返す。`toolbarDefaultItemIdentifiers` は現行の順序（FR-006）のまま。`autosavesConfiguration` は T005 の結果で決める（段1 なら有効、段2・3 なら無効にして自前で保存する）。
- [ ] T010 【実機】[US1] quickstart Q1〜Q3 を実施し、結果を `specs/TAK-23-toolbar-reorder/quickstart.md` の末尾に「実機検証の結果」として記録する。参照の不具合（R-2）は AppKit の挙動のため単体テストに向かない。再現と修正の確認は、Q1〜Q3 で代える（憲章 IV の「UI の見た目そのものの自動テストは必須としない」に基づく）。外して戻す・「デフォルトセット」の入れ直しの後も、履歴・ペイン・種類・zip・表示形式・サイズの状態が追従することを確認する。

## Phase 4: US2 セット内のボタンは分離できない (P1)

**Goal**: セット内のボタンを分離して配置できない（FR-002）。実機で確認済み（セットは1つの項目）。重複追加の扱いを確定する。

**Independent Test**: quickstart Q2。

- [ ] T011 【実機】[US2] 同じセットを複数回ツールバーへ追加できるかを確認し、結果を `specs/TAK-23-toolbar-reorder/research.md` の R-4 に記録する。
- [ ] T011a 【Cloud】[US2] T011 で追加できると分かった場合だけ、`Sources/FolzioApp/App/MainToolbarController.swift` のアクセサを、識別子で見つかるすべての項目に同じ状態を適用する形に拡張する。追加できない場合は変更なし。

## Phase 5: US3 並び順を次回の起動でも保つ (P2)

**Goal**: 並び順と構成（削除したセット、スペース、表示モード）が再起動後も復元される。不正な保存値では既定の並びで起動する（FR-005）。

**Independent Test**: quickstart Q5・Q6。

- [ ] T012 【Cloud】[US3] （T005 で段2 を採った場合）`Sources/FolzioCore/Settings/SettingsStore.swift` に `view.toolbarConfiguration`（plist 化した辞書）の読み書きを追加し、`MainWindowController.swift` で、カスタマイズ画面が閉じたとき（`NSWindow.didEndSheetNotification`）とアプリの終了時に `toolbar.configuration` を保存し、`window.toolbar` 割り当て後に `setConfiguration(_:)` で復元する。`isVisible` は `view.showsToolbar` を正とし、復元の前後で除く。保存値の識別子は `ToolbarLayout.normalized(saved:)` で検証し、不正なら既定の構成で起動する。`autosavesConfiguration` は無効にする。
- [ ] T013 【Cloud】[US3] （T005 で段3 を採った場合）`SettingsStore.swift` に `view.toolbarItems`（識別子の配列）の読み書きを追加し、`MainWindowController.swift` で、カスタマイズ画面が閉じたときとアプリの終了時に `toolbar.items` の識別子を保存し、起動時に `ToolbarLayout.normalized(saved:)` の結果で `insertItem` により並べ直す。表示モードも `toolbar.displayMode` を保存して復元する（FR-005。保存の有無は T014 の結果に依らず必須）。`autosavesConfiguration` は無効にする。
- [ ] T014 【実機】[US3] quickstart Q5・Q6 を実施する。並び順と構成が復元され、保存値を壊した状態（`defaults write local.folzio.Folzio` で不正値を書く）でも起動できることを確認し、結果を `specs/TAK-23-toolbar-reorder/quickstart.md` に記録する。

## Phase 6: US4 標準のカスタマイズ機能の許容とラベル・ツールチップ (P3)

**Goal**: 削除・再追加・スペース・表示モードの変更が標準のまま使え、ラベルとツールチップが FR-009・010 に揃う。

**Independent Test**: quickstart Q4・Q6〜Q8。

- [ ] T015 【Cloud】[US4] `Sources/FolzioApp/App/MainToolbarController.swift` の `init` で `allowsDisplayModeCustomization = true` にする（FR-003c）。`displayMode` の既定は `.iconOnly` のままにする。
- [ ] T016 【Cloud】[US4] `Sources/FolzioLocalization/TextKey.swift` と `Sources/FolzioLocalization/Resources/{en,ja}.lproj/Localizable.strings` に、`contracts/toolbar-labels.md` の新規キー（`toolbar.slideshowLabel`・`toolbar.zipFilesLabel`・`toolbar.thumbnailSizeLabel`・`toolbar.goBackHelp`・`toolbar.goForwardHelp`・`toolbar.showFileListOnlyHelp`・`toolbar.showPreviewOnlyHelp`・`toolbar.showImagesOnlyHelp`・`toolbar.showVideosOnlyHelp`・`toolbar.zipFilesHelp`）を、日英の文言とともに追加する。既存の `toolbar.history`・`toolbar.panes`・`toolbar.zoomGroup`・`toolbar.mediaType`・`toolbar.viewMode`・`toolbar.thumbnails`・`toolbar.list`・`toolbar.thumbnailSize` の値を表のとおりに変える。`toolbar.size`（サイズバーのラベル）と `menu.*` は変えない。各キーの用途を `TextKey` の説明（英語）に追加する。
- [ ] T017 【Cloud】[US4] `Sources/FolzioApp/App/MainToolbarController.swift` で、ラベルを T016 の新キーに差し替え、セグメントのツールチップとアクセシビリティのラベル・ヘルプを `contracts/toolbar-labels.md` のツールチップのキーに差し替える。メニューの文言（`menu.go.back` など）とは共用しない。`displayLanguageDidChange` の対応表も同じキーに更新する。
- [ ] T018 【CI】[US4] PR の作成後（保守者の依頼があるとき）、CI で `swift build` と `swift test` を確認する。`CatalogConsistencyTests`（日英のキー一致、`TextKey` の説明）と `ToolbarLayoutTests`（T008 を行った場合）が通ることを確認する。
- [ ] T019 【実機】[US4] quickstart Q4・Q6〜Q8 を実施し、日英のラベルとツールチップが `contracts/toolbar-labels.md` と一致することを確認する。テキスト表示のときのセグメントの幅とラベルの破綻、ウィンドウを最小幅まで狭めたときの溢れの扱いも確認する。結果を `specs/TAK-23-toolbar-reorder/quickstart.md` に記録する。あわせて Q9（スライドショー実行中・名前の変更中・全画面中にカスタマイズを開いたときの挙動。標準のまま制限しない方針のため、破綻がないかを確認する）を実施する。

## Phase 7: Polish & 検証ゲート（最後）

- [ ] T020 【Cloud】`docs/usage.md` と `docs/usage.ja.md` にツールバーの記述（ラベル・並び替え）があれば、新しいラベルとカスタマイズの方法に更新する。両言語を同じコミットで揃える。公開版のガイドから `specs/` などへのリンクは張らない（AGENTS.md）。
- [ ] T021 【Cloud】検証ゲートの Cloud 分を実行する: `scripts/check-no-network.sh`、`scripts/check-readme-sync.sh master`、`scripts/dev/check-english-comments.sh`、`scripts/dev/check-skill-sync.sh`。失敗したら直す。
- [ ] T022 【実機】保守者がローカルで起動スモーク（3ペインの表示、ツールバーのカスタマイズの一巡）を行う。結果を `specs/TAK-23-toolbar-reorder/quickstart.md` に記録する。省略して「CI が通ったから完了」にしない（AGENTS.md）。
- [ ] T023 【Cloud】実装と検証が終わったら、`git fetch origin master` して `git merge origin/master` で最新の master を取り込み、`specs/product/` へ反映する（plan.md Phase 1-5）。`window-layout.md` の FR-051・089・114・134、`contracts/keyboard-and-menus.md` の「ツールバー」、`contracts/settings.md`（保存の内容と不正値の扱い）、ローカライズの領域、新しい FR を追加する。FR の ID が他の feature と衝突したら、まだマージされていない側が振り直す。この feature の spec.md の冒頭に「移行済み」の注記を入れ、凍結する。反映の差分を保守者に示し、承認後にコミットする。
- [ ] T024 【Cloud】保守者が PR の作成を依頼したら、PR を作り、`TAK-23` の Linear に PR のリンクを追加して `In Review` に更新する。`Done` は、保守者のマージ後の依頼があるときだけ行う（AGENTS.md）。

## Dependencies & Execution Order

- Phase 1 → Phase 2 の T003〜T005（段0 の spike と分岐）→ T006（状態管理の作り直し。US1〜US4 すべての前提）→ T007〜T008（段2・3 を採った場合）→ Phase 3〜6 → Phase 7
- T006 は T003〜T005 と独立に着手できるが、Cloud の順次実行のため T005 の後に行う
- US1（T009〜T010）は T006 に依存。US3（T012〜T014）は T005 の分岐と T007 に依存。US4 のラベル（T016〜T017）は T006 に依存し、US1 と独立に進められる
- T023（`specs/product/` への反映）は、T019・T022 の実機確認が終わってから

## Implementation Strategy

1. MVP は Phase 2 の T003〜T006 と US1（T009〜T010）。ここで、カスタマイズしても状態が壊れないことと、並び替えができることを確かめる
2. 復元（US3）は、段0 の結果で最小の方式を選ぶ。直った時点で下の段は実装しない
3. 実機での確認は、保守者への依頼回数を減らすため、T004・T010・T014・T019・T022 の結果を `quickstart.md` にまとめて返してもらう
4. 見送り基準（spec.md）に当たる事態（独自のカスタマイズ画面が要る、セットが分離できる、ツールバーの作り直しが要る）が分かったら、作業を止めて保守者へ報告する
