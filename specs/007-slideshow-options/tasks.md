---
description: "スライドショーのオプション設定 実装タスク"
---

# Tasks: スライドショーのオプション設定

**Input**: `specs/007-slideshow-options/` の spec.md・plan.md・research.md・data-model.md・contracts/slideshow-options.md・quickstart.md、spec が参照する 006 の成果物（`specs/006-add-slideshow/`）と `specs/product/` の領域・契約、憲章 v1.2.0。

**Prerequisites**: `007-slideshow-options` ブランチ。Swift 6 / macOS 15+ / AppKit / 単一 Swift Package。外部依存の追加なし。永続化キーは `slideshow.intervalSeconds`・`slideshow.repeats`・`slideshow.transition` の3つだけを追加する。

**Tests**: plan の Testing 方針と憲章 IV に従い、間隔の解析・設定の不正値（異常系）・可変間隔・終了の判断・効果の置き換え・切り替えの状態遷移を Swift Testing で自動テストする。テストを先に追加し、実装前に期待する失敗を確認する。実時間 sleep で間隔を繰り返す単体テストは作らず、任意の now を注入する。効果の見た目・Tab 順・VoiceOver・実時間は手動ゲートとする。

**Organization**: Story 番号は spec の US12・US13 を保持する。各 Story は前提 Phase 完了後、独立した受け入れ確認を行える増分とする。

## Format: `[ID] [P?] [Story] Description`

- `[P]`: 同じ Phase 内で、前提完了後に別ファイルとして並行処理できる候補。既定は順次実装。
- `[US12]` / `[US13]`: spec.md の Story との対応。Setup・Foundational・最終 Phase には付けない。
- `[MANUAL]`: ユーザーによる GUI 操作・計測が必要なタスク。未実施なら未チェックに保つ。
- パスはリポジトリルートからの相対パス。新規ファイルは「新規」と明示する。

## Path Conventions

- Core: `Sources/MediaViewerCore/`（AppKit を import しない）
- App: `Sources/MediaViewerApp/`（MainActor で描画・入力・ウィンドウを扱う）
- Fixtures: `Sources/FixtureKit/`、テスト: `Tests/MediaViewerCoreTests/`・`Tests/MediaViewerPerformanceTests/`
- 実装中に更新する設計文書は、本書のチェックと、タスクで明示した `specs/007-slideshow-options/quickstart.md` への追記だけ。`specs/product/` への反映は T042 まで行わない。

## 共通の実装・検証規則

- デコード・列挙・zip 展開・ファイル操作を UI スレッドに載せない。通信 API は追加しない。`AVPlayer` は1つを使い回す（bug: slideshow-video-routing-context-crash、コミット 5db16aa）。
- 各 Phase 末尾のゲートは build → 全 test → no-network → bundle 作成 → ユーザーの起動スモーク → コミットの順。GUI の起動はユーザーに依頼し、未実施を合格・完了にしない。
- ゲートの結果は `specs/007-slideshow-options/quickstart.md` の末尾に「Phase 検証記録」の節を作って（既にあれば追記して）記録する。日付・コマンド結果・GUI 確認内容・未実施項目を書く。
- AppKit の禁止 split delegate override は追加しない。制約は `addSubview` の後に有効化し、異なる view hierarchy のアンカー同士を制約しない。
- 006 の入力の優先順位（終了 > 矢印 > due）、遅延時の最大1回（FR-124）、入力受理条件（`SlideshowInputPolicy`）は変えない。
- 効果・間隔の詳細設定、ランダム再生、専用の一時停止、実行中の操作パネル、設定の購読・通知の仕組み、汎用のアニメーション基盤は作らない（A-53・A-60、憲章 V）。

## Phase 1: Setup — 検証データと既存構成の確認

**Purpose**: US12・US13 の確認に使う5件の検証フォルダを用意し、既存の回帰ゲートを通す。

- [X] T001 `Tests/MediaViewerCoreTests/SlideshowFixtureTests.swift` に、`FixtureSets.slideshow(in:)` が `slideshow/transitions/` を生成し、表示順（名前昇順）が `01-image.jpg`・`02-video-1s.mp4`・`03-broken.jpg`・`04-image.png`・`05-video-10s.mov` の5件であること、`03-broken.jpg` がデコードできない破損ファイルであることを検査する Swift Testing を追加する。`FixtureKit` の一時ディレクトリに生成し defer で削除する。動画を生成しない既存の `generateVideos: false` 経路でも画像3件が揃うことを確かめる

- [X] T002 `Sources/FixtureKit/FixtureSets.swift` の `slideshow(in:generateVideos:)` に `slideshow/transitions/` の生成を追加する。既存の `ImageFixtures`・`VideoFixtures` と、`slideshow/mixed/` で使っている1秒 MP4・10秒 MOV・JPEG・PNG の生成処理を再利用し、`03-broken.jpg` は JPEG ヘッダの後ろを切り詰めた破損データとする。既存の `slideshow/` 以下のファイル名・内容は変えない

- [X] T003 `scripts/make-fixtures.sh .build/SlideshowFixtures` を実行し、`.build/SlideshowFixtures/slideshow/transitions/` に5件が生成されることを `ls` で確認する。外部ツールの導入が必要になった場合は導入せずユーザーへ確認する

- [X] T004 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記する

- [X] T005 [MANUAL] ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、3ペインが表示されること、006 のスライドショー（⇧⌘S、3秒ごとの循環、Esc で終了）に回帰がないことを確認してもらう。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ

- [X] T006 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/007-slideshow-options/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: 検証フォルダと既存回帰ゲートが揃う。

## Phase 2: Foundational — スライドショー設定の型と永続化

**Purpose**: US12・US13 の両方が読む3項目の値型と `SettingsStore` の読み書きを用意する。UI と実行時の振る舞いはまだ変えない。

**Blocking**: T007〜T012 完了後に Story 実装へ進む。

- [X] T007 `Tests/MediaViewerCoreTests/SettingsStoreTests.swift` に `slideshow` のテストを追加する。未保存では `intervalSeconds == 3`・`repeats == true`・`transition == .none`。`1`・`3600`・`false`・4種類の効果を書いて読み戻すと同じ値。項目ごとの不正値（`slideshow.intervalSeconds` に `0`・`3601`・`3.5`・`true`・`"5"`、`slideshow.repeats` に `"yes"`・`1`、`slideshow.transition` に `"fade"`・`1`）は、その項目だけが既定値になり、ほかの項目は保存値のまま残ることを検証する（EC-75、SC-039）。既存のキーの値が変わらないことも確認する。各テストは専用の suite 名の `UserDefaults` を使い、終了時に `removePersistentDomain` で消す

- [X] T008 `Sources/MediaViewerCore/Model/Settings.swift` の `PlaybackOptions`・`ConfirmationOptions` の隣に `SlideshowTransitionEffect`（`String` の raw value を持つ enum。`none` / `crossfade` / `slide` / `zoom`、`CaseIterable`・`Sendable`）と `SlideshowOptions`（`Sendable`・`Equatable`）を追加する。フィールドは `intervalSeconds: Int`（既定値 3、制約は「`SlideshowOptions.intervalRange = 1...3600`。範囲外の値を持たない」）、`repeats: Bool`（既定値 `true`、「動画のループ再生（`PlaybackOptions.loop`）とは独立（FR-119）」）、`transition: SlideshowTransitionEffect`（既定値 `.none`、「4種類のいずれか」）とし、`static let defaults`、`interval: Duration`（`.seconds(intervalSeconds)`）を持たせる。範囲外の `intervalSeconds` を受けた初期化は既定値 3 にする。表示名は App が持つので Core には置かない

- [X] T009 `Sources/MediaViewerCore/Settings/SettingsStore.swift` の `Keys` に `slideshow.intervalSeconds`・`slideshow.repeats`・`slideshow.transition` を追加し、`public var slideshow: SlideshowOptions` を `nonmutating set` で実装する。読み込みは項目ごとに独立して検証する: 間隔は「`NSNumber` で、`CFBoolean` ではなく、`Int` へ正確に変換でき、1〜3600。それ以外は 3」、繰り返しは既存の `storedBool` と同じく「`as? Bool` で読めなければ true」、効果は「4つの raw value のいずれかでなければ `none`」。既存のキー・`storedBool`・`storedDouble`・移行処理の振る舞いは変えない

- [X] T010 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記する

- [X] T011 [MANUAL] ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼し、3ペインが表示されること、既存の設定ウインドウ（⌘,）の3項目が従来どおり表示・保存されることを確認してもらう。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ

- [X] T012 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/007-slideshow-options/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: `SettingsStore.slideshow` を Story から読み書きできる。

## Phase 3: User Story 12 — 切り替え間隔と繰り返しを好みに合わせる（P1）🎯 MVP

**Goal**: 設定ウインドウに「スライドショー」の区分（間隔のテキストフィールドと「秒」、繰り返しのチェックボックス）を加え、006 の固定3秒を設定の間隔に置き換える。繰り返しがオフなら末尾のメディアから間隔の後に Esc と同じ復帰で終了する。

**Independent Test**: 設定ウインドウで間隔を 1 秒・10 秒に変え、送り間隔と矢印キー後の待ち時間を確かめる。繰り返しをオフにして `slideshow/transitions` の3件目から開始し、5件目から間隔の後に終了することを確かめる。不正な値を確定して値が変わらないことを確かめる（US12-AS1〜AS9）。効果のポップアップメニューは Phase 4 で加えるので、本 Phase の US12-AS1 は間隔と繰り返しの2項目で確認する。

### Tests for US12

- [X] T013 [P] [US12] 新規 `Tests/MediaViewerCoreTests/SlideshowIntervalInputTests.swift` に `SlideshowIntervalInput.parse(_:)` のテストを追加する。`"10"`→10、`"１５"`→15、`" 15 "`→15、`"\u{3000}15\u{3000}"`→15、`"007"`→7、`"1"`→1、`"3600"`→3600 を受け付け、`""`・`"  "`・`"0"`・`"-1"`・`"+5"`・`"2.5"`・`"abc"`・`"1,000"`・`"3601"`・`"99999999999999999999"`・`"１.５"` を nil とする（US12-AS3・AS4、EC-74、SC-039）

- [X] T014 [P] [US12] `Tests/MediaViewerCoreTests/SlideshowSessionTests.swift` の既存テストを、`start(now:interval:)`・`arrow(now:interval:)`・`commit(now:interval:)` に `.seconds(3)` を渡す形へ書き換え、006 と同じ意味のまま残す。追加: 間隔 1／3／10 秒で期限前0回・期限で1回。5秒で開始した後に間隔 2 秒で commit すると、すでに決まった期限は開始 + 5秒のままで、その commit から次の期限が +2秒になる（US12-AS9、FR-132）。矢印の待機中に新しい間隔を渡しても待機の期限は変わらず、待機後の commit から新しい間隔になる。`timeout`・`stop`・`remaining` は間隔を受け取らない

- [X] T015 [P] [US12] `Tests/MediaViewerCoreTests/SlideshowSequenceTests.swift` に `advance(in:focused:repeats:)` のテストを追加する。research.md R5 の表のとおり、繰り返しオン／オフ × 途中・末尾・対象1件・フォーカスが対象にない・選択なし・対象0件の全分岐（オンの末尾は先頭、オフの末尾は `.finish`、1件はオンで同じ URL・オフで `.finish`、フォーカスなしはどちらも先頭、0件は `.empty`）。1件・繰り返しオンでは、`.target` の URL が `focused` と等しいことを明示して検証する（T034 が「同じ対象なら効果を arm しない」と判定する根拠、EC-66）。非メディア（フォルダ・zip 自体）が末尾にある一覧でも、最後のメディアを末尾と判定する。一覧の更新で現在のメディアが末尾になる／末尾でなくなる（EC-76）、同じ一覧で `repeats` だけを変えて結果が変わる（EC-77）、通常 URL・ArchiveURL・検索結果相当の別フォルダ混在の一覧（SC-040）。既存の `nextTarget(in:focused:)` のテストが変更なしで通ることも確かめる

### Implementation for US12

- [X] T016 [P] [US12] 新規 `Sources/MediaViewerCore/Slideshow/SlideshowIntervalInput.swift` に `public enum SlideshowIntervalInput` と `static func parse(_ text: String) -> Int?` を実装する。規則: 前後の `CharacterSet.whitespacesAndNewlines`（U+3000 を含む）を除く → U+FF10〜U+FF19 だけを ASCII 数字へ置き換える → 空、または ASCII `0`〜`9` 以外を含めば nil → `Int` に変換できなければ nil（先頭の `0` は許す）→ `SlideshowOptions.intervalRange` の外なら nil。`NumberFormatter` は使わない

- [X] T017 [US12] `Sources/MediaViewerCore/Slideshow/SlideshowSession.swift` から `let interval`・`defaultInterval`・`init(interval:)` を削除し、`start(now:interval:)`・`arrow(now:interval:)`・`commit(now:interval:)` で間隔を受け取って `now + interval` を期限にする。phase・deadline・generation・pendingDue・`timeout`・`stop`・`remaining` は変えない。不変条件「一度決めた `deadline` は、設定の変更では書き換えない」をドキュメントコメントに書く。呼び出し側をコンパイルできるように、`Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` の呼び出しへ暫定で `SlideshowOptions.defaults.interval` を渡し、`Tests/MediaViewerPerformanceTests/SlideshowPerformanceTests.swift` の `SlideshowSession(interval:)` を `SlideshowSession()` と各操作への `interval` 引数に直す

- [X] T018 [US12] `Sources/MediaViewerCore/Slideshow/SlideshowSequence.swift` に `public enum SlideshowAdvance: Equatable, Sendable { case target(URL), finish, empty }` と `static func advance(in files: [MediaFile], focused: URL?, repeats: Bool) -> SlideshowAdvance` を追加する。対象は既存の `candidates(in:)` から都度導出し、判定は呼ばれた時点の最新の一覧で行う（A-57: 繰り返しオフでは自動送りで末尾から先頭へ戻らない。選択の消失による先頭（FR-125、EC-76）と矢印キーによる選び直しは除く）。既存の `nextTarget(in:focused:)` は `advance(..., repeats: true)` の `.target` を返すラッパーに置き換え、性能テストの互換を保つ

- [X] T019 [US12] `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` に `init(settings: SettingsStore)` を追加して保持し、`Sources/MediaViewerApp/App/MainSplitViewController.swift` の `SlideshowCoordinator()` の生成箇所で、同じ箇所で使っている `SettingsStore(defaults: .standard)` を渡す。設定は購読せず、`start`（間隔）・受理した矢印の `handleKeyEvent`（間隔）・`commitPendingDue`（間隔・繰り返し）のたびに `settings.slideshow` を読んで Session に渡す。`commitPendingDue` は `SlideshowSequence.advance(in:focused:repeats:)` を呼び、`.target` は従来どおり選択を同期して `SlideshowAdvance` signpost を出し、`.finish`・`.empty` は送らずに既存の `stop()` を呼んで受理した Esc と同じ復帰（全画面の解除、開始前のペイン表示・フォーカス、最後のメディアの選択の保持）を通す。006 の入力の優先順位・最大1回の遅延処理・`listingDidChange` の0件終了は変えない

- [X] T020 [US12] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` の `makeContentView` に「スライドショー」の見出しを「動画」「ファイル操作」の下に加え、`[テキストフィールド] 秒` の横並びと「最後まで表示したら先頭から繰り返す」チェックボックスを置く。ファイル内 private の `KeyViewCheckbox`（`canBecomeKeyView` を常に true にする `NSButton` のサブクラス）を作り、既存の3つのチェックボックスと繰り返しのチェックボックスに使う。`window.autorecalculatesKeyViewLoop = false` にし、`nextKeyView` を「動画を自動再生する → 動画をループ再生する → 確認する → 切り替え間隔 → 繰り返す → 先頭へ戻る」の順に明示して `initialFirstResponder` を先頭にする（効果のポップアップは T028 で繰り返しの後に挿入する）。アクセシビリティのラベルをテキストフィールドに「切り替え間隔（秒）」、チェックボックスに「最後まで表示したら先頭から繰り返す」と設定する。ウインドウの高さを内容に合わせて広げ、制約は `addSubview` の後に有効化する

- [X] T021 [US12] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` に確定と取り消しを実装する。`NSTextFieldDelegate` の `controlTextDidEndEditing`（Return・Tab／⇧Tab・クリックによるフォーカスの移動）で `SlideshowIntervalInput.parse` を呼び、成功なら `settings.slideshow` の間隔だけを保存してフィールドを正規化した数字で表示し直し、失敗なら保存せず保存値（直前の有効値）を表示する。警告のダイアログや音は出さない。`control(_:textView:doCommandBy:)` で `cancelOperation(_:)` を受けたら保存値の表示へ戻して `true` を返し、ウインドウを閉じず responder chain へ流さない。`windowWillClose` で `window.makeFirstResponder(nil)` を呼んで同じ検証を通す（EC-73）。繰り返しのチェックボックスは操作した時点で保存する。既存の `syncFromStore` で間隔と繰り返しも保存値から表示し直す

- [X] T022 [US12] `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記する

- [X] T023 [MANUAL] [US12] ユーザーに `cd /Users/igachan/projects/my_img_viewer`、必要なら `scripts/make-fixtures.sh ~/MediaViewerFixtures`、`open .build/MediaViewer.app` の実行を依頼する。3ペインの表示を確認した後、quickstart.md の「設定ウインドウ」1・2・4〜7（効果の項目を除く）と「間隔と繰り返し」1〜9 を確認してもらう。特に、設定ウインドウの Esc でウインドウもスライドショーも終了しないこと、繰り返しオフの終了が Esc と同じ表示復帰になること（全画面から開始した場合を含む）を記録する。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ

- [X] T024 [US12] 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/007-slideshow-options/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: 間隔と繰り返しの MVP が検証済み。効果は「なし」のまま 006 と同じ表示の更新になる。

## Phase 4: User Story 13 — 切り替え効果を選ぶ（P2）

**Goal**: 設定ウインドウで「なし」「クロスフェード」「スライド」「ズーム」を選べるようにし、スライドショーの自動送りにだけ約0.5秒の効果を付ける。前の表示は snapshot（前の動画は切り替えの開始時点のフレームで静止・無音）、次のメディアは実物のまま重ねる。

**Independent Test**: 4種類の効果を順に選び、`slideshow/transitions` の画像・動画・破損ファイルを含む自動送りを確認する。効果の途中で矢印・Esc・全画面の切り替えを行い、すぐに反映されることを確かめる（US13-AS1〜AS8、EC-67・EC-78〜EC-80）。

### Tests for US13

- [X] T025 [P] [US13] 新規 `Tests/MediaViewerCoreTests/SlideshowTransitionEffectTests.swift` に `effective(reduceMotion:)` のテストを追加する。`reduceMotion == true` で `slide`・`zoom` は `crossfade`、`none`・`crossfade` はそのまま。`false` では4種類ともそのまま（US13-AS7、FR-131）。raw value が `none` / `crossfade` / `slide` / `zoom` であることも固定する

- [X] T026 [P] [US13] `Tests/MediaViewerCoreTests/VideoPlaybackTests.swift` に、`load(asset:loop:)` 前と `unload()` 後の `currentFrame()` が nil であること、`load` したアイテムに `AVPlayerItemVideoOutput` が1つだけ付き、同じ `player` を使い回したまま次の `load` で前のアイテムの output が外れることを検証するテストを追加する。動画は `FixtureKit` の1秒 MP4 を一時ディレクトリに生成し defer で削除する

- [X] T045 [P] [US13] 新規 `Tests/MediaViewerCoreTests/SlideshowTransitionStateTests.swift` に、`SlideshowTransitionState`（T046）の状態遷移のテストを追加する。data-model.md §5 の表の全行を検証する: idle で `arm`（対象が現在の表示と異なり、効果が `none` 以外）→ holding・世代が進み、snapshot を表示する action。対象が現在の表示と同じ URL（EC-66 の1件・繰り返しオン）または効果が `none` の `arm` は idle のまま action なし（holding／animating 中なら打ち切り）。holding／animating 中の `arm` は打ち切ってから新たに holding。holding で対象の表示が準備完了 → animating と animation 開始の action。準備中の表示（`.loading`、`.animatedImage`／`.animatedImageData` の `showAnimated` 前、`.video` の準備完了（最初のフレームを表示できる時点）前）では holding のまま。holding で対象の再表示が届いたら準備完了を判定し直す。対象以外の URL の表示 → holding・animating のどちらでも打ち切り（効果中に効果「なし」の次の commit が来た場合を含む）。animating で対象の再表示・対象の `ready` → 何もしない（analyze U1 で追加した行）。古い世代の completion・準備完了の通知は無視し、現世代の completion → idle と overlay を外す action。holding／animating で `cancel`・コンテナの大きさの変更 → 打ち切り、idle での `cancel` は action なし。あわせて research.md R8 の準備完了の判定表（`.image`・`.unavailable`・`.empty` はすぐ、`.animatedImage`／`.animatedImageData`・`.video`・`.loading` は待つ）を `PreviewContent` の各ケースで検証する（FR-130・FR-131、EC-66・EC-80、US13-AS5・AS6・AS8）。analyze D1 で追加

### Implementation for US13

- [X] T027 [US13] `Sources/MediaViewerCore/Model/Settings.swift` の `SlideshowTransitionEffect` に `func effective(reduceMotion: Bool) -> SlideshowTransitionEffect` を追加する。`reduceMotion` が true なら `slide`・`zoom` を `crossfade` に置き換え、`none`・`crossfade` はそのまま返す。保存値は変えない（A-59）

- [X] T046 [US13] 新規 `Sources/MediaViewerCore/Slideshow/SlideshowTransitionState.swift` に、プレビューの切り替えの状態を表す純粋な値型 `SlideshowTransitionState`（`Sendable`・`Equatable`）を実装する。フィールドは data-model.md §5 のとおり phase（`idle / holding / animating`）・targetURL・effect・generation とし、snapshot の画像は持たない（App が持つ）。`mutating func reduce(_ event:) -> Action` で、イベント（`arm(target:current:effect:)`、表示の更新 `displayed(content:focused:)`、準備完了の通知 `ready(url:)`、`completed(generation:)`、`cancel`、`containerResized`）を受けて次の状態と App が実行する action（なし／snapshot を表示して holding／animation の開始（効果・世代）／overlay を外す（完了・打ち切りの別））を返す。`static func readiness(of: PreviewContent)` に research.md R8 の判定表を置く。URL を持たない表示（`.image`・`.unavailable`・`.empty`）は `focused` をその表示の URL とみなす。時刻・タイマー・AppKit・Core Animation は持たない。T045 のテストを通す。analyze D1 で追加

- [X] T028 [US13] `Sources/MediaViewerApp/Settings/SettingsWindowController.swift` に切り替え効果のポップアップメニューを追加する。ファイル内 private の `KeyViewPopUpButton`（`canBecomeKeyView` を常に true にする `NSPopUpButton` のサブクラス）で「なし」「クロスフェード」「スライド」「ズーム」を並べ、各項目の `representedObject` に raw value を持たせる。選択した時点で `settings.slideshow` の効果だけを保存する。アクセシビリティのラベルを「切り替え効果」とし、`nextKeyView` を「繰り返す → 切り替え効果 → 動画を自動再生する」に変えて T020 の順序の末尾に挿入する。`syncFromStore` で保存値を選択し直す

- [X] T029 [P] [US13] `Sources/MediaViewerCore/Playback/VideoPlayback.swift` で、`load(asset:loop:)` のたびに新しいアイテムへ `AVPlayerItemVideoOutput`（`kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA`）を付け、`unload()` と次の `load` で前のアイテムから外す。`public func currentFrame() -> CGImage?` を追加し、`player.currentTime()` に対して `hasNewPixelBuffer` に依らず `copyPixelBuffer(forItemTime:itemTimeForDisplay:)` を呼び、`VTCreateCGImageFromCVPixelBuffer` で `CGImage` に変換する。フレームがなければ nil。AppKit は import せず、`AVPlayer` は1つのまま使い回す

- [X] T030 [US13] `Sources/MediaViewerApp/Preview/VideoPreviewView.swift` に `freezeForTransition() -> (image: CGImage?, videoRect: CGRect)` を追加する。先に `player.pause()` で再生と音声を止め、`playback.currentFrame()` と `AVMakeRect(aspectRatio:insideRect:)` による aspect-fit の配置を返す（フレームがなければ image は nil で背景だけ）。最初のフレームを表示できる時点（`AVPlayerView`／`AVPlayerLayer` の該当 API、例えば `AVPlayerLayer.isReadyForDisplay` 相当を実装時に確認する）を KVO で監視し、その時点、`AVPlayerItem.status` が `.failed` になった時点、または映像トラックを持たない動画で `.readyToPlay` になった時点で、`onReadyForTransition` クロージャを MainActor で呼ぶ。`.readyToPlay` だけでは最初のフレームの描画を保証しないので、映像トラックのある動画の判定には使わない（research.md R8、analyze U3）。`onReadyForTransition` は引数を持たず、URL の対応は T033 が `configure` のたびに設定し直すクロージャで取る。`stop()` と次の `configure` で監視を外す

- [X] T031 [P] [US13] `Sources/MediaViewerApp/Preview/ImagePreviewView.swift` に `transitionSnapshot() -> (image: CGImage?, frame: CGRect, gravity: CALayerContentsGravity)` を追加する。静止画・アニメーション画像では `contentLayer` の現在の `contents`（`CGImage`）・frame・`contentsGravity` をそのまま返し、デコードや再描画をしない。エラー表示・メッセージ・読み込み中では `layer` を `CALayer.render(in:)` で表示サイズのビットマップに描いて返す。空の表示では image を nil（背景だけ、EC-79）とする

- [X] T032 [P] [US13] 新規 `Sources/MediaViewerApp/Preview/SlideshowTransitionOverlayView.swift` に、前の表示を写す overlay を実装する。背景をプレビューの背景色で不透明に塗り、snapshot の `CGImage` を指定の frame と `contentsGravity` の sublayer に載せる。`hitTest(_:)` は nil を返してクリックを下のプレビューへ通し、`isAccessibilityElement` を false にする。snapshot を手放す `clear()` を持つ

- [X] T033 [US13] `Sources/MediaViewerApp/Preview/PreviewViewController.swift` で、既存の `imageView`・`videoView` を新しい `contentHostView` に入れ、その上に `SlideshowTransitionOverlayView` を重ね、`containerView` の layer を `masksToBounds` にする（制約は `addSubview` の後に有効化）。表示だけの切り替えの状態として Core の `SlideshowTransitionState`（T046）を1つ持たせ、遷移の判断はすべてその `reduce` に任せる。PreviewViewController は返された action の実行（snapshot の取得と overlay の表示、animation の追加、overlay を外して snapshot を手放す）と、snapshot の画像の保持だけを行い、phase・世代・準備完了の判定を独自に持たない。`beginTransition(to:current:effect:)` は `arm` を送り、snapshot を表示する action なら、前が動画なら `freezeForTransition`、それ以外は `transitionSnapshot` で overlay を表示する（打ち切りを伴う場合は先に animation を外す）。`updateFromModel` は `displayed(content:focused:)` を、`showAnimated` の呼び出しと `onReadyForTransition` は `ready(url:)` を送る。動画の `ready(url:)` の URL は、`showVideo` が `configure` に渡した URL（`model.preview` の `.video(URL)`。zip 内の動画もアセットへ変換する前の URL）とし、`showVideo` が `configure` を呼ぶたびに、その URL を捕捉したクロージャを `videoView.onReadyForTransition` に設定し直す（research.md R8、analyze U3）。animation の開始の action を受けたら0.5秒・`easeInEaseOut` の `CABasicAnimation` を overlay と `contentHostView` の layer に追加するだけで効果を表す（クロスフェード: overlay の opacity 1→0・次の opacity 0→1、スライド: overlay の translation.x 0→−幅・次の +幅→0、ズーム: overlay の opacity 1→0・次は中心基準の scale 0.6→1.0 と opacity 0→1。anchorPoint が原点のため「中心へ平行移動 → 拡大 → 戻す」の `CATransform3D` を from 値にする）。layer のモデル値は変えない。`CATransaction` の completion は、animation の開始の action が返した世代で `completed(generation:)` を送る。`cancelTransition()` は `cancel` を送り、overlay を外す action なら animation を外して overlay を隠す（idle では何もしない）。`containerView` の大きさが変わったとき（全画面の切り替え・リサイズ、EC-80）は `containerResized` を送る。targetURL 以外の表示による打ち切りは `displayed` の結果に従う。既存の `OSSignposter`（`local.my-img-viewer.MediaViewer` / `Performance`）で `SlideshowTransitionStart`・`SlideshowTransitionEnd`・`SlideshowTransitionCancel` を出す（ファイル名・パスは含めない）

- [X] T034 [US13] `Sources/MediaViewerApp/Slideshow/SlideshowCoordinator.swift` の `SlideshowCoordinatorDelegate` に `slideshowBeginTransition(to url: URL, current: URL?, effect: SlideshowTransitionEffect)` と `slideshowCancelTransition()` を追加し、`Sources/MediaViewerApp/App/MainSplitViewController.swift` でプレビューの `beginTransition(to:current:effect:)`・`cancelTransition()` へ中継する。`commitPendingDue` で `advance` が `.target(url)` のとき、まず `url` が `delegate.slideshowFocusedURL` と同じか（EC-66 の1件・繰り返しオン）を判定する。同じなら arm せず、`slideshowCancelTransition` だけを呼んで準備中の切り替えを打ち切る（idle なら何もしない。前の動画を一時停止しないので、再生状態を保ち overlay も表示しない、FR-119）。異なり、かつ `settings.slideshow.transition.effective(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)` が `none` でなければ、選択を同期する**前に** `slideshowBeginTransition` を呼んで `SlideshowTransitionBegin` signpost を出す。それでも `slideshowSynchronizeSelection` が false を返した場合は、直ちに `slideshowCancelTransition` を呼ぶ（防御。同じ対象は上の判定で除いている）。受理した矢印の処理の先頭・`stop()`・`stopImmediately()` でも `slideshowCancelTransition` を呼ぶ。`start`・矢印による選び直し・終了時の復帰・スライドショー以外の選択変更では arm しない（FR-131、US13-AS5・AS8）。準備待ち・効果の途中に受理した矢印・Esc は、`slideshowCancelTransition` の後、006 と同じく選択中のメディア（次の対象）を基準に処理する。表示中の写しの URL を矢印・終了の基準にする状態は持たない（EC-80、analyze U5）。Session の期限は効果・準備待ちで延ばさない（FR-118、EC-80）

- [X] T035 [US13] `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` を順に実行し、失敗の修正は最大3回までとする。`swift test --filter MediaViewerPerformanceTests` の既存基準も確かめ、video output の追加による動画開始への影響（research.md R7 の Risks）を確認する。問題があればスライドショーの実行中で効果が「なし」以外のときだけ output を付ける方式に絞る。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記する

- [X] T036 [MANUAL] [US13] ユーザーに `cd /Users/igachan/projects/my_img_viewer` と `open .build/MediaViewer.app` の実行を依頼する。3ペインの表示を確認した後、quickstart.md の「設定ウインドウ」1〜3・8（効果のポップアップを含む Tab 順、Space と矢印・Return での選択、VoiceOver のラベル）と「切り替え効果」1〜13 を確認してもらう。特に、前の動画が静止・無音のまま効果が行われること、準備待ち・効果の途中の ↓・Esc が選択中のメディア（次の対象）を基準にすること（EC-80）、対象1件・繰り返しオンで効果を選んでも動画が止まらず overlay がちらつかないこと、効果の途中の ↓・Esc・⌃⌘F が待たされないこと、次が動画のとき効果の途中に黒い（空の）表示が見えないこと、効果の途中の画像のダブルクリックで全画面が切り替わること、「視差効果を減らす」でスライド・ズームがクロスフェードになることを記録する。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記し、GUI 未実施ならこのタスクを未チェックに保つ

- [X] T037 [US13] 直前の自動・GUI ゲート合格後、当該 Phase のソース・テスト・`specs/007-slideshow-options/` の差分だけを確認して Phase 単位でコミットする（push は行わない）

**Checkpoint**: US12・US13 の機能ゲートが揃う。最終計測と仕様反映へ進める。

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: 実時間の証拠を揃え、利用者向けの文書を更新し、006 の反映の後に Living spec へ移す。

- [X] T038 [P] `README.md` のスライドショーの説明と手動確認に、設定ウインドウ（⌘,）の「スライドショー」区分（切り替え間隔 1〜3600 秒・既定3、「最後まで表示したら先頭から繰り返す」・既定オン、切り替え効果 なし／クロスフェード／スライド／ズーム・既定なし）、繰り返しオフでの末尾での終了、効果は自動送りだけに付くこと、「視差効果を減らす」での置き換えを追記する。固定3秒の記述を設定の間隔に改める。効果の長さの設定や一時停止など範囲外の機能を案内しない

- [X] T039 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` の最終ゲートを実行する。`Tests/MediaViewerPerformanceTests/` の結果を回収し、`Sources/MediaViewerCore/` が AppKit を import していないこと（`grep -rn "import AppKit" Sources/MediaViewerCore` が0件）を確認する。結果を `specs/007-slideshow-options/quickstart.md` の「Phase 検証記録」へ追記する

- [X] T040 [MANUAL] quickstart.md の全手動シナリオと「実時間の計測」をユーザーへ依頼する。`open .build/MediaViewer.app` で3ペインの起動を確かめた後、Instruments（OS Signposts／Points of Interest）で、間隔 1／3／10 秒 × 4種類の効果で連続10回の `SlideshowAdvance` 間隔が設定値〜設定値＋0.2秒、最後の `SlideshowArrow` から次の `SlideshowAdvance` までが同じ時間枠、「なし」以外の各効果20回の `SlideshowTransitionStart`→`SlideshowTransitionEnd` が0.7秒以内であることを測る（SC-038・SC-041）。既定値（3秒・オン・なし）で 006 の quickstart の回帰シナリオも確認する（A-54）。未実施なら未チェックに保つ

- [X] T041 [MANUAL] `specs/007-slideshow-options/quickstart.md` に「最終検証結果」を追記し、環境（macOS・機種・build 種別）、SC-038〜SC-042 の結果、間隔ごとの最小・最大・範囲外の件数、効果の所要時間の最大、video output 追加後の既存性能基準、GUI の実施者と未実施項目を記録する。未実施の項目を PASS としない。全ゲート合格前に T042 へ進まない

- [X] T042 T001〜T041 と T045・T046 の実装・検証が完了し、**かつ** 006 の product 反映（`specs/006-add-slideshow/tasks.md` の T056〜T058）が完了している場合に限り、`specs/007-slideshow-options/spec.md` の「反映先」の表どおり、`specs/product/preview.md`・`specs/product/overview.md`（動作オプション）・`specs/product/contracts/settings.md`・`specs/product/contracts/keyboard-and-menus.md` へ全追加／変更 ID を移す。006 の項目（FR-118・FR-119・FR-121、EC-66・EC-67、A-49・A-52・A-53、実行状態）は本書の変更後の本文で置き換える。契約は参照で記載して ID 本文を重複定義せず、Clarifications は feature に残す。手順と ID の付け方は `specs/product/README.md` に従い、feature spec の冒頭へ移行済み・凍結の注記を付す。006 の反映が未完了なら本タスクを未チェックのまま止めてユーザーへ報告する

- [X] T043 `specs/007-slideshow-options/spec.md` の「反映先」の表と `specs/product/` の ID・リンク・契約を照合し、FR-118・119・121・127〜132、US12-AS1〜AS9、US13-AS1〜AS8、EC-66・67・73〜80、SC-038〜042、A-49・52・53・54〜60、動作オプションの反映漏れ・重複がないことを確認する。`specs/001-three-pane-media-viewer/` が未変更であることも確認する

- [X] T044 T039 の自動ゲート・T040 の GUI／計測・T043 の文書照合の合格後、最終 Phase のソース・テスト・`README.md`・`specs/product/`・`specs/007-slideshow-options/` の差分を確認し、本書の完了チェックとともにコミットする（push は行わない）

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 1: Setup (T001–T006)
  → Phase 2: Foundational (T007–T012)
    → Phase 3: US12 (T013–T024)  🎯 MVP
      → Phase 4: US13 (T025–T037、T045・T046)
        → Phase 5: 最終検証・反映 (T038–T044)
                   ※ T042 は 006 の T056〜T058 の完了も前提
```

### User Story Dependencies

- **US12 (P1)**: Foundational の `SlideshowOptions`・`SettingsStore.slideshow` が前提。単独で間隔と繰り返しを検証できる。
- **US13 (P2)**: 概念上は US12 と独立（効果は既定の間隔・繰り返しでも確認できる）だが、`SettingsWindowController.swift`（Tab 順）と `SlideshowCoordinator.swift`（`commitPendingDue` が `advance` を使う形）を US12 と共有するため、US12 の後に直列で実装する。
- 各 Story はテスト → Core 実装 → App 接続 → 自動ゲート → GUI → コミットの順。GUI 未実施なら Phase 完了として次へ進めない。

### Within Each Phase

- Phase 1: T001 → T002 → T003 → T004 → T005 → T006。
- Phase 2: T007 → T008 → T009 → T010 → T011 → T012。
- US12: T013・T014・T015（テスト）→ T016（T013 の対象、独立ファイル）→ T017 → T018 → T019 → T020 → T021 → T022 → T023 → T024。T017 は Session の呼び出し側（Coordinator・性能テスト）も同時に直してビルドを保つ。T020・T021 は同じファイルなので直列。
- US13: T025・T026・T045（テスト）→ T027 → T046（T045 の対象、T027 の `SlideshowTransitionEffect` を使う）→ T028 → T029 → T030（T029 の `currentFrame` を使う）→ T031・T032 → T033（T030〜T032・T046 を使う）→ T034（T033 の API を使う）→ T035 → T036 → T037。T045・T046 は analyze D1 で追加したため ID が末尾にある。
- Phase 5: T038・T039 → T040 → T041 → T042 → T043 → T044。未実施の GUI／実時間計測を仮想時刻のテストで置き換えて T042 を進めない。

### Parallel Opportunities

既定は順次実装。`[P]` は明示的に並列化する場合の候補を示すだけで、内部 subagent に同じ作業ディレクトリを編集させる指示ではない。

並列実装を行う場合は、未コミットの変更を先にコミットまたは stash し、`007-slideshow-options` をベースに専用の worktree と `agent/<task-id>-<slug>` ブランチを作る。担当者は自分の worktree だけを編集し、小さなコミットの SHA を報告する。インテグレータが `git merge --no-ff` で統合し、統合ごとに `swift build` / `swift test` を実行する。GUI の起動スモークは統合後に1つずつ行う。最後に worktree と作業ブランチを削除する。同じファイルの変更は直列化する。

## Parallel Example: US12

Phase 2 完了後、別ファイルのテストを並行して準備できる。

```text
T013: Tests/MediaViewerCoreTests/SlideshowIntervalInputTests.swift（新規）
T014: Tests/MediaViewerCoreTests/SlideshowSessionTests.swift
T015: Tests/MediaViewerCoreTests/SlideshowSequenceTests.swift
```

T016 の `Sources/MediaViewerCore/Slideshow/SlideshowIntervalInput.swift`（新規）は、Session・Sequence の変更と別ファイルなので並行できる。T017〜T021 は Coordinator・設定ウインドウの接続が連続するため直列。

## Parallel Example: US13

US12 完了後、次のファイルは互いに独立して準備できる。

```text
T025: Tests/MediaViewerCoreTests/SlideshowTransitionEffectTests.swift（新規）
T026: Tests/MediaViewerCoreTests/VideoPlaybackTests.swift
T045: Tests/MediaViewerCoreTests/SlideshowTransitionStateTests.swift（新規）
T029: Sources/MediaViewerCore/Playback/VideoPlayback.swift
T031: Sources/MediaViewerApp/Preview/ImagePreviewView.swift
T032: Sources/MediaViewerApp/Preview/SlideshowTransitionOverlayView.swift（新規）
```

T033（PreviewViewController）と T034（Coordinator・MainSplitViewController）は上記の API を組み合わせるため直列。

## Implementation Strategy

### MVP First（US12）

1. Setup と Foundational を完了する。
2. US12 を実装し、設定ウインドウの間隔・繰り返しと、可変間隔・繰り返しオフの終了を個別に検証する。
3. **STOP and VALIDATE**: 効果は「なし」の 006 と同じ表示のまま、要望の中心（間隔と終わりのある再生）が使える状態を MVP とする。

### Incremental Delivery

1. Setup + Foundational → 設定の値型と永続化。
2. US12 → 間隔と繰り返し（MVP）。自動・GUI ゲート → コミット。
3. US13 → 切り替え効果。自動・GUI ゲート → コミット。
4. 実時間の計測（SC-038・SC-041）と最終検証の記録 → 006 の反映の後に product へ反映して feature を凍結する。

## Requirement Coverage

| 対象 | 主なタスク |
|---|---|
| FR-127 / 設定ウインドウの区分・Tab 順・ラベル | T020、T028、T023、T036 |
| FR-128 / 間隔の解析・確定・Esc の取り消し | T013、T016、T021、T023 |
| FR-129 / 繰り返しオン／オフと末尾での終了 | T015、T018、T019、T023 |
| FR-130 / 効果の種類・0.5秒・準備待ち | T029–T034、T045、T046、T036、T040 |
| FR-131 / 効果を付けない場面・打ち切り・視差効果を減らす | T025、T027、T033、T034、T045、T046、T036 |
| FR-132 / 保存・復元・実行中の変更 | T007、T009、T014、T017、T019、T021、T023 |
| 変更 FR-118・FR-119・FR-121 / 可変間隔・動画・矢印の待機 | T014、T017、T019、T023、T040 |
| US12-AS1〜AS9 | T007–T009、T013–T023 |
| US13-AS1〜AS8 | T025–T036、T045、T046 |
| EC-66・EC-67 / 対象1件・表示不能 | T015、T018、T019、T031、T033、T034、T045、T046、T036 |
| EC-73・EC-74 / 閉じる時の確定・先頭の0・桁区切り・符号 | T013、T016、T021、T023 |
| EC-75 / 保存値の検証 | T007、T009 |
| EC-76・EC-77 / 一覧の更新・実行中の繰り返しの変更 | T015、T018、T019、T023 |
| EC-78〜EC-80 / 前の動画の静止・空からの切り替え・準備待ち・リサイズ | T026、T029–T033、T045、T046、T036 |
| SC-038・SC-041 / 実時間 | T033、T034、T040、T041 |
| SC-039・SC-040・SC-042 | T007、T013、T015、T020–T023、T028、T036、T040 |
| A-49・A-52〜A-60 | 上記実装の範囲制約、T038、T042 |
| 動作オプション（overview.md）と全 ID の Living spec 反映 | T042、T043 |

## Notes

- 本書が進捗の正本。全て未着手として生成した。
- 2026-10-26 の analyze の指摘を、着手前に反映した。C1（対象1件で効果を arm して動画が止まる）は T015・T034 と quickstart の「切り替え効果」12 で、D1（切り替えの状態遷移が App にあり自動テストがない）は T045・T046 の追加と T033 の変更で扱う。既存の ID への参照を保つため、追加したタスクの ID は末尾から採番した。
- 2026-10-26 の2回目の analyze の MEDIUM の指摘を、着手前に反映した。I1（A-57 の範囲）は spec の A-57・data-model §4・T018 で、U1（animating 中の表示の行の抜け）は data-model §5・research R8・T045 で、U2（契約にだけある振る舞い）は spec の EC-80・FR-128・FR-131 で、U3（動画の準備完了の判定と URL の出どころ）は research R8・data-model §5・§6・T030・T033・T045・T036 で扱う。P1（006 の T054〜T058 の未完了）は判断待ちのため、T042 の前提は変えていない。
- 2026-10-26 の3回目の analyze の MEDIUM の指摘を、着手前に反映した。U5（準備待ち・効果の途中の矢印・Esc の基準）は、選択中のメディア（次の対象）を基準とするとして、spec の EC-80・contracts・research R8・data-model §5・quickstart の「切り替え効果」13・T034・T036 で扱う。P1 は引き続き判断待ちのため、T042 の前提は変えていない。LOW（U6・I4・I5・I6・U7）は反映していない。
- GUI／Instruments 未実施は該当タスクを未チェックに保ち、完了と報告しない。
- テスト失敗の修正が3回で解決しない場合は止めて状況を報告する。
- 起動不良では推測で直さず、AGENTS.md の lldb による Objective-C 例外の停止コマンドをユーザーに依頼する。
- `.app` の設定は `local.my-img-viewer.MediaViewer` のドメインに保存される。初回状態の確認で3キーを消す場合は、quickstart.md の `defaults delete` をユーザーの了承を得てから使う。

## Phase 6: Convergence

- [X] T047 006 の T054〜T058（最終検証と `specs/product/` への反映）を完了させたうえで、`specs/007-slideshow-options/spec.md` の「反映先」の表どおりに FR-118・119・121・127〜132、US12-AS1〜AS9、US13-AS1〜AS8、EC-66・67・73〜80、SC-038〜042、A-49・52・53・54〜60、動作オプションを `specs/product/preview.md`・`overview.md`・`contracts/settings.md`・`contracts/keyboard-and-menus.md` へ反映し、`overview.md` の A-14 にある「スライドショーは範囲外」を解消してから feature spec を凍結する。006 の検証が未完了なら T042 と同じく止めてユーザーへ報告する。反映漏れ・重複の照合（T043）もこのタスクで完了させる (missing)

- [X] T048 [MANUAL] quickstart.md の「実時間の計測」をユーザーへ依頼し、Instruments（OS Signposts／Points of Interest）で、間隔 1／3／10 秒 × 4種類の効果の連続10回の `SlideshowAdvance` が設定値〜設定値＋0.2秒、最後の `SlideshowArrow` から次の `SlideshowAdvance` までが同じ時間枠、「なし」以外の各効果20回の `SlideshowTransitionStart`→`SlideshowTransitionEnd` が0.7秒以内であることを測る。結果を quickstart.md の「最終検証結果」へ、環境（macOS・機種・build 種別）、SC-038・SC-041 の最小／最大／範囲外件数、効果の所要時間の最大、実施者と未実施項目を記録する。未実施の項目を PASS としない (missing)

- [X] T049 `README.md` のスライドショーの説明と手動確認を、設定ウインドウ（⌘,）の「スライドショー」区分（切り替え間隔 1〜3600 秒・既定3、「最後まで表示したら先頭から繰り返す」・既定オン、切り替え効果 なし／クロスフェード／スライド／ズーム・既定なし）、繰り返しオフの末尾での終了、効果は自動送りだけに付くこと、「視差効果を減らす」での置き換えに合わせて更新する。34・158・210 行目付近の固定3秒の記述を設定の間隔に改め、範囲外の機能を案内しない (partial)

- [X] T050 `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` の最終ゲートを実行し、`Sources/MediaViewerCore/` の `import AppKit` が0件であることを確認して、結果を quickstart.md の「Phase 検証記録」へ追記する。`FileNameSearcherTests` のキャンセルテストが全体実行でだけ失敗する既知の揺れを再確認した場合は、単独実行の結果とあわせて記録し、本 feature の変更に起因しないことを明記する。合格後、T038〜T049 の完了を確認して最終 Phase をコミットする（push は行わない） (partial)
