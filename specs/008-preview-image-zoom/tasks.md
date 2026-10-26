---
description: "プレビュー画像の拡大・縮小 実装タスク"
---

# Tasks: プレビュー画像の拡大・縮小

**Input**: `specs/008-preview-image-zoom/` の spec.md・plan.md・research.md・data-model.md・contracts/preview-zoom.md・quickstart.md、spec が参照する `specs/product/` の領域（preview.md・window-layout.md・navigation-history.md・file-list.md・overview.md）と `specs/product/contracts/keyboard-and-menus.md`、憲章 v1.2.0。

**Prerequisites**: `008-preview-image-zoom` ブランチ。Swift 6 / macOS 15 以降 / AppKit / 単一 Swift Package。外部パッケージの追加なし。UserDefaults の新しいキーなし（倍率は保存しない）。

**Tests**: plan の Testing 方針と憲章 IV に従い、Core の倍率の加減・上下限・不正値、画像の同一性による復帰・履歴用の明示リセット・有効条件・フィットへの倍率適用を Swift Testing で自動テストする。テストを先に追加し、実装前に期待する失敗を確認する。ツールバーの見た目、メニューとキーの到達性、VoiceOver、実時間は `.app` の手動確認と Instruments（OS Signposts）で確かめる。

**Organization**: spec のユーザーストーリーは US14 の1つだけなので、Phase 3 を US14 の実装と受け入れ確認に充てる。Core の値型と純粋関数は、すべての入口（ツールバー・メニュー・ショートカット）が共有する前提として Phase 2 に置く。

## Format: `[ID] [P?] [Story] Description`

- `[P]`: 同じ Phase 内で、前提完了後に別ファイルとして並行処理できる候補。既定は順次実装。
- `[US14]`: spec.md の US14 との対応。Setup・Foundational・最終 Phase には付けない。
- 手動ゲートは `[US14] 手動:` または `手動:` と書き、ユーザーが GUI・VoiceOver・計測を行う。未実施なら未チェックに保つ。
- パスはリポジトリルートからの相対パス。新規ファイルは「新規」と明示する。

## Path Conventions

- Core: `Sources/MediaViewerCore/`（AppKit を import しない）
- App: `Sources/MediaViewerApp/`（MainActor で描画・入力・ウインドウを扱う）
- Fixtures: `Sources/FixtureKit/`、テスト: `Tests/MediaViewerCoreTests/`・`Tests/MediaViewerPerformanceTests/`
- 実装中に更新する設計文書は、本書のチェックと、タスクで明示した `specs/008-preview-image-zoom/quickstart.md` への追記だけ。`specs/product/` への反映は T033 まで行わない。

## 共通の実装・検証規則

- 倍率の判断は Core の値型（`PreviewZoom`・`PreviewZoomTracker`・`PreviewZoomAvailability`）と `FitCalculator.frame` に置き、`PreviewViewController` は表示との対応だけを持つ。Core は AppKit・Core Animation を import しない。
- 描画は既存の `ImagePreviewView` の `contentLayer.frame` を変えるだけにし、再デコード・`contents` の差し替え・アニメーションのやり直しをしない。スクロール・パン・ドラッグ・ピンチ・可視の数値表示・スライダー・画像ごとの倍率の記憶を追加しない（A-64）。
- 倍率は保存せず、`HistoryPresentation`・`HistoryViewState` に含めず、倍率変更を `HistoryNavigator.recordViewChange` に渡さない。100% はフィット表示であり原寸ではない（A-62）。
- 有効条件は FR-136 だけとし、シート・モーダル・名前の変更中・設定ウインドウをキーであることを条件に加えない（A-73）。
- 各 Phase 末尾のゲートは build → 全 test → no-network → bundle 作成 → ユーザーの起動スモーク → コミットの順。GUI の起動はユーザーに依頼し、未実施を合格・完了にしない。
- ゲートの結果は `specs/008-preview-image-zoom/quickstart.md` の末尾に「Phase 検証記録」の節を作って（既にあれば追記して）記録する。日付・コマンド結果・GUI 確認内容・未実施項目を書く。
- AppKit の禁止 split delegate override は追加しない。制約は `addSubview` の後に有効化し、異なる view hierarchy のアンカー同士を制約しない。レイヤーのモデル値の frame だけを変える。
- 並列実装を行う場合は、未コミットの変更を先にコミットまたは stash し、`008-preview-image-zoom` をベースに専用の worktree と `agent/<task-id>-<slug>` ブランチを作る。同じファイルを触るタスクは直列化する。

## Phase 1: Setup — 検証データと既存回帰の確認

**Purpose**: 手動確認と性能確認に使う `zoom/` の検証データを用意し、既存の回帰ゲートを通す。

- [X] T001 新規 `Tests/MediaViewerCoreTests/PreviewZoomFixtureTests.swift` に、`FixtureSets.zoom(in:)` が一時ディレクトリに `zoom/01-small-16.png`（16×16）・`zoom/02-tiny-1.png`（1×1）・`zoom/03-landscape-24mp.jpg`（6000×4000）・`zoom/04-portrait.png`（1200×2400）の4件を生成することを検査する Swift Testing を追加する。`ImageIO` の `CGImageSourceCreateWithURL` と `kCGImagePropertyPixelWidth` / `kCGImagePropertyPixelHeight` で画素サイズを確かめ、`defer` で一時ディレクトリを削除する（EC-82、SC-043、SC-048、quickstart.md「検証データ」）
- [X] T002 `Sources/FixtureKit/FixtureSets.swift` に `public static func zoom(in directory: URL) throws` を追加し、`makeAll(in:)` から呼ぶ。既存の `ImageFixtures.png` / `ImageFixtures.jpeg` を使い、`zoom/01-small-16.png`（16×16）・`zoom/02-tiny-1.png`（1×1）・`zoom/03-landscape-24mp.jpg`（6000×4000）・`zoom/04-portrait.png`（1200×2400）を生成する。既存の `mixed`・`slideshow`・`bigimage` などのファイル名・内容・生成順は変えない
- [X] T003 `scripts/make-fixtures.sh .build/PreviewZoomFixtures` を実行し、`.build/PreviewZoomFixtures/zoom/` に4件が生成されることとサイズを `ls` と `sips` で確認する。外部ツールの導入が必要になった場合は導入せずユーザーへ確認する。あわせて `specs/008-preview-image-zoom/quickstart.md` の「`FixtureSets.makeAll` に `zoom/` を追加する予定」を、実装した `FixtureSets.zoom(in:)` の記述に直す
- [X] T004 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/008-preview-image-zoom/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T005 手動: ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、3ペインが表示されること、既存のフィット表示、ツールバーの並び、⌘+ / ⌘- によるサムネイルサイズ変更、スライドショーの開始と Esc に回帰がないことを確認してもらう。結果を `specs/008-preview-image-zoom/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T006 直前の自動・GUI ゲート合格後、`Sources/FixtureKit/`・`Tests/MediaViewerCoreTests/PreviewZoomFixtureTests.swift`・`specs/008-preview-image-zoom/` の差分だけを確認して Phase 単位でコミットする（push は行わない）。注記: 全 Phase の自動ゲートと GUI 確認の合格後に、Phase ごとのコードのコミットとして `da87a8e` を作成した（設計文書の更新は最終コミットにまとめた）

**Checkpoint**: `zoom/` の検証データと既存の回帰ゲートが揃う。

## Phase 2: Foundational — 倍率の値型・状態・有効条件・フィット計算

**Purpose**: US14 のすべての入口が使う Core の判断ロジックと、既存フィット計算への倍率適用を用意する。UI と入力はまだ変えない。

**Blocking**: T007〜T017 完了後に US14 の App 接続へ進む。

- [X] T007 [P] 新規 `Tests/MediaViewerCoreTests/PreviewZoomTests.swift` に `PreviewZoom` のテストを追加する。`step == 25`・`minimum == 25`・`maximum == 800`・`fit.percentage == 100`。`init?(percentage:)` は 25・50・100・775・800 を受け付け、0・-25・30・101・799・801 を拒否する。`scale` は 25→0.25・100→1.0・800→8.0。`zoomedIn` は 100→125→150 と25ポイント加算し、800 では自分自身。`zoomedOut` は 150→125→100→75→50→25 と25ポイント減算し、25 では自分自身。`canZoomIn` は 800 で false・775 で true、`canZoomOut` は 25 で false・50 で true。`Comparable` の順序も固定する（FR-133、US14-AS1・AS2・AS7、EC-85、A-62、SC-043）
- [X] T008 [P] 新規 `Tests/MediaViewerCoreTests/PreviewZoomTrackerTests.swift` に `PreviewZoomTracker` のテストを追加する。初期値は `level == .fit`・`imageIdentity == nil`。`present(urlA)` で同一性が変わり true、同じ `urlA` の再提示は false で倍率を保つ。`zoomIn()` 後の `present(urlA)` は125%を保ち、`present(urlB)` は100%へ戻して true。`present(nil)` は空・動画・表示不能として100%へ戻し、続けて `present(nil)` は false。`reset()` は同じ URL のまま100%へ戻して true、100%で再度呼ぶと false で `imageIdentity` は保つ。`zoomIn` / `zoomOut` は上下限で false を返して値を変えない。`fit()` は125%から true、100%から false（FR-137、EC-87・EC-88、SC-047、data-model.md §2）
- [X] T009 [P] 新規 `Tests/MediaViewerCoreTests/PreviewZoomAvailabilityTests.swift` に `PreviewZoomAvailability` のテストを追加する。`isImageDisplayed == true && isPreviewVisible == true` のとき `isAvailable == true` で、100%では `canZoomIn`・`canZoomOut`・`canFit` がすべて true。800%では `canZoomIn == false`・`canZoomOut == true`・`canFit == true`。25%では `canZoomOut == false`・`canZoomIn == true`・`canFit == true`。`isImageDisplayed == false`（動画・空・表示不能）または `isPreviewVisible == false`（ファイルリストのみ表示）では、倍率にかかわらず3つとも false（FR-134・FR-136、US14-AS6、EC-85・EC-89、SC-046、data-model.md §3）
- [X] T010 [P] `Tests/MediaViewerCoreTests/FitCalculatorTests.swift` に `FitCalculator.frame(imageSize:in:zoom:)` のテストを追加する。`.fit` は既存の `fit(imageSize:in:)` と完全に同じ矩形（横長・縦長・小さい画像・1×1・ちょうど収まる画像）。`2000×1000` を `500×500` に置く場合、125%は `(-62.5, 93.75, 625, 312.5)`、50%は `(125, 187.5, 250, 125)`、800%は幅4000・高さ2000で原点が負。`1×1` を `500×500` で800%にすると幅・高さ4000・原点 `(-1750, -1750)`。画像またはコンテナが0以下なら `.zero`。丸めをしない（FR-028・FR-029・FR-133、EC-81・EC-82、SC-044）
- [X] T011 [P] 新規 `Tests/MediaViewerPerformanceTests/PreviewZoomPerformanceTests.swift` に、`6000×4000` の画像サイズと `1600×1200` のコンテナで32段（25%〜800%）すべての `FitCalculator.frame` を1000回ずつ（合計32,000回）計算し、`ContinuousClock` で1秒以内であることを検査するテストを追加する。デコード・描画・ファイルアクセスを含めない（SC-048、憲章 原則 II、research.md R10）
- [X] T012 新規 `Sources/MediaViewerCore/Layout/PreviewZoom.swift` に `public struct PreviewZoom: Sendable, Equatable, Comparable` を実装する。定数 `step = 25`・`minimum = 25`・`maximum = 800`・`fit = PreviewZoom(percentage: 100)!`、`public let percentage: Int`、`public var scale: CGFloat { CGFloat(percentage) / 100 }`。`init?(percentage:)` は「25以上800以下、かつ25の倍数」だけを許し、それ以外は nil。`canZoomIn` は `percentage < maximum`、`canZoomOut` は `percentage > minimum`。`zoomedIn()` は25加算して上限で自分自身、`zoomedOut()` は25減算して下限で自分自身を返す。`Comparable` は `percentage` で比較する。100%はフィット表示であり原寸ではない（FR-133、A-62、contracts/preview-zoom.md）
- [X] T013 `Sources/MediaViewerCore/Layout/PreviewZoom.swift` に T012 と同じファイルで `public struct PreviewZoomTracker: Sendable, Equatable` と `public struct PreviewZoomAvailability: Sendable, Equatable` を追加する。`PreviewZoomTracker` は `level: PreviewZoom = .fit`・`imageIdentity: URL?` を持ち、`present(_:) -> Bool` は同一性が変わったときだけ `.fit` に戻して true、同じなら false、`reset() -> Bool` は同一性を保ったまま `.fit` に戻して変更時 true、`zoomIn()` / `zoomOut()` / `fit()` は変更時 true を返す。`PreviewZoomAvailability` は `isImageDisplayed`・`isPreviewVisible`・`level` を持ち、`isAvailable == isImageDisplayed && isPreviewVisible`、`canZoomIn == isAvailable && level.canZoomIn`、`canZoomOut == isAvailable && level.canZoomOut`、`canFit == isAvailable`（FR-134・FR-136・FR-137、data-model.md §2・§3、T008・T009 を通す）
- [X] T014 `Sources/MediaViewerCore/Layout/FitCalculator.swift` に `public static func frame(imageSize: CGSize, in container: CGSize, zoom: PreviewZoom) -> CGRect` を追加する。既存の `fit(imageSize:in:)` を変えず、フィットの矩形を求め、その中心を保ったまま幅・高さを `zoom.scale` 倍し、原点を `((container.width - scaled.width) / 2, (container.height - scaled.height) / 2)` とする。画像またはコンテナが0以下なら `.zero`。整数丸めをしない。100%は既存の `fit` と一致させる（FR-028・FR-029・FR-133、EC-81、SC-043・SC-044、T010・T011 を通す）
- [X] T015 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/008-preview-image-zoom/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T016 手動: ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、3ペインが表示されること、既存のフィット表示・画像切替・サイズ変更・フルスクリーン・スライドショーに回帰がないことを確認してもらう（この時点では倍率の入口はまだない）。結果を `specs/008-preview-image-zoom/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T017 直前の自動・GUI ゲート合格後、`Sources/MediaViewerCore/Layout/`・`Tests/MediaViewerCoreTests/`・`Tests/MediaViewerPerformanceTests/PreviewZoomPerformanceTests.swift`・`specs/008-preview-image-zoom/` の差分だけを確認して Phase 単位でコミットする（push は行わない）。注記: 全 Phase の自動ゲートと GUI 確認の合格後に、Phase ごとのコードのコミットとして `968412d` を作成した（設計文書の更新は最終コミットにまとめた）

**Checkpoint**: Core の倍率・リセット判定・有効条件・フィットへの適用が単体テストで固定され、App から利用できる。

## Phase 3: User Story 14 — プレビュー画像を拡大・縮小する（P1）

**Goal**: プレビューに表示中の画像を、ツールバーの3ボタン（拡大・表示領域に合わせる・縮小）、「表示」メニューの3項目、⌘+・⌘-・⌘0（拡大は ⌘= でも可）で25%刻みに拡大・縮小する。画像は中央基準で縦横比を保ち、はみ出した部分は表示しない。動画・空・表示不能・ファイルリストのみ表示では無効。別の画像・履歴の移動後は100%、フルスクリーン・サイズ変更・同じ画像のままのペイン復帰では保つ。既存のサムネイルサイズ変更は ⌃⌘. / ⌃⌘, へ移す。

**Independent Test**: 画像を選択してプレビューに表示し、ツールバーの3ボタン、表示メニューの3項目、⌘+・⌘-・⌘0 で倍率が25%刻みに変わること、⌘= でも拡大すること、動画では無効になること、別の画像へ移ると100%に戻ること、フルスクリーンとプレビューのみ表示でも同じ操作ができること、⌃⌘. / ⌃⌘, がサムネイルサイズだけを変えることを確かめる（spec.md US14 の Independent Test）。

### Implementation for US14

- [X] T018 [US14] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` に倍率の描画とアクセシビリティを追加する。`private var zoom = PreviewZoom.fit`、`var isShowingImage: Bool { displayedImage != nil }`、`var onDisplayedImageChange: (() -> Void)?`、`func applyZoom(_ zoom: PreviewZoom, announce: Bool)` を追加する。`setup()` で `layer?.masksToBounds = true` にする。`layout()` の `fittedFrame()` を `FitCalculator.frame(imageSize:in:zoom:)` に置き換え、ピクセル空間で計算してから `backingScale` で割る（縦横比・中央配置を保ち、はみ出す場合は負の原点）。`onDisplayedImageChange` は `displayedImage` の `didSet`（`nil` と非 `nil` が入れ替わったとき）でまとめて呼ぶ。`setDisplayed(_:)` に加え、`showLoading`・`showEmpty`・`showUnavailable`・`showMessage`、およびフォールバックなしの `showAnimated` が `displayedImage = nil` を直接設定するため、呼び出し箇所を個別に列挙しない。そのうえで画像表示中だけアクセシビリティの値を `"125%"` の形式で公開し、画像がない状態では値を nil にする。`announce == true` かつ値が変わったときだけ `NSAccessibility.post(element:notification:.announcementRequested)` で新しい百分率を medium で読み上げる。倍率の変更で `contentLayer.contents`・`displayedImage`・アニメーションを変えず、再生をやり直さない（FR-138、EC-84、SC-048・SC-050、research.md R4・R8、contracts/preview-zoom.md）
- [X] T019 [US14] `Sources/MediaViewerApp/Preview/PreviewViewController.swift` に `private var zoomTracker = PreviewZoomTracker()` を追加し、`updateFromModel()` の各分岐で表示対象の同一性を `present` に渡す。`.image` は `model.selection.focused`、`.animatedImage(url)`・`.animatedImageData(url, _)`・`.loading(url)` はその URL、`.empty`・`.video`・`.unavailable` は nil。分岐の表示処理のあとに `imageView.applyZoom(zoomTracker.level, announce: false)` を適用し、アニメーションの最初のフレームが届いたときも適用する。`@discardableResult func zoomIn() -> Bool` / `zoomOut()` / `zoomToFit()` は `zoomTracker` を更新できたら `applyZoom(..., announce: true)` を呼んで true、変わらなければ false。`func resetZoom()` は `zoomTracker.reset()` の結果を `applyZoom(..., announce: false)` で反映する。`var zoomAvailability: PreviewZoomAvailability` は `imageView.isShowingImage`・`isPaneVisible`・`zoomTracker.level` から作り、`var onZoomAvailabilityChange: (() -> Void)?` を倍率・画像表示・ペイン表示の変化時に呼ぶ。`imageView.onDisplayedImageChange` を同じ通知に接続する。倍率の適用区間を既存の `OSSignposter`（`local.my-img-viewer.MediaViewer` / `Performance`）に `PreviewZoomApply` として記録し、ファイル名・パスを含めない。`transitionState`・スライドショーの期限・間隔には触れず、`HistoryNavigator.recordViewChange` を呼ばない（FR-133・FR-136・FR-137・FR-138、US14-AS5・AS8・AS10・AS15、EC-86〜EC-88、SC-047、research.md R3・R5・R9）
- [X] T020 [US14] `Sources/MediaViewerApp/App/MainSplitViewController.swift` に `var zoomAvailability: PreviewZoomAvailability { previewViewController.zoomAvailability }`、`@discardableResult func zoomIn() -> Bool` / `zoomOut() -> Bool` / `zoomToFit() -> Bool`、`func resetZoom()`、`var onZoomAvailabilityChange: (() -> Void)?` を追加し、`previewViewController` の同名 API へ中継する。`onZoomAvailabilityChange` は `previewViewController` の通知とペイン表示の変更で呼ぶ。`HistoryPresentationHost.applyHistoryPresentation(_:)` の末尾で `previewViewController.resetZoom()` を呼び、履歴の移動が成立したときだけ100%へ戻す（履歴の記録は増やさない）。`applyPanePresentation()` では倍率を変更しない（FR-137、EC-87・EC-88・EC-90、US14-AS15、contracts/preview-zoom.md「倍率のリセット」）
- [X] T021 [US14] `Sources/MediaViewerApp/App/MainWindowController.swift` に `var zoomAvailability: PreviewZoomAvailability { splitViewController.zoomAvailability }`、`@discardableResult func zoomIn() -> Bool` / `zoomOut()` / `zoomToFit()` を追加し、`splitViewController` へ中継する。これは `AppDelegate` のメニュー操作と検証のための入口に限る。`onZoomAvailabilityChange` は追加しない（ツールバーは T024 で `MainSplitViewController.onZoomAvailabilityChange` を直接購読する。closure は1つしか持てないため、ここで中継・設定すると上書きの競合になる）（FR-134・FR-136、contracts/preview-zoom.md「App 側の接続点」）
- [X] T022 [US14] `Sources/MediaViewerApp/App/AppDelegate.swift` に `@objc func previewZoomIn(_ sender: Any?)` / `previewZoomOut(_:)` / `previewZoomToFit(_:)` を追加し、`mainWindowController?.zoomIn()` などを呼ぶ。`NSMenuItemValidation` に準拠し、3つの action に対して `mainWindowController?.zoomAvailability.canZoomIn` / `canZoomOut` / `canFit` を返し、それ以外は true を返す。`MainMenu.install()` に自分を target として渡せるようにする（FR-135・FR-136、US14-AS16、A-73、research.md R7）
- [X] T023 [US14] `Sources/MediaViewerApp/App/MainMenu.swift` の `install()` を、倍率メニューの target を受け取る形（例: `install(zoomTarget: AppDelegate)`）に変え、`Sources/MediaViewerApp/App/AppDelegate.swift` の呼び出しを更新する。「表示」の「フルスクリーン」の下に区切り線を置き、その直後に「拡大」（keyEquivalent `+`、⌘）、「縮小」（`-`、⌘）、「表示領域に合わせる」（`0`、⌘）をこの順で追加し、target を渡された `AppDelegate` にする。同じ action・target を持つ非表示の `NSMenuItem`（keyEquivalent `=`、⌘、`isHidden = true`、`allowsKeyEquivalentWhenHidden = true`）も追加し、⌘= と ⇧⌘= で拡大できるようにする。`allowsKeyEquivalentWhenHidden` の既定は false で、設定しないと非表示の項目はキー等価に反応しない（research.md R7）。表示文言とツールチップは ⌘+ のまま変えない。既存の「スライドショーを開始」以降の並びは変えない（FR-135、US14-AS4・AS11・AS12、A-65・A-72、contracts/preview-zoom.md「表示メニュー」）
- [X] T024 [P] [US14] `Sources/MediaViewerApp/App/MainToolbarController.swift` に `previewZoomIdentifier` と `previewZoomControl` を追加し、`NSSegmentedControl`（`trackingMode = .momentary`、3セグメント、各幅36）を `NSToolbarItem` として実装する。画像は SF Symbols の `plus.magnifyingglass`（拡大）・`arrow.up.left.and.down.right.magnifyingglass`（表示領域に合わせる）・`minus.magnifyingglass`（縮小）を左から並べ、`toolbarDefaultItemIdentifiers` / `toolbarAllowedItemIdentifiers` では「スライドショーを開始」の右隣、種類フィルタの左に挿入する。各セグメントにアクセシビリティのラベル「拡大」「表示領域に合わせる」「縮小」とツールチップ「拡大（⌘+）」「表示領域に合わせる（⌘0）」「縮小（⌘-）」を付ける。`panes.zoomAvailability` から項目全体の `isEnabled` とセグメント単位の有効化を行い、`panes.onZoomAvailabilityChange` で更新する。`validateToolbarItem` に同じ判定を追加する。既存の `sizeSlider` のツールチップとアクセシビリティのラベルに「⌃⌘. / ⌃⌘,」を反映する。100%でも中セグメントを押された見た目にしない（FR-134・FR-045、US14-AS11、SC-049、A-61・A-65、research.md R6）
- [X] T025 [P] [US14] `Sources/MediaViewerApp/FileList/FileListViewController.swift` の `installViewMenuItems()` で「サムネイルを拡大」「サムネイルを縮小」の `keyEquivalentModifierMask` を `[.command, .control]` にして ⌃⌘. / ⌃⌘, に移す。`setupBottomBar()` の「サイズ」ラベルと `sizeSlider` のツールチップ／アクセシビリティのラベルに ⌃⌘. / ⌃⌘, を記す。`increaseThumbnailSize(_:)` / `decreaseThumbnailSize(_:)`・変更幅16ポイント・保存キー・`onViewChange?(.thumbnailSize)` の履歴記録は変えない。プレビューの倍率には触れない（FR-014・FR-135、US14-AS9・AS14、EC-89、SC-045・SC-051、A-63・A-69・A-74、contracts/preview-zoom.md「サムネイルサイズの移行」）。注記（2026-10-27）: 実装後の見直しで、キーを ⌃⌘+ / ⌃⌘- から ⌃⌘. / ⌃⌘, に変更した（keyEquivalent を `.` / `,` に変更。`+` は Shift を要し拡大だけ4キーになるため。A-74）。本文の ⌃⌘. / ⌃⌘, はこの変更を反映済み
- [X] T026 [US14] `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/008-preview-image-zoom/quickstart.md` の「Phase 検証記録」へ追記する
- [X] T027 [US14] 手動: ユーザーに `cd /Users/igachan/projects/my_img_viewer`、必要なら `scripts/make-fixtures.sh ~/MediaViewerFixtures`、`open .build/MediaViewer.app` の実行を依頼する。3ペインの表示を確認した後、`specs/008-preview-image-zoom/quickstart.md` の「手動シナリオ」1〜8 を確認してもらう。特に、ツールバーの3ボタンの並び・アイコン・ツールチップ、⌘+・⌘-・⌘0・⌘=（⌘= と ⇧⌘= は実キーで非表示項目に届くことを必ず確かめる）、25%〜800%の上下限、動画・空・破損画像・ファイルリストのみ表示での無効、別画像・履歴・フルスクリーン・ペイン復帰・スライドショーでのリセットと保持、⌃⌘. / ⌃⌘, のサムネイルサイズ、VoiceOver の値と読み上げ、シート・名前の変更中・設定ウインドウがキーのときの操作を記録する。結果を `specs/008-preview-image-zoom/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ
- [X] T028 [US14] 直前の自動・GUI ゲート合格後、`Sources/MediaViewerApp/`・`Tests/MediaViewerCoreTests/` の追加テスト・`specs/008-preview-image-zoom/` の差分だけを確認して Phase 単位でコミットする（push は行わない）。注記: 全 Phase の自動ゲートと GUI 確認の合格後に、Phase ごとのコードのコミットとして `07cdcd1` を作成した（設計文書の更新は最終コミットにまとめた）

**Checkpoint**: US14 が単独で機能し、ツールバー・メニュー・ショートカットの3入口が同じ倍率を変え、既存のサムネイルサイズ変更が ⌃⌘ に移っている。

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: 利用者向け文書を更新し、VoiceOver と実時間の証拠を揃え、Living spec へ反映して feature を凍結する。

- [X] T029 [P] `README.md` の機能一覧とキーボードの表を更新する。プレビュー画像の拡大・縮小（ツールバーの3ボタン、表示メニュー、⌘+ / ⌘- / ⌘0、⌘= でも拡大、25%〜800%の25%刻み、フィットが100%）、サムネイルサイズが ⌃⌘. / ⌃⌘, になったこと、画像を切り替えると100%へ戻ること、スクロール・パン・ピンチ・倍率の数値表示はないことを追記し、⌘+ / ⌘- がサムネイルサイズという古い記述を残さない（A-64・A-69、contracts/preview-zoom.md）
- [X] T030 最終の自動ゲートとして `swift build` → `swift test` → `swift test --filter MediaViewerPerformanceTests` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行する。`grep -rn "import AppKit" Sources/MediaViewerCore` が0件であること、`Sources/MediaViewerCore/Layout/PreviewZoom.swift` が AppKit・QuartzCore に依存しないことも確認する。結果を `specs/008-preview-image-zoom/quickstart.md` の「Phase 検証記録」へ追記する（憲章 原則 I・II・IV）
- [X] T031 手動: ユーザーに `open .build/MediaViewer.app` を依頼し、`specs/008-preview-image-zoom/quickstart.md` の「手動シナリオ」7（VoiceOver）を中心に、SC-049・SC-050 を確認してもらう。プレビューのアクセシビリティの値が実際の倍率と一致し、明示的な操作のたびに新しい百分率が読み上げられ、可視の倍率表示が出ないこと、画像切替・履歴の復帰では値を更新するが読み上げないこと、ツールバーの3セグメントのラベルとツールチップ、ライト・ダークの区別、画像がない状態で3操作が無効として読み上げられることを記録する。未実施なら未チェックに保つ
- [X] T032 手動: ユーザーに `open .build/MediaViewer.app` と Instruments（OS Signposts / Points of Interest）の実行を依頼し、SC-043・SC-044・SC-045・SC-046・SC-047・SC-048・SC-051・SC-052 を確認してもらう。24MP の JPEG で拡大・縮小・フィットを各10回、`PreviewZoomApply` の区間が0.5秒以内で UI が応答しない回数が0回であること、100%→800%→25%と20回繰り返して縦横比・中央配置・上下限が崩れないこと、3ペイン・プレビューのみ・フルスクリーン・シート・設定ウインドウ・名前の変更中でキーが届くこと、⌘+ / ⌘= / ⇧⌘= と ⌃⌘. / ⌃⌘, の使い分け、履歴の件数が変わらないことを記録する。結果と環境（macOS・機種・build 種別）を `specs/008-preview-image-zoom/quickstart.md` の「最終検証結果」へ追記する。未実施なら未チェックに保つ
- [ ] T033 T030〜T032 の自動・GUI・計測がすべて合格した場合に限り、`specs/008-preview-image-zoom/spec.md` の「反映先」の表どおり、`specs/product/preview.md`（FR-028・FR-029・FR-133〜FR-138、US14-AS1〜AS16、EC-81〜EC-90、SC-043〜SC-052、A-11・A-12・A-61〜A-75、表示倍率のエンティティ）、`specs/product/window-layout.md`（FR-134 のツールバー項目）、`specs/product/navigation-history.md`（FR-107 の倍率変更を記録しない旨と ⌘+ / ⌘- から ⌃⌘. / ⌃⌘, への読み替え、US8-AS7）、`specs/product/overview.md`（FR-045）、`specs/product/contracts/keyboard-and-menus.md`（ツールバーの並び・ラベル・有効条件、表示メニュー、プレビューの操作表、プレビューのみ表示／zip の中／検索結果のキー一覧、ファイルリストの ⌘+ / ⌘- 行、サイズのスライダー、メニューバー、⌘+ / ⌘- と ⌃⌘. / ⌃⌘, の使い分けの注記）へ全追加／変更 ID を移す。契約は参照で記載して ID 本文を重複定義せず、Clarifications は feature に残す。手順と ID の付け方は `specs/product/README.md` に従い、`specs/008-preview-image-zoom/spec.md` の冒頭へ移行済み・凍結の注記を付す（憲章「仕様の管理」）
- [ ] T034 `specs/008-preview-image-zoom/spec.md` の「反映先」の表と `specs/product/` の ID・リンク・契約を照合し、FR-028・FR-029・FR-133〜FR-138、US14-AS1〜AS16、EC-81〜EC-90、SC-043〜SC-052、A-11・A-12・A-61〜A-75、表示倍率の反映漏れ・重複・古い ⌘+ / ⌘- の記述が残っていないことを確認する。`specs/001-three-pane-media-viewer/` が未変更であること、`specs/008-preview-image-zoom/` の spec・plan・research・data-model・contracts・quickstart が実装の記録として整合していることも確認する
- [ ] T035 T030〜T034 の合格後、`README.md`・`Sources/`・`Tests/`・`specs/product/`・`specs/008-preview-image-zoom/` の差分を確認し、本書の完了チェックとともに最終コミットを作成する（push は行わない）

**Checkpoint**: 自動・GUI・VoiceOver・実時間のゲートが揃い、Living spec への反映と feature の凍結が完了する。

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: Setup (T001–T006)
  → Phase 2: Foundational (T007–T017)
    → Phase 3: US14 (T018–T028)  ← MVP
      → Phase 4: Polish (T029–T035)
```

### User Story Dependencies

- **US14 (P1)**: Phase 2 の `PreviewZoom`・`PreviewZoomTracker`・`PreviewZoomAvailability`・`FitCalculator.frame` が前提。1つのストーリーで完結し、他のストーリーへの依存はない。
- US14 の中では Core（Phase 2）→ `ImagePreviewView` → `PreviewViewController` → `MainSplitViewController` → `MainWindowController` → `AppDelegate` → `MainMenu` の順に接続する。ツールバーとファイルリストのキー移行は、`PreviewViewController` と `MainSplitViewController` の API が揃った後なら並行できる。

### Within Each Phase

- Phase 1: T001 → T002 → T003 → T004 → T005 → T006。
- Phase 2: T007・T008・T009・T010・T011（テスト）→ T012 → T013 → T014 → T015 → T016 → T017。T012 と T013 は同じファイルなので直列。T014 は T012 の後に独立して進められる。
- US14: T018 → T019 → T020 → T021 → T022 → T023。T024・T025 は T020 の後に進められるが、同じファイルを触る T022・T023 とは独立。T026 → T027 → T028。
- Polish: T029・T030 → T031 → T032 → T033 → T034 → T035。未実施の GUI／VoiceOver／計測を仮想時刻のテストや目視なしで置き換えて T033 を進めない。

### Parallel Opportunities

既定は順次実装。`[P]` は明示的に並列化する場合の候補を示すだけで、内部 subagent に同じ作業ディレクトリを編集させる指示ではない。

```text
Phase 2 のテスト（別ファイル）:
  T007 PreviewZoomTests.swift
  T008 PreviewZoomTrackerTests.swift
  T009 PreviewZoomAvailabilityTests.swift
  T010 FitCalculatorTests.swift
  T011 PreviewZoomPerformanceTests.swift

Phase 3 US14 の入口（T020 完了後、別ファイル）:
  T024 MainToolbarController.swift
  T025 FileListViewController.swift

Phase 4 の文書と自動ゲート:
  T029 README.md
  T030 swift build / swift test / 性能テスト / no-network / bundle
```

並列実装を行う場合は、未コミットの変更を先にコミットまたは stash し、`008-preview-image-zoom` をベースに専用の worktree と `agent/<task-id>-<slug>` ブランチを作る。担当者は自分の worktree だけを編集し、小さなコミットの SHA を報告する。インテグレータが `git merge --no-ff` で統合し、統合ごとに `swift build` / `swift test` を実行する。GUI の起動スモークは統合後に1つずつ行う。最後に worktree と作業ブランチを削除する。同じファイルの変更は直列化する。

## Implementation Strategy

### MVP First（US14）

1. Setup で `zoom/` の検証データと既存回帰を確認する。
2. Foundational で Core の倍率・リセット判定・有効条件・フィット計算を自動テスト付きで用意する。
3. US14 で `ImagePreviewView`・`PreviewViewController` からツールバー・メニュー・キーへ接続し、サムネイルサイズを ⌃⌘ に移す。
4. **STOP and VALIDATE**: quickstart の手動シナリオ 1〜8 で US14 を単独検証する。MVP はここまで（本 feature の全範囲）。

### Incremental Delivery

1. Setup + Foundational → Core の判断ロジックが固まり、既存 UI は無変更のまま回帰が通る。
2. US14 → ツールバー・メニュー・キーが同じ倍率を変え、画像切替・履歴・全画面・スライドショー・無効状態が揃う。
3. Polish → README・VoiceOver・実時間計測・Living spec への反映・凍結。

## Requirement Coverage

| 対象 | 主なタスク |
|---|---|
| FR-133 / 倍率の加減・上下限・フィット・中央配置 | T007、T010、T012、T014、T018、T019、T027、T032 |
| FR-134 / ツールバーの3ボタン・有効条件 | T009、T013、T020、T024、T027、T031 |
| FR-135 / 表示メニュー・⌘+・⌘-・⌘0・⌘=・サムネイル移行 | T022、T023、T024、T025、T027、T032 |
| FR-136 / 有効条件（画像・プレビュー表示・上下限） | T009、T013、T019、T020、T024、T027 |
| FR-137 / 保存しない・履歴に含めない・リセットと保持 | T008、T013、T019、T020、T027、T032 |
| FR-138 / アクセシビリティの値と読み上げ | T018、T019、T024、T031 |
| 変更 FR-028・FR-029 / フィットとレイアウト追従 | T010、T014、T018、T027 |
| 変更 FR-045 / ツールバーのアイコン | T024、T031 |
| US14-AS1〜AS16 | T007・T008・T009・T010・T018〜T025、T027、T031、T032 |
| EC-81〜EC-90 | T007・T008・T010、T018・T019、T025、T027、T032 |
| SC-043〜SC-052 | T011・T014、T018、T024、T027、T031、T032 |
| 検証データ・性能基準 | T001〜T003、T011、T030、T032 |
| 変更 FR-107・US8-AS7 / 倍率変更を記録しない・サムネイルの ⌃⌘. / ⌃⌘, | T019、T020、T025、T027、T032、T033 |
| Living spec への反映・凍結 | T033、T034、T035 |
