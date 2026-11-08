# Tasks: TAK-85 スワイプのジェスチャで履歴を戻る・進む

**Input**: `specs/TAK-85-swipe-history-navigation/` の設計文書

**Prerequisites**: spec.md / plan.md / research.md / data-model.md / contracts/swipe-history-navigation.md / quickstart.md

**Tests**: Core の判定（`SwipeGestureTracker` の状態遷移・`HorizontalScrollRoom`・向きの対応・矢印の量）と、App の余地の読み取りに自動テストを付ける（憲章 原則 IV）。
ジェスチャそのものは合成できないため、保守者がローカルで確認する（quickstart.md）。実装は保守者の設計承認の後に行う。

**注意**: Cloud では `swift` を実行できない。build とテストは、作業ブランチに push した後、CI（`macos-swift-ci.yml` の `workflow_dispatch`、
または PR の作成後の自動の実行）で確かめる（docs_private/cloud-agent-workflow.md の 4・5 章）。

## Phase 1: Setup

- [x] T001 `specs/TAK-85-swipe-history-navigation/spec.md` と `checklists/requirements.md` を作り、TAK-85 と保守者の決定（Clarifications）を記録する
- [x] T002 `plan.md`・`research.md`・`data-model.md`・`contracts/swipe-history-navigation.md`・`quickstart.md` に設計と検証方法を記録する
- [x] T003 保守者の設計レビューと実装の承認を得る。承認がなければ T004 以降に進まない（2026-11-08、5 回の設計レビューの後に保守者が承認）

## Phase 2: Foundational（Core の判定）

- [ ] T004 [P] `Tests/FolzioCoreTests/SwipeNavigationTests.swift` を作り、次をテストする（先に失敗させる）。
  - `HorizontalScrollRoom(visibleMinX:visibleMaxX:contentMinX:contentMaxX:)`: 内容が広く中央にあるとき両方 true、左端・右端に着いたとき片方だけ true、
    「差が 0.5pt 以下なら端に着いているとする」、内容が狭いとき両方 false（`none` と等しい）
  - 向きの対応（data-model.md の「向きの扱い」）: `scrollingDeltaX > 0` を `revealsLeft`、`< 0` を `revealsRight`。`gestureAmount > 0` を `back`、`< 0` を `forward`。
    3 本指の `deltaX > 0` を `back`、`< 0` を `forward`、0 は nil。戻る・進むの向きは既存の `HistoryDirection` を使う
  - `NSEvent.Phase` 相当の値の対応: `.stationary` は `changed`、`.mayBegin` は `ignored`（状態を変えずに `passThrough`）
  - `SwipeGestureTracker`: `began` → 左右が主の `changed` で、余地なし・どちらかの向きが使えるなら `startSwipe` を 1 回だけ返し、その後の同じ 1 回のイベントは `consume`
  - `began` のイベント自体に左右が主の動きがあるときは、そのイベントで同じ判定をする（`startSwipe` または `passThrough`）
  - `began` の余地がその向きにあれば、その 1 回の終わりまで `passThrough`。途中のイベントの余地が変わっても（端に着いても）`passThrough` のまま（US7-AS19）
  - 次の `began` で、端に着いた余地を記録し直せば `startSwipe` になる（US7-AS20）。反対の向き（余地あり）は `passThrough`
  - 上下が主（|deltaY| >= |deltaX|）の最初の動きでは、その 1 回は `passThrough`（EC-239）。左右・上下とも 0 のイベントでは向きを決めない
  - `isMomentum` のイベント、`phase` が `none` のイベント、`began` を受け取っていないイベントは `passThrough`
  - `isSwipeTrackingEnabled` が false、または `canGoBack`・`canGoForward` がどちらも false のときは `passThrough`（FR-350・US7-AS21）
  - `finishSwipe()` の後は `afterSwipe` になり、同じジェスチャの慣性のイベントは `consume`。慣性でない `phase` なしのイベント（マウスホイール）は `passThrough` で `idle` に戻る。
    次の `began` から判定する
  - `began` で `room` が `nil`（対象の外）なら、その 1 回は終わりまで `passThrough`。`began` 以外のイベントでは `room` を使わない
  - `pending` のまま動きなしで `ended` / `cancelled` を受け取ると `idle`。`pending` で `phase` が `none` のイベント（左右が主でも）は `passThrough` で、`startSwipe` にしない
  - `scrolling` の後に `phase` なしのマウスホイールのイベントが来ても `passThrough`
  - `swiping` の間の、慣性でない `ended` / `cancelled` は `passThrough`。それ以外は `consume`
  - `scrolling` でビューへ渡した慣性のイベントの `timestamp` から 0.1 秒以内に、同じペインで受け取った `began` は、余地がなくても `scrolling`（`startSwipe` にしない）。
    0.1 秒を超えた `began` は通常どおり判定する
  - `swiping`・`afterSwipe` で `consume` した慣性の直後（0.1 秒以内）の `began` は、通常どおり判定して `startSwipe` になる（EC-241。連続したスワイプを妨げない）
  - 別のペインの慣性の直後（0.1 秒以内）の `began` は、通常どおり判定する
  - 余地が `none` のペイン（縦だけの一覧）の慣性の直後（0.1 秒以内）の `began` は、通常どおり判定して `startSwipe` になる
  - `target` が `nil`（対象の外）で始めたスクロールの慣性は覚えず、その直後の `began` は通常どおり判定する
  - `swiping` のまま（`finishSwipe()` の前）に次の `began` を受け取ったら、判定し直す（EC-241。前の追跡が終わらなくても状態が残らない）
  - `SwipeArrowState(gestureAmount:)`: `progress` は `abs(gestureAmount)` を 0〜1 に収める。正は `back`（左端）、負は `forward`（右端）。0 では `isVisible` が false
- [ ] T005 [P] `Tests/FolzioCoreTests/PreviewScrollLayoutTests.swift` に、`horizontalRoom(viewportWidth:)` のテストを加える（先に失敗させる）。
  横にはみ出す画像で中央・左端・右端のとき、はみ出さない画像のとき、不正な寸法（`frame` が `.zero`）のとき
- [ ] T006 `Sources/FolzioCore/History/SwipeNavigation.swift` を作り、data-model.md の `ScrollReveal`・`HorizontalScrollRoom`・`ScrollSample`・`SwipeAvailability`・
  `SwipeTarget`（既存の `Pane` と `HorizontalScrollRoom` の組）・`SwipeGestureTracker`（`handle(_:availability:target:)`）・`SwipeDecision`・`SwipeArrowState` と、向きの対応の関数を実装して T004 を通す。戻る・進むの向きは既存の `HistoryDirection`
  （`Sources/FolzioCore/History/HistoryEntry.swift:97`）を使い、同じ名前の型を新しく作らない。AppKit を import しない。型は `Sendable`・`Equatable` にする
- [ ] T007 `Sources/FolzioCore/Layout/PreviewScrollLayout.swift` に `horizontalRoom(viewportWidth:) -> HorizontalScrollRoom`（`frame.minX < 0` で左、`frame.maxX > viewportWidth` で右。
  T006 の 0.5pt の規則を使う）を加えて T005 を通す
- [ ] T008 作業ブランチに push し、CI（`workflow_dispatch`、`ref` は作業ブランチ）で build と Core のテストを確かめる

## Phase 3: 先に行う確認（実機での追跡と向き）

- [ ] T009 `Sources/FolzioApp/App/SwipeNavigationController.swift` を作り、確認用の最小の版を実装する（矢印なし、余地は常に `none`）。
  - `NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe])` を 1 つ置き、`MainSplitViewController.viewDidLoad()` から作る。
    既存の `installVideoSeekKeyMonitor()`（`MainSplitViewController.swift:839`）と同じく `MainActor.assumeIsolated` で処理し、ビューが消えたらモニタを外す
  - 1 回のスクロールの `began`（と 3 本指の `.swipe`）のときだけ、メインウインドウのイベント・メインウインドウがキーウインドウ（`window.isKeyWindow`）・シートとモーダルがない・ポインタの下のビューが 3 ペインのビュー
    （`treeViewController.view`・`fileListViewController.view`・`previewViewController.view`）の中、を判定する（EC-244・EC-245）。
    対象の中なら、そのペイン（既存の `Pane`）と余地を `SwipeTarget` として渡し、対象の外なら `nil` を渡す。`began` 以外のイベントは判定せずに `SwipeGestureTracker` に渡す（data-model.md の規則）。`treeViewController`・`previewViewController` は `private` のため、
    3 つのビューと、使えるかどうか・`goBack`・`goForward` は、`MainSplitViewController` から init の引数（ビューの配列とクロージャ）で渡す
  - `.scrollWheel` は `SwipeGestureTracker` に渡し、`startSwipe` で `trackSwipeEvent(options: [.lockDirection, .clampGestureAmount], dampenAmountThresholdMin:max:)`
    を呼ぶ。min は `canGoForward ? -1 : 0`、max は `canGoBack ? 1 : 0`（R1・R7）。`.ended` で、最後の `gestureAmount` の符号の向きの `goBack(_:)` / `goForward(_:)`
    を呼ぶ（使えるかの再判定はその guard に任せる。EC-240）。`.cancelled` で何もしない。`isComplete` で `finishSwipe()`
  - 追跡ごとに通し番号を振り、次の `began` で判定し直した後に届いた前の追跡の handler の呼び出しは無視する（data-model.md の規則）
  - `trackSwipeEvent` の handler は MainActor と宣言されていないクロージャのため、中の処理（`goBack(_:)`・`goForward(_:)`・`finishSwipe()`・矢印の更新）は、
    モニタと同じく `MainActor.assumeIsolated` で包む（Swift 6 の並行性の検査）
  - `swiping` の間の同じジェスチャの `ended` / `cancelled` はビューへ渡す（data-model.md）。確認用に、それがモニタに届いたかを `NSLog` で出す（Q4）
  - `.swipe` は `deltaX` の対応で `goBack(_:)` / `goForward(_:)` を呼ぶ（R2）。その向きが使えて実行したときだけモニタで `nil` を返してイベントを捨て、
    対象の外・使えない向き・`deltaX` が 0 のときはそのまま渡す
  - 使えるかどうかは `paneCommands.canNavigateHistory && historyNavigator.canGoBack`（`canGoForward`）で求める（R7）
  - `NSEvent.isSwipeTrackingFromScrollEventsEnabled` をイベントごとに読み、`SwipeAvailability.isSwipeTrackingEnabled` に渡す（FR-350。再起動なしで設定の変更が反映される）
  - 確認用に、向き・`gestureAmount`・`phase`・`deltaX` を `NSLog` で出す（T012 で消す）
- [ ] T010 push し、CI で build とテストを確かめる
- [ ] T011 [MANUAL] 保守者に、quickstart.md の「先に行う確認」（Q1〜Q3）を T009 の版で実行してもらい、結果を `checklists/validation.md` に記録する。
  Q1 が動かなければ research.md R3 の代わり（`NSWindow` のサブクラスの `sendEvent(_:)`）に切り替える方針を保守者に確かめる。
  Q2・Q3 の向きが逆なら、T006 の対応と T004 のテストを直す。結果に合わせて research・data-model を直してから T012 に進む

## Phase 4: User Story 1 - スワイプで前に見ていたフォルダへ戻る・進む (P1)

**Goal**: 3 ペインの上で、システム設定の「ページ間をスワイプ」のスワイプで戻る・進むができ、スワイプの間は矢印が出て、指を戻せば取り消せる

**Independent Test**: quickstart.md の「基本」

- [ ] T012 [US1] T009 の確認用の `NSLog` を消す
- [ ] T013 [US1] `Sources/FolzioApp/App/SwipeArrowOverlay.swift` を作る（R6）。
  - 枠なし・透明・`ignoresMouseEvents`・影なしの子ウインドウを作る。表示するたびに、メインウインドウに `addChildWindow(_:ordered: .above)` で付け、
    その時点の `splitView` の画面上の範囲にフレームを合わせる。隠すときは `removeChildWindow(_:)` してから `orderOut` する（`orderOut` で親から外れるため。R6）。
    ウインドウとビューの操作は MainActor で行う（AGENTS.md）
  - 矢印のビュー: 円の背景に SF Symbols の `chevron.left` / `chevron.right`。文字を含まない。アクセシビリティの要素にしない
  - `SwipeArrowState` の `progress` で大きさと不透明度を変える。`back` は左端に左向き、`forward` は右端に右向き。`isVisible` が false の間は出さない（FR-352）
  - 消すときは短いフェード。`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` が true ならフェードせずに消す
  - 3 本指のスワイプでは、`progress` 1 で短い時間（0.3 秒程度）だけ表示する（EC-242）
  - 子ウインドウは `NSSplitView` とペインのビューに部品を加えない（AppKit UI の不変条件）
- [ ] T014 [US1] `SwipeNavigationController.swift` の `trackSwipeEvent` の handler から `SwipeArrowOverlay` を更新し、`.ended` / `.cancelled` と `isComplete` で消す（FR-352・US7-AS16）。
  新しい `began` で判定し直すときも、矢印を消す（前の追跡の終わりが届かなくても残さない）。
  3 本指のスワイプでは、その向きが使える（`canGoBack` / `canGoForward`）ときだけ、短く表示してから `goBack(_:)` / `goForward(_:)` を呼ぶ（FR-352・US7-AS21）
T015 は欠番（設定の読み取りは、確認用の版でも要るため T009 に含めた）。

## Phase 5: User Story 2 - 横スクロールとぶつからない (P1)

**Goal**: その向きにまだ横スクロールできる間は横スクロールを優先し、端に着いた状態で始めたスワイプだけを戻る・進むにする

**Independent Test**: quickstart.md の「横スクロールとの区別」

- [ ] T016 [P] [US2] `Tests/FolzioAppTests/SwipeScrollRoomTests.swift` を作り、次をテストする（先に失敗させる）。
  - 文書のビューが広い `NSScrollView` で、`contentView.scroll(to:)` で左端・中央・右端にしたときの余地
  - 文書のビューが狭い `NSScrollView` の余地が `none`
  - `ImagePreviewView` が画像を表示していないとき `none`
  - 3 ペインのルートより上にはたどらない（ルートの外の `NSScrollView` を使わない）
- [ ] T017 [US2] `Sources/FolzioApp/Preview/ImagePreviewView.swift` に `HorizontalScrollRoomProviding` の適合を加え、`scrollLayout.horizontalRoom(viewportWidth: bounds.width)` を返す
  （画像を表示していないとき・横にはみ出さないときは `none`。R5）。動画のビューは適合させず、余地は `none` のままにする（EC-246）
- [ ] T018 [US2] `SwipeNavigationController.swift` に、ポインタの位置で `hitTest` したビューから 3 ペインのルートまで上へたどり、
  （`hitTest(_:)` は superview の座標を取る。`PreviewViewController.swift:580-583` と同じく、`event.locationInWindow` を各ペインのルートの superview の座標に
  変換してから呼ぶ）最初に見つかった `HorizontalScrollRoomProviding` または
  `NSScrollView` の余地を求める関数を加え、`began` のイベントで `SwipeTarget` の余地として `SwipeGestureTracker` に渡して T016 を通す（FR-351・EC-243・A-208）。
  `HorizontalScrollRoomProviding` は `Sources/FolzioApp/App/SwipeNavigationController.swift` に置く

## Phase 6: User Story 3 - 使えないときは何も起きない (P2)

**Goal**: ⌘[ / ⌘] が使えない状態では、スワイプでも矢印が出ず、何も起きない

**Independent Test**: quickstart.md の「使えないとき」

- [ ] T019 [US3] `SwipeNavigationController.swift` で、追跡を始めるときの `SwipeAvailability` が min / max に正しく渡り（使えない向きは 0）、使えない向きには矢印が出ないこと、
  `.ended` では `goBack(_:)` / `goForward(_:)` の guard だけで再判定していること（Core に同じ条件を重ねない）を確かめる（FR-112・EC-240・US7-AS21。data-model.md）。検索結果の表示中の「戻る」が `historyNavigator.canGoBack` で使え、「進む」が使えないこと（FR-113・US7-AS22）を
  コードで確かめ、`goBack(_:)` の既存の経路を通ることをコメントに書く
- [ ] T020 [US3] `SwipeNavigationController.swift` の対象の判定で、`window.isKeyWindow`（設定・ショートカット一覧・Quick Look などが前面のときは false）・
  `window.attachedSheet`・`NSApp.modalWindow`・イベントのウインドウ・ペインの境界線とツールバーの除外
  （ポインタの下のビューが 3 ペインのビューの中にないとき）を確かめる（EC-244・EC-245）。ドラッグ＆ドロップの途中は扱わない（EC-244）。
  ドラッグの途中は、`NSEvent.pressedMouseButtons` が 0 でないとき、または Folzio のビュー（ツリー・リスト形式・サムネイル形式）から始めたドラッグのセッションの途中
  （`Sources/FolzioApp/Shared/InternalDrag.swift` に、セッションの開始と終了で切り替える印を加える）とする（R7）

## Phase 7: Polish

- [ ] T021 [P] `docs/usage.ja.md` と `docs/usage.md` の「フォルダ移動とお気に入り」に、戻る・進むの手段（⌘[・⌘]・ツールバーの `<`・`>`・「移動」メニュー・スワイプ）と、
  スワイプはシステム設定の「ページ間をスワイプ」に従うこと、拡大した画像などの横スクロールは端に着いてから改めてスワイプすることを、同じ内容で書く（R9。同じコミットで両方）
- [ ] T022 新しいソースのコメントを英語で書いたこと（公開用リポジトリへ書き出すコード。`docs_private/comment-translation-glossary.md`）と、`specs/`・`docs_private/` へのリンクがないことを確かめる
- [ ] T023 `scripts/dev/check-all.sh` を実行し、通ることを確かめる
- [ ] T024 push し、CI で build・通常のテスト・性能テスト（ログの末尾で `passed` / `failed` を確かめる）を確かめる
- [ ] T025 [MANUAL] 保守者に、起動スモークと quickstart.md の「手動の確認」をすべて実行してもらう。確認されるまで GUI のタスク（T013・T014・T017〜T020）の完了を報告しない
- [ ] T026 保守者が PR を依頼したら、`.github/pull_request_template.md` の見出しで PR を作り、Linear の TAK-85 に PR のリンクを加えて `In Review` にする（docs_private/agents/linear.md）
- [ ] T027 PR の最後に、`git merge origin/master` で最新の `master` を取り込み、`scripts/dev/check-spec-ids.sh` で ID の衝突を確かめる（衝突したら `docs_private/spec-id-conflicts.md`）。
  spec.md の「反映先」の表のとおり `specs/product/navigation-history.md` と `specs/product/contracts/keyboard-and-menus.md` に反映し、
  `python3 scripts/dev/check-spec-format.py` と `scripts/dev/check-spec-ids.sh` を実行する。反映した項目と差分を保守者に示し、承認を得てからコミットする。
  反映後、spec.md の冒頭に移行済み・凍結の注記を入れる

## Dependencies

- T003（承認）→ Phase 2 → Phase 3（実機の確認。T011 の結果で Core を直すことがある）→ Phase 4・5・6 → Phase 7
- Phase 4・5・6 は、どれも `SwipeNavigationController.swift` を変えるため、順に行う（US1 → US2 → US3）
- T027 は PR の最後（docs_private/cloud-agent-workflow.md の 7 章）

## Parallel Example

- Phase 2: T004（`SwipeNavigationTests.swift`）と T005（`PreviewScrollLayoutTests.swift`）は別のファイルで、同時に書ける
- Phase 5: T016（App のテスト）は T017・T018 の前に、別のファイルで書ける
- Phase 7: T021（文書）は T022〜T024 と独立

## Implementation Strategy

- MVP は Phase 2〜4（US1）。横スクロールのない一覧（サムネイル形式・ツリー）の上では、これだけで要望の中心が使える
- US2 を入れるまでは、拡大した画像の上で横スクロールより戻る・進むが先になるため、US1 と US2 は同じ PR に含める（どちらも P1）
- Cloud では build とテストを CI で、ジェスチャを保守者の実機で確かめる。T011 の結果で設計が変わる場合は、保守者に確かめてから進める
