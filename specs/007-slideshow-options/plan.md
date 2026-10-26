# Implementation Plan: スライドショーのオプション設定

**Branch**: `007-slideshow-options` | **Date**: 2026-10-26 | **Spec**: [spec.md](spec.md)

**Input**: `specs/007-slideshow-options/spec.md`、spec が参照する 006 の成果物（spec・data-model・contracts）と `specs/product/` の領域・契約。憲章 v1.2.0。

## Summary

設定ウインドウ（⌘,）に「スライドショー」の区分を加え、切り替え間隔（1〜3600 の整数秒、既定3）・繰り返し（既定オン）・切り替え効果（なし／クロスフェード／スライド／ズーム、既定なし）を保存・復元する。006 の固定3秒を設定の間隔に置き換え、繰り返しがオフなら末尾のメディアから間隔の後に Esc と同じ復帰で終了する。自動送りにだけ約0.5秒の効果を付ける。

設定は既存の `SettingsStore` に3キーを加え、`SlideshowCoordinator` が判断の時点ごとに読む（購読しない）。`SlideshowSession` は間隔を引数で受け取り、予定済みの期限を書き換えない。終了の判断は `SlideshowSequence.advance` に入れ、既存の `stop()` を再利用する。効果は、前の表示の snapshot を overlay に、次のメディアを実物のまま重ね、Core Animation の animation を追加するだけで表す。根拠は [research.md](research.md)、型と遷移は [data-model.md](data-model.md)、操作は [contracts/slideshow-options.md](contracts/slideshow-options.md) を参照。

## Technical Context

**Language/Version**: Swift 6（Package の `swiftLanguageModes: [.v6]`）

**Primary Dependencies**: Foundation／Swift Concurrency、AppKit、Core Animation（QuartzCore）、既存の ImageIO・AVFoundation・AVKit。動画フレームの写しに CoreVideo・VideoToolbox（OS 標準）。外部パッケージの追加なし。Core は AppKit に依存しない。

**Storage**: 既存のローカル UserDefaults。`slideshow.intervalSeconds`（Int）・`slideshow.repeats`（Bool）・`slideshow.transition`（String）の3キーを追加する。実行状態・期限・切り替えの途中の状態はメモリだけに置く。

**Testing**: Swift Testing。Core の間隔の解析・設定の読み書き・可変間隔の仮想時刻・終了の判断・効果の置き換え・切り替えの状態遷移と準備完了の判定を単体テストする。効果の見た目・Tab 順・VoiceOver はユーザーによる `.app` の手動確認。実時間は OSSignposter と Instruments で測る。

**Target Platform**: macOS 15 以降

**Project Type**: AppKit デスクトップアプリ + Core ライブラリ、単一 Swift Package

**Performance Goals**: SC-038（間隔 1／3／10 秒で各送りが設定値〜設定値＋0.2秒、効果の種類によらない）、SC-041（効果は0.7秒以内に完了、効果中の矢印・Esc を待たせない）。既存の先読み済み切り替え100ms・初回画像1秒・動画開始1秒・10,000件で UI を止めない基準を維持する。

**Constraints**: オフライン・ネットワーク API 不使用。デコード・列挙・展開・ファイル操作を UI スレッドで行わない。snapshot は表示中の `CGImage` の共有と動画の現在フレーム1枚に限り、メインスレッドでの全面の再描画をしない。`AVPlayer` は1つを使い回す（bug: slideshow-video-routing-context-crash）。効果の長さ・向きの設定、ランダム再生、専用の一時停止、操作パネルは追加しない（A-53・A-60）。GUI の起動はユーザーが行う。

**Scale/Scope**: 現在の1つの一覧全体（006 と同じ）。追加の走査は commit ごとの末尾判定（線形）だけ。設定ウインドウに3項目。

**Resolved design questions**: NEEDS CLARIFICATION はない。spec の Clarifications 5問（前の動画の静止、準備待ち、繰り返しオフの終了条件、Tab 順と Esc、動作オプションへの所属）を前提に、設定の読み出し時点（R1）、間隔の解析（R2）、Tab 順（R3）、可変間隔（R4）、終了の判断（R5）、効果の描画（R6）、snapshot（R7）、準備待ち（R8）、打ち切りと視差効果（R9）、検証（R10）を research.md に記す。

## Constitution Check

*Phase 0 の前と Phase 1 の後に評価。PASS は設計の適合の判定であり、実装・GUI 検証が済んだという意味ではない。*

| 原則・ゲート | Phase 0 前 | Phase 1 後の設計と検証方針 |
|---|---|---|
| I ローカル完結 | PASS | 通信・送信・ファイル変更なし。設定は既存の UserDefaults だけ。no-network チェックを実行する |
| II 性能 | PASS | 期限は commit 時刻から数え、効果・準備待ちで延ばさない。snapshot は既存の `CGImage` の共有と動画1フレームのみ。video output の追加の影響を既存の動画開始の基準で確かめる（R7 の Risks）。SC-038／041 を signpost で実測して記録する |
| III キーボード・アクセシビリティ | PASS | 設定の3項目は Tab／⇧Tab・Space・Return・Esc だけで操作でき、システムのキーボードナビゲーションに依存しない。3項目にラベル。視差効果を減らす設定でスライド・ズームをクロスフェードにする |
| IV テスト必須 | PASS | 解析・設定の不正値（異常系）・可変間隔・終了の判断・効果の置き換え・切り替えの状態遷移（holding／animating、世代の照合、準備完了の判定、打ち切りの条件）を Core でテストする。描画は手動ゲート |
| V シンプルさ | PASS | 新しい依存なし（OS 標準のフレームワークのみ）。設定の購読・効果の汎用基盤・効果の詳細設定を作らない。終了は既存の `stop()` を再利用する |
| 技術制約・AppKit 不変条件 | PASS | MainActor でのみ UI を変更する。制約は `addSubview` の後に有効化する。animation は layer のモデル値を変えず、NSSplitViewDelegate の禁止メソッドに触れない。Core は AppKit を import しない |
| 仕様管理・検証ゲート | PASS | 成果物は本 feature に限る。実装中は tasks のチェックと明示タスクの追記だけ。product への反映は実装・検証の後、006 の反映の後に行う。GUI 未確認を完了にしない |

違反・例外の申請はない。

## Project Structure

### Documentation (this feature)

```text
specs/007-slideshow-options/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/slideshow-options.md
├── quickstart.md
└── tasks.md                 # 次の /speckit-tasks で生成。本コマンドでは作らない
```

### Source Code (repository root)

以下は実装先の予定。既存ファイルの修正を優先し、新規には「新規」を付す。

```text
Sources/MediaViewerCore/
├── Model/Settings.swift                  # SlideshowOptions・SlideshowTransitionEffect を追加
├── Settings/SettingsStore.swift          # slideshow の3キー・読み込み時の検証
├── Slideshow/
│   ├── SlideshowIntervalInput.swift      # 新規: 間隔の文字列の解析
│   ├── SlideshowSession.swift            # interval を引数へ
│   ├── SlideshowSequence.swift           # advance(in:focused:repeats:)
│   └── SlideshowTransitionState.swift    # 新規: プレビューの切り替えの状態遷移・準備完了の判定
└── Playback/VideoPlayback.swift          # AVPlayerItemVideoOutput・currentFrame()
Sources/MediaViewerApp/
├── Settings/SettingsWindowController.swift # スライドショーの区分・Tab 順・確定と Esc
├── Slideshow/SlideshowCoordinator.swift    # 設定の読み出し・終了・切り替えの arm と打ち切り・signpost
├── App/MainSplitViewController.swift       # coordinator の delegate をプレビューへ中継、SettingsStore を渡す
└── Preview/
    ├── PreviewViewController.swift         # contentHostView・SlideshowTransitionState の action の実行
    ├── SlideshowTransitionOverlayView.swift # 新規: snapshot の表示と animation
    ├── ImagePreviewView.swift              # 表示中の contents・frame・gravity を返す
    └── VideoPreviewView.swift              # 一時停止して現在フレームを返す、最初のフレームを表示できる時点の通知
Sources/FixtureKit/FixtureSets.swift        # slideshow/transitions/ を追加
Tests/MediaViewerCoreTests/
├── SlideshowIntervalInputTests.swift      # 新規
├── SettingsStoreTests.swift               # slideshow の既定値・往復・不正値
├── SlideshowSessionTests.swift            # 可変間隔・予定済みの期限の不変
├── SlideshowSequenceTests.swift           # 繰り返しオン／オフ・1件・一覧の更新
├── SlideshowTransitionEffectTests.swift   # 新規: 視差効果を減らす での置き換え
├── SlideshowTransitionStateTests.swift    # 新規: 切り替えの状態遷移・同じ対象で arm しない・準備完了の判定└── SlideshowFixtureTests.swift            # transitions の5件
```

**Structure Decision**: 単一 Package と2つの既存テスト target を保つ。判断（解析・設定の検証・期限・終了・効果の置き換え・切り替えの状態遷移と準備完了の判定）は Core の値型と純粋関数に置き、AppKit・実際の待機・描画を持たない。App は、期限の Task を1つ持つ既存の `SlideshowCoordinator` と、Core の `SlideshowTransitionState` を1つ持ってその action（snapshot・overlay・animation）を実行する `PreviewViewController` に責務を分ける。プレビューは時刻を持たず、準備中の切り替えは coordinator の次の commit・矢印・終了で打ち切る（R8）。新しい target・UI テスト・汎用のアニメーション基盤は追加しない。

## Phase 0 — Research

spec・006 の設計・既存コード（設定、スライドショーの Core と App、プレビュー、動画の再生）を読み、[research.md](research.md) を作成した。主な判断:

- 設定は判断の時点ごとに読み、期限は計算済みの値を書き換えない（R1・R4）。これで FR-132 の「予定済みの時刻は変えない」が成り立つ。
- 終了の判断は最新の一覧からの純粋関数とし、既存の `stop()` に流す（R5）。
- 単一の `AVPlayer` の制約から、効果は「前は snapshot、次は実物」の非対称な構成にする（R6・R7）。
- 準備待ちの打ち切りはプレビューのタイマーではなく次の commit に任せ、時刻の管理を Session の1か所に保つ（R8）。

## Phase 1 — Design

### 1. 設定と設定ウインドウ

- Core に `SlideshowOptions`・`SlideshowTransitionEffect`・`SlideshowIntervalInput` を置き、`SettingsStore.slideshow` で3キーを読み書きする。読み込み時は項目ごとに検証する（EC-75）。
- 設定ウインドウは「スライドショー」の見出しの下に、`[テキストフィールド] 秒` の横並び、繰り返しのチェックボックス、効果のポップアップメニューを置く。ウインドウの高さは内容に合わせて広げる。
- チェックボックスとポップアップは `canBecomeKeyView` を常に true にするサブクラスで作り、`nextKeyView` の順序を明示する（R3）。
- 間隔は Return・フォーカスの移動・ウインドウを閉じる操作で確定し、編集中の Esc は取り消しとして delegate で消費する（R2）。

### 2. 間隔と繰り返し

- `SlideshowCoordinator` に `SettingsStore` を渡す。`start`・受理した矢印・`commitPendingDue` で `slideshow` を読み、Session に間隔を渡す。
- `commitPendingDue` は `SlideshowSequence.advance(in:focused:repeats:)` を呼び、`.finish`・`.empty` で `stop()` する。006 の入力の優先順位（終了 > 矢印 > due）と遅延時の最大1回は変えない。

### 3. 切り替え効果

- `commitPendingDue` で `.target(url)` のとき、まず url が現在のフォーカスと同じか（EC-66 の1件・繰り返しオン）を判定し、同じなら arm しない（準備中の切り替えの打ち切りだけを呼ぶ）。異なれば効果を `effect.effective(reduceMotion:)` で決め、`none` でなければ選択を変える前にプレビューを arm する（delegate の `slideshowBeginTransition(to:current:effect:)`）。それでも選択が変わらなければすぐに打ち切る（R9）。
- プレビューは前の表示の snapshot を overlay に出し、armed の URL が準備完了になった時点で 0.5 秒の animation を追加する（R6〜R8）。holding／animating の遷移・世代の照合・準備完了の判定・打ち切りの条件は Core の `SlideshowTransitionState.reduce` が決め、`PreviewViewController` は返された action を実行するだけにする（data-model §5）。
- 打ち切りは、受理した矢印・`stop()`・`stopImmediately()` で coordinator から呼ぶ（delegate の `slideshowCancelTransition()`）。プレビューは containerView の大きさが変わったときにも自分で打ち切る（R9）。
- signpost に `SlideshowTransitionBegin`／`Start`／`End`／`Cancel` を加える（R10）。

### 4. 006 からの読み替え

006 の「3秒」は設定の間隔とする（FR-118・FR-119・FR-121、A-54）。既存の `SlideshowSessionTests`・`SlideshowSequenceTests` は、間隔 3 秒・繰り返しオンを明示して同じ意味のまま残す。006 の性能テストの `nextTarget` は互換のラッパーで動かす。

### 5. Validation and handoff

要件との対応は [quickstart.md](quickstart.md) を参照。実装 Phase の検証は `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` の順に行う。その後、ユーザーへ `open .build/MediaViewer.app` と確認点（3ペインの表示、設定ウインドウ、間隔・繰り返し・効果のシナリオ）を依頼する。GUI と実時間の計測が未確認なら該当タスクを未チェックに保つ。問題のない Phase をコミットし、実装・検証の後にだけ spec の反映先の表に従って `specs/product/` へ反映する。

本コマンドは Phase 1 の設計で終わる。tasks の生成・ソースの実装・GUI の起動は次の工程で行う。

### Constitution Check（Phase 1 後の再評価）

上の表の「Phase 1 後」の列のとおり、すべて PASS。設計で増えた要素（overlay のビュー、video output、切り替えの状態）は、spec の FR-130・FR-131・EC-78・EC-80 を満たすための最小限であり、汎用化しない。

## Complexity Tracking

憲章違反はない。次の2点は、より単純な案を採らなかった理由を記録する。

| 追加する複雑さ | 必要な理由 | 採らなかった単純な案と理由 |
|---|---|---|
| 動画アイテムへの `AVPlayerItemVideoOutput` の付与 | 前の動画を切り替えの開始時点のフレームで静止させて効果に使う（Clarifications、EC-78）。単一の `AVPlayer` を使い回すので、次のメディアの読み込みでプレーヤーの表示が消える | 前の動画をプレーヤーに残す案は、次も動画のとき単一プレーヤーと衝突する。`AVAssetImageGenerator` は非同期で zip 内動画では間に合わない |
| プレビューの切り替えの状態（holding／animating と世代）を Core の値型 `SlideshowTransitionState` に置く | 準備待ち（EC-80）と、効果中の矢印・Esc・全画面の即時反映（FR-131、SC-041）を両立する。遷移・世代の照合・準備完了の判定・打ち切りの条件を自動テストするため、App から切り出す（憲章 IV、analyze D1） | 準備完了まで commit を遅らせる案は FR-118（間隔を延ばさない）に反する。プレビュー独自の期限は Session の期限と二重管理になる。状態を `PreviewViewController` の中に持つ案は、判断ロジックが自動テストされない |
