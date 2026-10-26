# Data Model: プレビュー画像の拡大・縮小

**Date**: 2026-10-27 | **Spec**: [spec.md](spec.md)

以下は設計上の型と責務。実装時の名前は対応関係を保てば調整してよい。Core の型は AppKit に依存しない。既存のプレビュー・履歴・スライドショーの型は、ここに記した変更以外は変えない。

## 1. 表示倍率 — PreviewZoom（Core、新規）

`Sources/MediaViewerCore/Layout/PreviewZoom.swift`

| フィールド | 型 | 制約 |
|---|---|---|
| `percentage` | `Int` | 25以上800以下、かつ25の倍数。32通りだけを取る |

定数:

| 名前 | 値 | 意味 |
|---|---|---|
| `PreviewZoom.step` | 25 | 1回の拡大・縮小のポイント |
| `PreviewZoom.minimum` | 25 | 下限（%） |
| `PreviewZoom.maximum` | 800 | 上限（%） |
| `PreviewZoom.fit` | 100 | フィット表示。FR-028 の既定表示 |
| `scale` | `CGFloat(percentage) / 100` | フィットの矩形に掛ける倍率 |

初期化と操作:

| API | 結果 |
|---|---|
| `init?(percentage:)` | 25の倍数かつ25〜800のときだけ生成する。それ以外は `nil` |
| `zoomedIn() -> PreviewZoom` | 25ポイント加算。800%では自分自身 |
| `zoomedOut() -> PreviewZoom` | 25ポイント減算。25%では自分自身 |
| `canZoomIn` / `canZoomOut` | 上限・下限に達していないか |

**不変条件**:

- 生成できる値は25〜800%の25%刻みだけ。0%・30%・801%・負値は存在しない。
- 100%はフィット表示であり、原寸ではない（A-62）。
- 上限・下限を超える操作は値を変えない。反対端へ循環しない（EC-85）。

対応: FR-133、US14-AS1・AS2・AS7、EC-85、A-62。

## 2. 表示中の倍率と画像の同一性 — PreviewZoomTracker（Core、新規）

`Sources/MediaViewerCore/Layout/PreviewZoom.swift`

| フィールド | 型 | 意味 |
|---|---|---|
| `level` | `PreviewZoom` | 現在の倍率。初期値は `.fit` |
| `imageIdentity` | `URL?` | 現在表示している画像の同一性。画像がない状態は `nil` |

操作:

| API | 結果 |
|---|---|
| `present(_ identity: URL?) -> Bool` | 前回の同一性と異なるとき `level` を `.fit` に戻し、`imageIdentity` を更新する。戻したら true |
| `reset() -> Bool` | `imageIdentity` を保ったまま `level` を `.fit` に戻す。戻したら true（履歴移動用） |
| `zoomIn() -> Bool` | 可能なら1段上げる。変わったら true |
| `zoomOut() -> Bool` | 可能なら1段下げる。変わったら true |
| `fit() -> Bool` | `.fit` に戻す。変わったら true |

`present` の同一性:

| 渡す値 | 意味 |
|---|---|
| 画像の URL | 通常画像・アニメーション GIF・アニメーション WebP（通常ファイル／zip 内） |
| `nil` | 空のプレビュー・動画・表示不能な画像・読み込み開始前 |

**不変条件**:

- 同じ URL を渡し続けても倍率は変わらない。表示の再構築・サイズ変更・フルスクリーン・ペイン復帰で失われない。
- 異なる URL を渡すと100%になる。新しい画像は常にフィットから始まる。
- `reset()` は同じ URL でも100%にする。履歴の戻る・進むはこの操作を使う。
- 倍率は `UserDefaults` に保存しない。`HistoryPresentation`・`HistoryViewState` に含めない。
- `zoomIn` / `zoomOut` / `fit` は履歴を記録しない。呼び出し側も `recordViewChange` を呼ばない。

対応: FR-137、US14-AS5・AS8・AS15、EC-87・EC-88・EC-90、A-66・A-70。

## 3. 操作の可否 — PreviewZoomAvailability（Core、新規）

`Sources/MediaViewerCore/Layout/PreviewZoom.swift`

| フィールド | 型 | 意味 |
|---|---|---|
| `isImageDisplayed` | `Bool` | プレビューが画像を実際に表示しているか。アニメーションの最初のフレーム待ちは false |
| `isPreviewVisible` | `Bool` | 3ペイン表示・プレビューのみ表示・フルスクリーンのいずれかで、プレビューが見えているか |
| `level` | `PreviewZoom` | 現在の倍率 |

導出:

| プロパティ | 条件 |
|---|---|
| `isAvailable` | `isImageDisplayed && isPreviewVisible` |
| `canZoomIn` | `isAvailable && level.canZoomIn` |
| `canZoomOut` | `isAvailable && level.canZoomOut` |
| `canFit` | `isAvailable` |

**不変条件**:

- 動画・空のプレビュー・表示不能な画像・ファイルリストのみ表示では `isAvailable = false`。
- 画像を表示していれば、100%でも `canFit = true`。
- 800%では `canZoomIn = false`、25%では `canZoomOut = false`。3操作すべてが同時に無効になるのは `isAvailable = false` のときだけ。
- シート・モーダル・名前の変更中・設定ウインドウがキーであることは条件に含めない（A-73）。

対応: FR-134・FR-136、US14-AS6、EC-85・EC-89、SC-046。

## 4. フィットへの倍率適用 — FitCalculator（Core、変更）

`Sources/MediaViewerCore/Layout/FitCalculator.swift`

```swift
public struct FitCalculator {
    // 既存。100%の矩形。互換のため残す
    public static func fit(imageSize: CGSize, in container: CGSize) -> CGRect

    // 追加。fit の矩形を中心基準で zoom.scale 倍する
    public static func frame(
        imageSize: CGSize,
        in container: CGSize,
        zoom: PreviewZoom
    ) -> CGRect
}
```

| 入力 | 結果 |
|---|---|
| 正常なサイズ、`zoom = .fit` | `fit(imageSize:in:)` と完全に同じ矩形 |
| 正常なサイズ、125% | 幅・高さがフィットの1.25倍。中心は同じ。コンテナより大きければ原点は負 |
| 正常なサイズ、25% | 幅・高さがフィットの0.25倍。中央に配置 |
| 画像・コンテナのいずれかが0以下 | `.zero` |
| 1×1 の画像、800% | 幅・高さがコンテナの8倍。原点は `(container - size) / 2` の負値 |

**不変条件**:

- 縦横比はフィットの矩形から変えない。
- 中心は常にコンテナの中心。スクロール・パンによる移動はしない。
- ビューポートが変わればフィットから再計算する。現在の倍率は「新しいフィット」に対する倍率として適用する。
- 丸めはしない（1ポイントの揺れを避ける）。

対応: FR-028・FR-029・FR-133、EC-81、SC-043・SC-044。

## 5. App 側の状態と責務

| 型 | 状態・責務 |
|---|---|
| `PreviewViewController` | `PreviewZoomTracker` を1つ持つ。`updateFromModel` で `model.preview` から同一性を渡す。`imageView` に倍率を適用する。`onZoomAvailabilityChange` を通知する。スライドショーの切り替え・期限には触れない |
| `ImagePreviewView` | 描画用の `PreviewZoom` を持つ。`layout()` で `FitCalculator.frame` を使う。`masksToBounds`。アクセシビリティの値と読み上げ。アニメーションの最初のフレーム・画像のクリアを `onDisplayedImageChange` で知らせる。アニメーションのフレーム更新では倍率を変えない |
| `MainSplitViewController` | 倍率の有効条件を公開し、ツールバー・`AppDelegate` へ中継する。履歴の移動が成立したときだけ呼ばれる `applyHistoryPresentation` で `resetZoom()` を呼ぶ。履歴には記録しない |
| `MainWindowController` | `zoomAvailability` と3操作を `AppDelegate` へ公開する |
| `AppDelegate` | 表示メニューの3項目と ⌘= の target。`NSMenuItemValidation`。キー入力先のウィンドウに依存しない入口 |
| `MainToolbarController` | `previewZoom` の3セグメント。項目全体とセグメント単位の有効化。ツールチップ・ラベル |
| `FileListViewController` | サムネイルの拡大・縮小のメニューを ⌃⌘+ / ⌃⌘- にする。プレビューの倍率には触れない |

### 5.1 倍率のリセットと保持

| 出来事 | 倍率 | 対応 |
|---|---|---|
| 起動、画像を表示していない状態から最初の画像 | 100% | FR-137 |
| ファイルリストの選択変更で別の画像 | 100% | US14-AS5 |
| プレビューのみ表示・フルスクリーン中の矢印移動で別の画像 | 100% | FR-137 |
| スライドショーの自動送り・手動移動で別の画像 | 100% | US14-AS10 |
| 履歴の戻る・進む（同じ画像に戻る場合を含む） | 100% | US14-AS15・EC-88 |
| フルスクリーンの切替 | 現在の倍率を保つ | US14-AS8 |
| ウィンドウ・ペイン・ツールバーの表示切替 | 現在の倍率を保つ | FR-137 |
| 同じ画像を表示したままプレビューを隠して戻す | 現在の倍率を保つ | EC-87 |
| 隠れている間に選択が変わった | 戻したとき100% | EC-87 |
| 動画・空・表示不能・ファイルリストのみ表示 | 操作不可。次に画像を表示するとき100% | FR-136 |
| スライドショー開始（同じ画像のまま） | 現在の倍率を保つ | FR-137 |
| スライドショーの切り替え効果の進行中 | 現在の倍率を保つ／変更できる。効果の時間は変えない | EC-86 |

### 5.2 画像の同一性

- `.image` は `model.selection.focused` を同一性とする。`PreviewContent.image` は URL を持たないため、選択中の URL を使う。
- `.animatedImage(url)`・`.animatedImageData(url, _)` はその URL。
- `.loading(url)` は読み込み対象の URL。新しい対象ならこの時点で100%になる。
- `.empty`・`.video`・`.unavailable` は `nil`。
- 同じ URL でも、履歴移動だけは `reset()` で明示的に100%にする。

## 6. 入口とキーの対応

| 入口 | 操作 | 有効条件 |
|---|---|---|
| ツールバー 左セグメント | 拡大 | `canZoomIn` |
| ツールバー 中セグメント | 表示領域に合わせる | `canFit` |
| ツールバー 右セグメント | 縮小 | `canZoomOut` |
| 表示メニュー「拡大」⌘+ | 拡大 | `canZoomIn` |
| 表示メニュー「縮小」⌘- | 縮小 | `canZoomOut` |
| 表示メニュー「表示領域に合わせる」⌘0 | 100% | `canFit` |
| 非表示の「拡大」項目 ⌘=／⇧⌘= | 拡大 | `canZoomIn` |
| サムネイルを拡大／縮小 ⌃⌘+ / ⌃⌘- | ファイルリストのサムネイルサイズ | 既存の条件（プレビュー倍率とは独立） |

**不変条件**:

- メニュー・ツールバー・キーのどれから実行しても同じ `PreviewZoomTracker` を更新する。
- キーはキー入力先のウィンドウに依存しない。シート・設定ウインドウ・名前の変更中でも、`canZoomIn` などが true なら実行する。
- 実行しても `HistoryNavigator`・`UserDefaults`・`model.listing`・`model.selection` を変えない。
- 100%のフィットは画像の初期表示として自動でも行う（A-12）。

## 7. アクセシビリティ

| 要素 | 値・ラベル | 更新 |
|---|---|---|
| プレビューの画像要素 | ラベル: ファイル名。値: `"125%"` など現在の倍率 | 画像表示中だけ値を持つ。画像がない状態では `nil` |
| ツールバーの3セグメント | 「拡大」「表示領域に合わせる」「縮小」 | セグメントのツールチップに ⌘+・⌘0・⌘- |
| 表示メニューの3項目 | 「拡大」「縮小」「表示領域に合わせる」 | 無効時は AppKit が無効として公開する |
| 読み上げ | 明示的な操作で倍率が変わったとき、新しい百分率 | `announcementRequested`（medium）。可視の数値表示はない |

- 画像のない状態では倍率の値を公開せず、3操作を無効にする（FR-138）。
- リセット（画像切替・履歴）では、値は更新するが、操作による変更ではないため読み上げの通知はしない。
- 同じ倍率になる操作（100%でフィット、上限で拡大）は値を変えず、通知もしない。
