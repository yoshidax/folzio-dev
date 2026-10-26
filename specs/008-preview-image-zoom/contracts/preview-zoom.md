# Contract: プレビュー画像の拡大・縮小

**Date**: 2026-10-27 | **Branch**: `008-preview-image-zoom`

本 feature の差分契約。要件の本文は [spec.md](../spec.md) を正とする。既存の `specs/product/` の [preview.md](../../product/preview.md)・[window-layout.md](../../product/window-layout.md)・[navigation-history.md](../../product/navigation-history.md)・[file-list.md](../../product/file-list.md)・[overview.md](../../product/overview.md)、および [contracts/keyboard-and-menus.md](../../product/contracts/keyboard-and-menus.md) に対する追加・変更を記す。実装・検証の後に spec の「反映先」に従って product へ反映するまでは本 feature 内に置く。外部サービス・HTTP API・CLI は追加しない。

## MediaViewerCore の公開 API

`Sources/MediaViewerCore/Layout/PreviewZoom.swift`（新規）

```swift
public struct PreviewZoom: Sendable, Equatable, Comparable {
    public static let step: Int          // 25
    public static let minimum: Int       // 25
    public static let maximum: Int       // 800
    public static let fit: PreviewZoom   // 100%

    public let percentage: Int
    public var scale: CGFloat { get }    // percentage / 100

    public init?(percentage: Int)        // 25〜800 の25の倍数だけ
    public var canZoomIn: Bool { get }
    public var canZoomOut: Bool { get }
    public func zoomedIn() -> PreviewZoom
    public func zoomedOut() -> PreviewZoom
}

public struct PreviewZoomTracker: Sendable, Equatable {
    public private(set) var level: PreviewZoom
    public private(set) var imageIdentity: URL?

    public init()
    @discardableResult public mutating func present(_ identity: URL?) -> Bool
    @discardableResult public mutating func reset() -> Bool
    @discardableResult public mutating func zoomIn() -> Bool
    @discardableResult public mutating func zoomOut() -> Bool
    @discardableResult public mutating func fit() -> Bool
}

public struct PreviewZoomAvailability: Sendable, Equatable {
    public var isImageDisplayed: Bool
    public var isPreviewVisible: Bool
    public var level: PreviewZoom

    public init(isImageDisplayed: Bool, isPreviewVisible: Bool, level: PreviewZoom)
    public var isAvailable: Bool { get }
    public var canZoomIn: Bool { get }
    public var canZoomOut: Bool { get }
    public var canFit: Bool { get }
}
```

`Sources/MediaViewerCore/Layout/FitCalculator.swift`（変更）

```swift
extension FitCalculator {
    public static func frame(
        imageSize: CGSize,
        in container: CGSize,
        zoom: PreviewZoom
    ) -> CGRect
}
```

- 100%は既存の `fit(imageSize:in:)` と一致する。既存 API のシグネチャ・意味は変えない。
- 0以下のサイズは `.zero`。縦横比と中央配置を保つ。はみ出す場合は原点が負になる。

意味・不変条件・状態遷移は [data-model.md](../data-model.md) を参照。

## App 側の接続点

| 型 | 契約 |
|---|---|
| `PreviewViewController` | `PreviewZoomTracker` を1つ持つ。`zoomIn()` / `zoomOut()` / `zoomToFit()` は実行できたら true。`zoomAvailability` を公開。`resetZoom()`。`onZoomAvailabilityChange: (() -> Void)?` |
| `ImagePreviewView` | `applyZoom(_:announce:)`。`isShowingImage`。`onDisplayedImageChange: (() -> Void)?`（最初のフレーム・画像のクリア）。`layout()` で `FitCalculator.frame` を使う。画像表示中はアクセシビリティの値に百分率を持つ |
| `MainSplitViewController` | `zoomAvailability`、`zoomIn()` / `zoomOut()` / `zoomToFit()`、`resetZoom()`。`onZoomAvailabilityChange` をツールバーへ中継。履歴の移動が成立したときだけ呼ばれる `applyHistoryPresentation` で `resetZoom()` |
| `MainWindowController` | `zoomAvailability` と3操作を `AppDelegate` へ公開 |
| `AppDelegate` | `@objc previewZoomIn(_:)` / `previewZoomOut(_:)` / `previewZoomToFit(_:)`。`NSMenuItemValidation` で `zoomAvailability` を返す |
| `MainToolbarController` | `previewZoom` の `NSToolbarItem`。3セグメント。項目全体とセグメント単位の有効化 |
| `FileListViewController` | サムネイルの拡大・縮小の keyEquivalent を `.` / `,`、keyEquivalentModifierMask を `[.command, .control]` にする（⌃⌘. / ⌃⌘,） |

## ツールバー

並びは「スライドショーを開始」の右隣、種類フィルタの左。

```text
[履歴] [ペイン] [スライドショーを開始] [拡大|表示領域に合わせる|縮小] [種類] [zip] [表示形式] [サイズ]
```

| セグメント | 画像 | ラベル | ツールチップ | 有効条件 |
|---|---|---|---|---|
| 1（左） | `plus.magnifyingglass` | 拡大 | 拡大（⌘+） | `canZoomIn` |
| 2（中） | `arrow.up.left.and.down.right.magnifyingglass` | 表示領域に合わせる | 表示領域に合わせる（⌘0） | `canFit` |
| 3（右） | `minus.magnifyingglass` | 縮小 | 縮小（⌘-） | `canZoomOut` |

- 3つは1つの `NSSegmentedControl` として隙間なく並べる。trackingMode は `.momentary` で、押した状態を保たない（A-61）。
- 100%のときも中セグメントは押された見た目にしない。
- 画像を表示していない・プレビューが見えていないときは項目全体を無効にする。上限・下限では該当セグメントだけを無効にする。
- ライト・ダークの両方の外観で3つを区別できる（テンプレート画像）。VoiceOver で各セグメントのラベルを読み上げる。

対応: FR-134・FR-045、US14-AS11、SC-049、A-61・A-65。

## 表示メニュー

「表示」の「フルスクリーン」の下に区切り線を置き、次の順で追加する。既存の「スライドショーを開始」はその後に残す。

```text
表示
  ツールバーを表示／隠す            ⇧⌘T
  ─────────────
  フルスクリーン                    ⌃⌘F
  ─────────────
  拡大                              ⌘+
  縮小                              ⌘-
  表示領域に合わせる                ⌘0
  スライドショーを開始              ⇧⌘S
  サムネイル                        ⌘1
  リスト                            ⌘2
  サムネイルを拡大                  ⌃⌘.
  サムネイルを縮小                  ⌃⌘,
  ...
```

| 項目 | 表示 | キー | 有効条件 |
|---|---|---|---|
| 拡大 | 拡大 | ⌘+（⇧⌘= と ⌘= も受け付ける） | `canZoomIn` |
| 縮小 | 縮小 | ⌘- | `canZoomOut` |
| 表示領域に合わせる | 表示領域に合わせる | ⌘0 | `canFit` |

- メニューとツールチップの表示は ⌘+ のまま。⌘= 用の非表示項目は表示しない。非表示項目は `isHidden = true` と `allowsKeyEquivalentWhenHidden = true` の両方を設定し、表示しないままキー等価に参加させる。
- 3項目の target は `AppDelegate`。キー入力先のウィンドウに依存せず、シート・設定ウインドウ・名前の変更中でも FR-136 の条件だけで実行する（A-73）。
- 画像がない・動画・空・表示不能・ファイルリストのみ表示では3項目を無効にし、キーは何もしない。上限では拡大、下限では縮小だけを無効にする。
- 実行しても履歴を記録しない。`HistoryPresentation`・`HistoryViewState` を変えない。

対応: FR-135・FR-136・FR-137、US14-AS1〜AS4・AS6・AS7・AS12・AS15・AS16。

## サムネイルサイズの移行

| 既存 | 変更後 | 対象 |
|---|---|---|
| サムネイルを拡大 ⌘+ | ⌃⌘. | 表示メニュー、ファイルリストのキー一覧、プレビューのみ表示・zip の中・検索結果のキー一覧、ツールバーのサイズのスライダー、下部バーの説明 |
| サムネイルを縮小 ⌘- | ⌃⌘, | 同上 |

- プレビューのみ表示では、画像を表示していれば ⌘+ / ⌘- がプレビューの倍率を変え、⌃⌘. / ⌃⌘, が隠れたファイルリストのサムネイルサイズを変える（US14-AS14、EC-89）。
- プレビューに画像がないときの ⌘+ / ⌘- は何もしない。サムネイルサイズは変えない。
- キーボードだけで両方を操作できる状態を保つ（FR-040、憲章 原則 III）。
- `navigation-history.md` の FR-107（3）・US8-AS7 の ⌘+ / ⌘- は ⌃⌘. / ⌃⌘, に読み替える。

対応: FR-014・FR-135、US14-AS9・AS14、A-63・A-69。

## 有効条件（FR-136）

| 状態 | 3操作 | 拡大 | 縮小 |
|---|---|---|---|
| 3ペイン表示・プレビューのみ表示・フルスクリーンで画像を表示 | 有効 | 800%未満で有効 | 25%超で有効 |
| スライドショー実行中で画像を表示 | 有効 | 同上 | 同上 |
| 動画 | 無効 | 無効 | 無効 |
| 空のプレビュー（画像なし） | 無効 | 無効 | 無効 |
| 表示できない画像 | 無効 | 無効 | 無効 |
| ファイルリストのみ表示 | 無効 | 無効 | 無効 |
| シート・モーダル・名前の変更中・設定ウインドウがキー | 画像を表示していれば有効 | 同上 | 同上 |

有効条件は上表だけ。編集状態・シートの有無・設定ウインドウをキーかどうかで追加の制限を設けない（A-73）。

## 倍率のリセット

| 出来事 | 結果 |
|---|---|
| 起動、画像のない状態から最初の画像 | 100% |
| 別の画像への切り替え（選択変更・矢印・スライドショー） | 100% |
| 履歴の戻る・進む（同じ画像に戻る場合を含む） | 100% |
| フルスクリーンの切替 | 現在の倍率を保つ |
| ウィンドウ・ペイン・ツールバーの表示切替 | 現在の倍率を保つ |
| 同じ画像を表示したままのペイン表示の復帰 | 現在の倍率を保つ |
| 隠れている間に選択が変わった場合の復帰 | 新しい画像は100% |
| サイズ変更 | 新しいビューポートのフィットを100%として現在の倍率を適用 |
| 倍率変更の操作 | 履歴を記録しない。件数・表示の状態を変えない |

対応: FR-137、US14-AS5・AS8・AS10・AS15、EC-81・EC-86・EC-87・EC-88・EC-90、SC-047。

## アクセシビリティ

| 要素 | 契約 |
|---|---|
| プレビューの画像要素 | 画像表示中は値に `"25%"`〜`"800%"`。画像がない状態では値なし |
| 倍率変更の読み上げ | 明示的な操作で値が変わったとき、新しい百分率を `announcementRequested` で通知する。可視の数値表示は追加しない |
| 無効状態 | 3操作を無効として読み上げる（ツールバーは項目／セグメント、メニューは項目） |
| 画像切替・履歴による100%への復帰 | 値は更新するが、操作による変更ではないため読み上げの通知はしない |

対応: FR-138、US14-AS13、SC-050、A-64・A-71。

## 変更しないもの

- スクロール・パン・ドラッグ・トラックパッドのピンチ操作。
- 可視の倍率表示・スライダー・プリセット。
- 画像ごとの倍率の記憶、起動時の復元、履歴への保存。
- 動画の表示サイズ。
- スライドショーの切り替え効果「ズーム」とその時間・向き。
- サムネイルサイズの変更幅（16ポイント）と保存キー。
