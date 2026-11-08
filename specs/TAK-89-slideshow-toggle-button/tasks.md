# Tasks: TAK-89 スライドショーのボタンを開始・停止のトグルにする

**Input**: `specs/TAK-89-slideshow-toggle-button/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/toolbar-slideshow-toggle.md / quickstart.md

**Tests**: Core の判断（`SlideshowToggleState`）に真理値表のテストを、文言に翻訳の検査を付ける（憲章 原則 IV、R8）。
ボタンの見た目・クリック・あふれたメニュー・VoiceOver は保守者がローカルで確認する。実装は保守者の設計承認の後に行う。

## Phase 1: Setup

- [x] T001 `specs/TAK-89-slideshow-toggle-button/spec.md` と `checklists/requirements.md` を作り、TAK-89 と保守者の決定（Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/toolbar-slideshow-toggle.md`・`quickstart.md` に設計と検証方法を記録する
- [x] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない

## Phase 2: Foundational（判断と文言）

- [x] T004 [P] `Tests/FolzioCoreTests/SlideshowToggleStateTests.swift` を作り、6 つの入力（`canStart`・`isActive`・`isRestoring`・`hasSheet`・`hasAppModal`・`isEditingText`）の
  64 通りで、`isOn` が「`isActive && !isRestoring`」、`action` が「`isOn` なら `.stop`、それ以外は `.start`」、`isEnabled` が
  「`isOn` なら `!hasSheet && !hasAppModal && !isEditingText`、それ以外は `canStart && !isRestoring`」であることをテストする（data-model.md、FR-350〜FR-352。先に失敗させる）。
  あわせて、実行中（`isActive` が真、`isRestoring` が偽）の `isEnabled` が、同じ入力で `isTargetWindowKey: true` とした `SlideshowInputPolicy.acceptsKeys` と一致することを確かめる（A-209）
- [x] T005 `Sources/FolzioCore/Slideshow/SlideshowToggleState.swift` に `public struct SlideshowToggleState: Sendable, Equatable` と `public enum Action { case start, stop }` を実装して T004 を通す。
  実行中の `isEnabled` は、型の中で `SlideshowInputPolicy` に `isTargetWindowKey: true`・`menuOwnsInput: false` を渡した `acceptsKeys` で求め、3 つの条件を書き直さない。
  AppKit を import しない。コメントは英語で、要件の ID（FR-350〜FR-352）を書く（R1）
- [ ] T006 [P] `Sources/FolzioLocalization/TextKey.swift` に `toolbarStopSlideshowHelp = "toolbar.stopSlideshowHelp"` を加える。
  引数なし（`arguments` は既定の空）。翻訳者向けの説明を加える（「実行中のスライドショーのボタンのツールチップとアクセシビリティの説明。Esc は固定のキー」）。
  あわせて、同じファイルの翻訳者向けの説明で、`toolbarSlideshowLabel` をグループ名の case から別の case に分け、
  「ツールバーのスライドショーの項目名。ボタンのアクセシビリティラベルを兼ね、VoiceOver が状態によらず読む」と書く（A-211。コードレビューの指摘）。
  `Sources/FolzioLocalization/Resources/ja.lproj/Localizable.strings` に「スライドショーを停止（Esc）」、
  `Sources/FolzioLocalization/Resources/en.lproj/Localizable.strings` に `Stop Slideshow (Esc)` を加える（FR-353、R6、contracts）
- [ ] T007 `Tests/FolzioCoreTests/Localization/ShortcutSettingsTextTests.swift` に、T006 のキーが両言語で訳され、`%` を含まず、引数がないことのテストを加える
  （既存の `plainTextsAreTranslated` と同じ方法。別の配列 `toolbarPlainKeys` にする）
- [ ] T008 作業ブランチに push し、CI（`macos-swift-ci.yml`。PR がなければ `workflow_dispatch` で作業ブランチを指定）で `swift build` と `swift test` の成功を確かめる。
  Cloud には Swift がないため、Core の型（T005）と文言（T006）を App の変更の前に確かめ、失敗の原因を App の変更と切り分ける（Implementation Strategy）。
  失敗したらログを読んで直し、Phase 3 に進まない

## Phase 3: User Story 77 - ツールバーのボタンでスライドショーを止める (P1)

**Goal**: 同じボタンで開始と停止ができ、ボタンのオン・オフが実行状態と一致する

**Independent Test**: quickstart.md の 1〜9

- [ ] T009 [US77] `Sources/FolzioApp/App/MainSplitViewController.swift` に `var slideshowToggleState: SlideshowToggleState` を加える。入力は data-model.md の表のとおり
  （`canStart: canStartSlideshow`、`slideshowCoordinator.isActive`・`isRestoring`、`view.window?.attachedSheet != nil`、`NSApp.modalWindow != nil`、`fileListViewController.isEditingText`）。
  ウインドウがないときは、`canStart` を false とし、シートなしとして計算する（R1）
- [ ] T010 [US77] 同じファイルに `@objc func toggleSlideshow(_ sender: Any?)` を加える。押した時点で `slideshowToggleState` を計算し直し、`isEnabled` でなければ何もしない。
  `.start` なら `startSlideshow(sender)`、`.stop` なら `slideshowCoordinator.stop()` を呼ぶ。Esc の受理の関数（`handleSlideshowEscapeFallback`）は使わない
  （キー入力先の条件を含むため。FR-351・FR-352・EC-239、R3）。`startSlideshow(_:)` と `validateMenuItem` の `startSlideshow` の扱いは変えない（SC-189）
- [ ] T011 [US77] `Sources/FolzioApp/App/MainToolbarController.swift` のボタンの生成（`slideshowIdentifier` の case）で、`button.setButtonType(.pushOnPushOff)` にし、
  ボタンとツールバー項目の target を `self`、action を新しい `@objc private func slideshowToggled(_:)` にする。`slideshowToggled` は `panes.toggleSlideshow(sender)` を呼んだ後、
  `updateSlideshowAvailability()` でボタンの `state` を実際の実行状態で上書きする（R2）
- [ ] T012 [US77] 同じファイルに `applySlideshowState(to item: NSToolbarItem)` を加え、`panes.slideshowToggleState` から、項目の `isEnabled` とボタンの `isEnabled`
  （両方に設定する。文字だけの形式は項目を使うため。既存の `applyZoomAvailability(to:)` と同じ）、ボタンの `state`（オンなら `.on`）、
  アクセシビリティラベル（どちらの状態でも `toolbarSlideshowLabel`。A-211）、ツールチップとアクセシビリティの説明（オフ `ToolbarShortcutText.text(.toolbarStartSlideshowHelp)` /
  オン `l10n.text(.toolbarStopSlideshowHelp)`）、項目の `toolTip` を適用する。項目の `label`・`paletteLabel` は `toolbarSlideshowLabel` のまま（FR-350・FR-353）。
  `applyState(to:)`・`updateSlideshowAvailability()`・`validateToolbarItem(_:)`・文言の更新のループ（164 行付近）の slideshow の処理を、この関数を呼ぶ形にする（R4）
- [ ] T013 [US77] 同じファイルで、ツールバー項目に `menuFormRepresentation` を設定する（名前 `toolbarSlideshowLabel`、action `slideshowToggled(_:)`、target `self`）。
  `MainToolbarController` を `NSMenuItemValidation` に適合させ、`validateMenuItem(_:)` で `slideshowToggled` の項目に `state`（オンなら `.on`）を設定し、`isEnabled` を返す。
  文言の更新で項目の名前も更新する（EC-240・A-210、R7）
- [ ] T014 [US77] 同じファイルに、メインウインドウの `NSWindow.willBeginSheetNotification` と `NSWindow.didEndSheetNotification` の監視を加え、
  `DispatchQueue.main.async` で 1 回遅らせて `updateSlideshowAvailability()` を呼ぶ（通知の時点ではシートがまだ付いていない恐れがあるため。分析の C2）。
  監視は `editingObservers` と同じく保持し、ウインドウは `panes.view.window` が決まった後の時点（監視の対象は `object` にそのウインドウ）で登録する。
  登録の時点でウインドウがなければ、`object: nil` で受けて、通知のウインドウがメインウインドウのときだけ処理する（FR-352・US77-AS6、R5）

## Phase 4: Polish & Cross-Cutting Concerns

- [ ] T015 `scripts/dev/check-all.sh` を実行して成功させる（Cloud の検査。docs_private/cloud-agent-workflow.md の 5 章）。
  T018・T019 の後にも、それぞれもう一度実行する（仕様の ID の検査と公開用の書き出しの検査を含むため。コードレビューの指摘）
- [ ] T016 作業ブランチに push し、CI（`macos-swift-ci.yml`。PR がなければ `workflow_dispatch`）で `swift build` と `swift test` の成功を確かめる。性能テストはログの末尾で件数を確かめる
- [ ] T017 [MANUAL] 保守者に quickstart.md の GUI 確認（1〜10）を依頼し、結果を `checklists/validation.md` に記録する。確認されるまでこのタスクは未チェックのまま残す
- [ ] T018 ユーザーガイドと開発の手順書を更新する。日本語と英語を同じコミットで同じ内容にする（コードレビューの指摘。TAK-74 の T021 と同じ扱い）。
  - `docs/usage.ja.md`・`docs/usage.md` の「スライドショー」の「開始と操作」（182 行付近）: ツールバーの再生ボタンは、実行中はオンになり、もう一度押すと終了することを加える。
    「スライドショー中は」の項目の Esc の終了に、ツールバーのボタンでも終了できることを加える
  - 同じ 2 つのファイルのショートカットの表「スライドショーと動画」（`docs/usage.ja.md` の 433 行付近）の「スライドショーを開始／終了」の行に、
    ツールバーのボタンが終了にも使えることを書く
  - `docs/development.ja.md`・`docs/development.md` の手動の確認「スライドショー」（117 行付近）に、ツールバーのボタンで開始と終了ができ、ボタンのオン・オフが実行状態と一致することを加える
  - 公開用リポジトリへ書き出される文書なので、`specs/`・`docs_private/` へリンクしない（AGENTS.md の「書くときの規則」）
  - 更新の後に `scripts/dev/check-all.sh` を実行して成功させてからコミットする
- [ ] T019 最新の `origin/master` を取り込み、`scripts/dev/check-spec-ids.sh` を実行してから、spec.md の「反映先」の表のとおり（FR-114・FR-134 の変更を含む）`specs/product/preview.md`・`window-layout.md`・
  `contracts/keyboard-and-menus.md`・`contracts/localization.md` へ反映する（`specs/product/README.md` の「書き方のルール」に従う。
  1行が160桁を超える文は分け、feature の中だけの参照（research.md の節など）は製品仕様に残さない。GUI の確認で未確認の項目（R9）が決まっていれば、その結果で直してから移す）。
  反映の後に `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-all.sh`（`check-spec-ids.sh` を含む）を実行し、反映した項目と差分を保守者に示して承認を得てからコミットする
- [ ] T020 反映が終わったら、spec.md の冒頭に移行済み・凍結の注記を入れる（`specs/product/README.md` の「feature の spec.md の書き方」）

## Dependencies & Execution Order

- T003（設計の承認）→ Phase 2 → Phase 3 → Phase 4
- Phase 2: T004 → T005。T006 → T007。T004 と T006 は別のファイルなので並行できる。T008 は T005・T007 の後
- Phase 3: T009 → T010 → T011 → T012 → T013。T014 は T012 の後（`updateSlideshowAvailability()` の変更を使う）
- Phase 4: T015・T016 は Phase 3 の後。T017 は T016 の後。T018 は Phase 3 の後。T019・T020 は PR の最後の作業（docs_private/cloud-agent-workflow.md の 7 章）

## Parallel Example

```text
T004（SlideshowToggleStateTests.swift）と T006（TextKey.swift・Localizable.strings）は並行できる
```

Cloud ではサブエージェントで実装を分けない（AGENTS.md）。上の並行は順序の制約がないことを示すだけで、1 つのセッションで順に行う。

## Implementation Strategy

- User Story は 1 つ（US77）だけで、MVP は Phase 2〜3 のすべて
- まず Core の判断と文言（T004〜T007）を CI で確かめ（T008）、次に App の変更をまとめて行い、CI と保守者の GUI 確認で確かめる
