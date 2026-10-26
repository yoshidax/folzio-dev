# Implementation Plan: プレビュー画像の拡大・縮小

**Branch**: `008-preview-image-zoom` | **Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

**Input**: `specs/008-preview-image-zoom/spec.md`、spec が参照する `specs/product/` の領域（preview.md・window-layout.md・navigation-history.md・file-list.md・overview.md）と [contracts/keyboard-and-menus.md](../product/contracts/keyboard-and-menus.md)。憲章 v1.2.0。

## Summary

プレビューに表示中の画像を、ツールバーの3ボタン（拡大・表示領域に合わせる・縮小）、「表示」メニューの3項目、⌘+・⌘-・⌘0（拡大は ⌘= でも可）で25%刻みに拡大・縮小する。フィット表示を100%とし、25%以上800%以下で頭打ちにする。画像は縦横比を保って中央に置き、ビューポートからはみ出した部分は表示しない。動画・空・表示不能・ファイルリストのみ表示では無効。別の画像へ切り替わったときと履歴の移動後は100%に戻し、フルスクリーン・サイズ変更・同じ画像を表示したままのペイン復帰では保つ。倍率は保存せず、履歴の表示の状態にも記録しない。

判断は Core の値型（`PreviewZoom`・`PreviewZoomTracker`・`PreviewZoomAvailability`）に置き、`PreviewViewController` が表示との対応を取る。描画は既存の `ImagePreviewView` の `CALayer` の frame を変えるだけで、再デコードも画像の作り直しもしない。既存のサムネイルサイズ変更は ⌃⌘+ / ⌃⌘- へ移す。根拠は [research.md](research.md)、型と遷移は [data-model.md](data-model.md)、UI とキーの差分契約は [contracts/preview-zoom.md](contracts/preview-zoom.md) を参照。

## Technical Context

**Language/Version**: Swift 6（Package の `swiftLanguageModes: [.v6]`）

**Primary Dependencies**: Foundation／Swift Concurrency、AppKit、CoreGraphics。既存の Core Animation（QuartzCore）・ImageIO の使い方は変えない。外部パッケージの追加なし。Core は AppKit を import しない。

**Storage**: なし。倍率は保存せず、履歴（`HistoryPresentation`・`HistoryViewState`）にも加えない。UserDefaults のキーを追加しない。

**Testing**: Swift Testing。Core の倍率の加減・上下限・リセット判定・有効条件・フィットへの倍率適用を単体テストする。ツールバーの見た目、メニューとキーの到達性、VoiceOver、実時間はユーザーによる `.app` の手動確認と Instruments（OS Signposts）で確かめる。

**Target Platform**: macOS 15 以降

**Project Type**: AppKit デスクトップアプリ + Core ライブラリ、単一 Swift Package

**Performance Goals**: SC-043〜SC-052。特に SC-048（24MP 以下の JPEG で拡大・縮小・フィット各10回が0.5秒以内、操作中に UI が応答しない回数0回）と、既存の先読み済み切り替え100ms・初回画像1秒・10,000件で UI を止めない基準を維持する。倍率変更はデコードを伴わない O(1) のレイアウト計算だけにする。

**Constraints**: オフライン・ネットワーク API 不使用。デコード・列挙・ファイル操作を UI スレッドで行わない。スクロール・パン・ドラッグ・ピンチ・倍率の数値表示・スライダー・画像ごとの倍率の保存は追加しない（A-64）。動画には適用しない。Core は AppKit に依存しない。GUI の起動はユーザーが行う。

**Scale/Scope**: 同時に表示する画像は1枚。倍率は25〜800%の32段。`PreviewViewController` に状態を1つ、ツールバーに3セグメント、表示メニューに3項目を加える。新しい画面・設定・永続化はない。

**Resolved design questions**: NEEDS CLARIFICATION はない。spec の Clarifications 14問（ボタンの並び、100%の基準、刻み、⌘+ / ⌘- の移行、画像切替時の戻し、見えない部分、スライドショー、保存と履歴、メニュー名、契約の読み替え、履歴の記録、VoiceOver、⌘=、シート等での制限）を前提に、R1〜R10 を research.md に記す。

## Constitution Check

*Phase 0 の前と Phase 1 の後に評価。PASS は設計の適合の判定であり、実装・GUI 検証が済んだという意味ではない。*

| 原則・ゲート | Phase 0 前 | Phase 1 後の設計と検証方針 |
|---|---|---|
| I ローカル完結 | PASS | 通信・送信・ファイル変更・保存の追加なし。倍率はメモリだけ。no-network チェックを実行する |
| II 性能 | PASS | 倍率変更は `CALayer.frame` の再計算だけで、再デコード・再描画・列挙をしない。Core のレイアウト計算が O(1) であることを性能テストで測り、SC-048 は signpost と Instruments で実測して記録する。既存の基準を変えない |
| III キーボード・アクセシビリティ | PASS | ⌘+・⌘-・⌘0 と ⌘= をメニューのキー等価で提供し、ツールバー非表示・フルスクリーン・シート・設定ウインドウがキーのときも届く。3ボタンにラベルとショートカット入りツールチップ、プレビューに倍率のアクセシビリティ値と変更の読み上げを付ける。可視の数値表示は増やさない |
| IV テスト必須 | PASS | 倍率の加減・上下限・不正値、画像の同一性によるリセット、履歴の明示リセット、有効条件、フィットへの倍率適用と中央配置・はみ出しを Core でテストする。破損画像・1×1・100MP 等の異常系は既存のデコード経路とフィクスチャで確認する。描画と VoiceOver は手動ゲート |
| V シンプルさ | PASS | 新しい依存なし（OS 標準のみ）。倍率のスライダー・プリセット・画像ごとの記憶・ジェスチャーを作らない。既存の `FitCalculator`・`ImagePreviewView`・ツールバーのグループ化・メニューの検証を拡張する |
| 技術制約・AppKit 不変条件 | PASS | UI の変更は MainActor のみ。制約は `addSubview` の後に有効化する。`NSSplitViewDelegate` の禁止メソッドに触れない。レイヤーのモデル値の frame を変えるだけで、Auto Layout の制約は追加しない。Core は AppKit を import しない |
| 仕様管理・検証ゲート | PASS | 成果物は本 feature に限る。実装中は tasks のチェックと明示タスクの追記だけ。`specs/product/` への反映は実装・検証の後。GUI 未確認を完了にしない |

違反・例外の申請はない。

## Project Structure

### Documentation (this feature)

```text
specs/008-preview-image-zoom/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── contracts/preview-zoom.md
├── quickstart.md
└── tasks.md                 # 次の /speckit-tasks で生成。本コマンドでは作らない
```

### Source Code (repository root)

以下は実装先の予定。既存ファイルの修正を優先し、新規には「新規」を付す。

```text
Sources/MediaViewerCore/
└── Layout/
    ├── FitCalculator.swift          # frame(imageSize:in:zoom:) を追加。fit は互換のまま
    └── PreviewZoom.swift            # 新規: PreviewZoom・PreviewZoomTracker・PreviewZoomAvailability
Sources/MediaViewerApp/
├── App/
│   ├── AppDelegate.swift            # メニューの target・検証・3操作の転送
│   ├── MainMenu.swift               # 表示メニューの3項目・区切り線・⌘= の非表示項目
│   ├── MainWindowController.swift   # 倍率の有効条件と操作を AppDelegate へ公開
│   ├── MainSplitViewController.swift # 操作の転送・有効条件の通知・履歴移動後のリセット
│   └── MainToolbarController.swift  # 3セグメントのグループ・セグメント単位の有効化
├── Preview/
│   ├── ImagePreviewView.swift       # 倍率を適用した frame・クリップ・アクセシビリティ値/読み上げ
│   └── PreviewViewController.swift  # 倍率の状態・画像同一性・表示との対応・signpost
└── FileList/FileListViewController.swift # サムネイルの拡大・縮小を ⌃⌘+ / ⌃⌘- へ移す
Sources/FixtureKit/FixtureSets.swift  # zoom/ を追加（小さい画像・縦横・24MP）
Tests/MediaViewerCoreTests/
├── PreviewZoomTests.swift            # 新規: 倍率・トラッカー・有効条件
└── FitCalculatorTests.swift          # 倍率適用・中央配置・はみ出し・異常系を追加
Tests/MediaViewerPerformanceTests/
└── PreviewZoomPerformanceTests.swift # 新規: レイアウト計算が基準内
```

**Structure Decision**: 単一 Package と既存の2テスト target を保つ。倍率の加減・上下限・リセット判定・有効条件・フィットへの適用は Core の値型と純粋関数に置き、AppKit を持たない。App は、表示中の画像と倍率の対応を `PreviewViewController`、描画を `ImagePreviewView`、入口をツールバー・メニュー・ショートカットに分ける。メニューのキー等価は明示的な target（`AppDelegate`）に集約し、キー入力先のウィンドウに依存しないようにする。新しい target・UI テスト・汎用の入力基盤は追加しない。

## Phase 0 — Research

spec・product の領域・既存コード（プレビュー、フィット計算、ツールバー、メニュー、履歴、スライドショー）を読み、[research.md](research.md) を作成した。主な判断:

- 倍率は加算25ポイントの `PreviewZoom`、画像の同一性による戻しは `PreviewZoomTracker` に置く（R1・R3）。
- フィットの矩形を中心基準で拡大し、`ImagePreviewView` の `contentLayer.frame` に反映する。クリップ以外は変えない（R2・R4）。
- メニューは明示的な `AppDelegate` target とし、⌘= は非表示の重複項目で受ける。これでシート・設定ウインドウがキーのときも届く（R7）。
- サムネイルサイズ変更の ⌃⌘+ / ⌃⌘- への移行は、メニューの修飾キーとスライダーの説明だけに閉じる（R7）。
- 有効条件は Core の `PreviewZoomAvailability` に集約し、ツールバーはセグメント単位、メニューは `validateMenuItem` で同じ条件を使う（R5）。
- 描画中のアニメーションは止めず、`contents` を差し替える既存経路を変えない（R4・R9）。

## Phase 1 — Design

### 1. 倍率の値と状態（Core）

- `PreviewZoom`: 25〜800% の25%刻み。`fit`（100%）から `zoomedIn()`・`zoomedOut()` で1段ずつ動かし、上下限では同じ値を返す。不正な構成は作れない。
- `FitCalculator.frame(imageSize:in:zoom:)`: 既存の `fit` の矩形を中心基準で `percentage / 100` 倍する。100% は既存の `fit` と一致する。0以下の入力は `.zero`。
- `PreviewZoomTracker`: `level` と表示中の画像の同一性（URL）を持ち、`present(_:)` で別の画像に変わったときだけ100%へ戻す。`reset()` は履歴移動用。空・動画・表示不能は `nil` を渡して戻す。
- `PreviewZoomAvailability`: 画像を表示しているか・プレビューが見えているか・現在の倍率から、3操作の可否と `canZoomIn` / `canZoomOut` / `canFit` を導く。

### 2. 表示とリセット

- `PreviewViewController` は `PreviewZoomTracker` を1つ持ち、`updateFromModel` の各分岐で表示対象の同一性を渡す。`showImage` / `showAnimated` のあとに現在の倍率を `ImagePreviewView` へ適用する。
- 別の画像・履歴の移動後は100%、同じ画像のままの再表示・フルスクリーン・サイズ変更・ペイン復帰・スライドショー開始は現在の倍率を保つ。動画・空・表示不能・ファイルリストのみ表示は無効にし、次に画像を表示するときは100%から始める。
- `MainSplitViewController.applyHistoryPresentation`（履歴の移動が成立したときだけ `HistoryNavigator` から呼ばれる）で `resetZoom()` を呼ぶ。倍率変更の操作は `HistoryNavigator` に渡さない。
- スライドショーの自動送り・手動移動・選択変更は、`updateFromModel` が新しい画像の同一性を見て100%に戻す。切り替え効果の状態・期限には触れない。

### 3. 描画とアクセシビリティ

- `ImagePreviewView` の `layout()` で、ビューポートに対するフィットの矩形に現在の倍率を掛け、中央に置く。ビューポートより大きい場合は負の原点になり、`masksToBounds` で切り抜く。スクロール・パンは追加しない。
- 再デコードせず、表示中の `CGImage` の `contents` を共有したまま `frame` だけを変える。アニメーションのフレーム更新は既存の `setDisplayed` を通し、倍率を変えても再生をやり直さない。
- 画像表示中はアクセシビリティの値に `"125%"` のような百分率を公開し、明示的な操作で倍率が変わったときだけ新しい値を読み上げる。数値のラベル・スライダーは追加しない。画像がない状態では値を公開しない。
- `PreviewViewController` の表示更新時に `onZoomAvailabilityChange` を通知し、アニメーションの最初のフレームが届いたときも通知する。倍率を適用する区間は既存の `OSSignposter` に `PreviewZoomApply` として記録する。

### 4. ツールバー

- `MainToolbarController` に `previewZoom` のグループを追加し、「スライドショーを開始」の右隣、種類フィルタの左に置く。セグメントは左から `plus.magnifyingglass`（拡大）、`arrow.up.left.and.down.right.magnifyingglass`（表示領域に合わせる）、`minus.magnifyingglass`（縮小）。3つを `NSSegmentedControl`（`.momentary`）で隙間なく並べる。
- ツールバーの項目は画像を表示してプレビューが見えているときだけ有効にし、上限では拡大、下限では縮小のセグメントを無効にする。ツールチップは「拡大（⌘+）」「表示領域に合わせる（⌘0）」「縮小（⌘-）」、アクセシビリティのラベルは「拡大」「表示領域に合わせる」「縮小」。
- `PreviewViewController.onZoomAvailabilityChange` を `MainSplitViewController` が受け、ツールバーのセグメントと項目の有効状態を更新する。ペイン表示の変更でも同じ更新を通す。

### 5. 表示メニューとショートカット

- `MainMenu` の「表示」で「フルスクリーン」の下に区切り線を置き、「拡大」「縮小」「表示領域に合わせる」をこの順で追加する。キーは ⌘+・⌘-・⌘0。3項目の target は `AppDelegate` にし、`NSMenuItemValidation` で `PreviewZoomAvailability` を返す。
- ⌘= と ⇧⌘= の拡大は、同じ action を持つ非表示の `NSMenuItem`（keyEquivalent `=`、⌘、`isHidden = true`、`allowsKeyEquivalentWhenHidden = true`）で受ける。表示は ⌘+ のまま変えない。非表示の項目は `allowsKeyEquivalentWhenHidden`（既定は false）を true にしたときだけキー等価の照合に参加するため、この設定を必須とし、実キーでの到達は手動シナリオで確かめる（R7）。
- 既存の「サムネイルを拡大」「サムネイルを縮小」の修飾キーを ⌃⌘ に変え、ツールバーのサイズのスライダーと下部バーの説明に ⌃⌘+ / ⌃⌘- を反映する。⌘+ / ⌘- はプレビューの倍率だけを変え、画像がないときは何もしない。
- シート・モーダル・名前の変更中・設定ウインドウがキーのときも、FR-136 の条件だけを適用する。追加の入力制限は設けない。

### 6. Validation and handoff

要件との対応は [quickstart.md](quickstart.md) を参照。実装 Phase の検証は `swift build` → `swift test` → `scripts/check-no-network.sh` → `scripts/make-app.sh` の順に行う。その後、ユーザーへ `open .build/MediaViewer.app` と確認点（3ペイン、ツールバーの3ボタン、メニュー、⌘+・⌘-・⌘0・⌘=、上限・下限、画像切替・履歴・全画面・ペイン復帰、⌃⌘+ / ⌃⌘-、VoiceOver）を依頼する。GUI・VoiceOver・実時間が未確認なら該当タスクを未チェックに保つ。問題のない Phase をコミットし、実装・検証の後にだけ spec の反映先の表に従って `specs/product/` へ反映する。

本コマンドは Phase 1 の設計で終わる。tasks の生成・ソースの実装・GUI の起動は次の工程で行う。

### Constitution Check（Phase 1 後の再評価）

上の表の「Phase 1 後」の列のとおり、すべて PASS。設計で増えた要素（倍率の値型、非表示のキー項目、ツールバーの3セグメント）は、FR-133〜FR-138 を満たすための最小限であり、汎用の入力・描画基盤にはしない。

## Complexity Tracking

憲章違反はない。次の点は、より単純な案を採らなかった理由を記録する。

| 追加する複雑さ | 必要な理由 | 採らなかった単純な案と理由 |
|---|---|---|
| 表示メニューの3項目の target を `AppDelegate` にし、⌘= 用の非表示項目を1つ持つ | シート・設定ウインドウがキーのときも ⌘+・⌘-・⌘0 を届かせ、⌘= と ⇧⌘= の両方を受け付ける（FR-135、A-73）。target を nil にするとキーウィンドウの responder chain に依存する | キー入力先ごとの `keyDown` やローカルモニタは、ウィンドウ・モーダルの組み合わせごとに入力経路が増える。⌘= を可視の別項目にするとメニューの表示が要件と変わる |
| ツールバーのグループを `NSSegmentedControl` の3セグメントにする | 既存の履歴・ペイン・種類フィルタと同じ見た目と幅で、セグメント単位の有効化・ツールチップ・キーボード到達性を保つ（FR-134、FR-045） | 3つの独立した `NSButton` はグループの見た目が既存と揃わず、有効化の同期も増える。アイコンの独自描画は SF Symbols で足りるため不要 |
| 倍率の状態を `PreviewZoomTracker`（Core）に分ける | 画像の同一性による戻し・履歴後の戻し・上下限を AppKit なしで単体テストする（憲章 IV）。表示中の画像との対応をモデルや履歴へ混ぜない（FR-137） | `PreviewViewController` に直接持つと判断ロジックがテストできない。`BrowserModel` に持たせると UI だけの状態がモデル・履歴の関心に混ざる |
