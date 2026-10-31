# Tasks: メディア表示区画のダブルクリックによる全画面の切り替え

**Input**: `specs/TAK-19-media-double-click-fullscreen/` の spec.md、plan.md、research.md、data-model.md、contracts/、quickstart.md。

**Prerequisites**: 設計レビューの承認前には実装しない。

**Tests**: spec.md の検証方針に従い、Core の判断に自動テストを付ける。AppKit・AVKit の挙動は quickstart.md の M1〜M8 で実機確認する。

**Organization**: US1 = US5-AS7〜9（通常表示からの全画面化）、US2 = US5-AS10〜12（全画面中の解除）。Cloud は Issue 単位のため、全タスクを順に行う。[P] は使わない。

## Phase 1: Setup

- [x] T001 設計レビューの承認を受け、承認日と承認者の判断を `specs/TAK-19-media-double-click-fullscreen/quickstart.md` の第5章に記録する。

## Phase 2: Foundational

- [x] T002 `Sources/FolzioCore/Model/PreviewDoubleClick.swift` に `PreviewContent.hasMedia` と `PreviewDoubleClick.togglesFullScreen(isFullScreen:hasMedia:isOverControl:)` を追加する。
  data-model.md の表のとおりとし、doc comment は英語で書く（FR-035・208、EC-141・142）。
- [x] T003 `Tests/FolzioCoreTests/PreviewDoubleClickTests.swift` で、`PreviewContent` の全 case の `hasMedia` と、判断の表の全組み合わせを検証する。
  期待値は data-model.md の表から書き、実装の値をそのまま期待値にしない（EC-141・142）。

## Phase 3: US1 通常表示で画像・動画をダブルクリックして全画面にする (P1 / MVP)

**Goal**: 画像と動画のどちらでも、余白を含むプレビュー領域のダブルクリックで全画面にする。コントロールとスクロールバーは除く。

**Independent Test**: quickstart.md の M1〜M4・M7。

- [x] T004 [US1] `Sources/FolzioApp/Preview/PreviewViewController.swift` で、`containerView` に `NSClickGestureRecognizer`（2回、`delaysPrimaryMouseButtonEvents = false`）を取り付け、
  `onDoubleClick` を `imageView` への転送から自身のプロパティに改める。`NSGestureRecognizerDelegate` の `gestureRecognizer(_:shouldAttemptToRecognizeWith:)` で、
  ヒットしたビューから `containerView` までに `NSControl` があれば認識しない（FR-208、EC-142、research.md の R1・R2）。
- [x] T005 [US1] `Sources/FolzioApp/Preview/ImagePreviewView.swift` から `doubleClickRecognizer`・`onDoubleClick`・`handleDoubleClick(_:)` を削除する（plan.md の Phase 1 の 5）。
- [x] T006 [US1] `Sources/FolzioApp/App/MainSplitViewController.swift` の `onDoubleClick` の処理で、`PreviewDoubleClick.togglesFullScreen(isFullScreen: isFullScreenPresentation, hasMedia: model.preview.hasMedia, isOverControl: false)`
  が true のときだけ `togglePreviewFullScreen()` を呼ぶ。⌃⌘F・メニュー・Esc の経路は変えない（EC-141、A-121）。

**Checkpoint**: US5-AS7〜9 を実機で示せる状態。CI と実機の確認の前は完了にしない。

## Phase 4: US2 全画面のどこをダブルクリックしても戻す (P1)

**Goal**: 全画面中は画面のどこのダブルクリックでも解除し、全画面前の表示に戻る。スライドショー中は FR-122 のとおり。

**Independent Test**: quickstart.md の M1・M2・M5・M6。

- [x] T007 [US2] T004〜T006 の変更で、全画面中にプレビューが画面全体を占め、メディアの周りの余白・四隅でも認識されることを、`MainSplitViewController` の全画面の表示
  （`PanePresentation` の全画面でツリーとファイルリストを隠す）と `PreviewViewController` の制約から確かめる。覆わない領域が見つかれば、その領域を認識の対象に加える（FR-208（2））。
  結果: 全画面ではツリーとファイルリストの項目を折りたたみ（`MainSplitViewController.swift` の `canCollapse = true`・`isCollapsed = true`）、プレビューが残る。
  折りたたんだペインの細い仕切り（`dividerStyle = .thin`）が画面の端に残るかは実機でしか分からないため、quickstart.md の M1（画面の四隅）で確かめる。
  AGENTS.md の不変条件により split view の delegate には手を加えない。
- [x] T008 [US2] スライドショー中の全画面の切り替えと切り替え効果の表示中のダブルクリックが、既存の `togglePreviewFullScreen()` と全画面の通知の処理を通ることを、
  `SlideshowTransitionOverlayView` のヒットテストと `MainSplitViewController` の処理から確かめる（US5-AS12、EC-143、FR-122・131）。
  結果: `SlideshowTransitionOverlayView.hitTest(_:)` は nil を返すため、ヒットテストは下のプレビューに届き、認識は共通の祖先の `containerView` で受ける。
  切り替えは従来と同じ `togglePreviewFullScreen()` を通る。

## Phase 5: Polish & 検証

- [x] T009 `docs/usage.md`・`docs/usage.ja.md` の全画面の記述（機能一覧と操作の表）と、`docs/development.md`・`docs/development.ja.md` の起動スモークの全画面の項目を、
  画像と動画を含むメディアのダブルクリックに改める。英語版と日本語版を同じコミットで直す（research.md の R5）。
- [x] T010 Cloud の検査（quickstart.md の第1章）を実行し、結果を quickstart.md の第5章に記録する。
- [ ] T011 [MANUAL] 保守者の依頼で PR を作った後、macOS CI の `swift build`・`swift test`（性能テストのログを含む）の結果を確認し、quickstart.md の第5章に記録する。
- [ ] T012 [MANUAL] 保守者に起動スモークと quickstart.md の M1〜M8 を依頼し、報告を受けて quickstart.md の第5章に記録する。M2・M3 が期待どおりでなければ、作業を止めて方式を相談する。
- [ ] T013 実装と検証の後、最新の master を取り込み、spec.md の「反映先」の項目を `specs/product/preview.md` と `specs/product/contracts/keyboard-and-menus.md` へ反映し、
  ID の重複がないことを確かめ、feature の spec.md に移行済み・凍結の注記を入れる。差分を保守者に示し、承認を得てからコミットする。

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 → T013。T004 と T005 は同じコミットに入れる（片方だけでは二重に切り替わるか、画像で反応しなくなる）。
