# Contract: MediaViewerCore の公開インターフェース

UI（`MediaViewerApp`）が依存する、Core ライブラリの境界。テストはこの境界に対して書く（原則 IV）。
シグネチャは設計上の意図を示すもので、引数名などの細部は実装時に調整してよい。ただし責務の分担は変えない。
エンティティの定義は [data-model.md](../data-model.md) を参照。

## 形式判定

```swift
public enum MediaKind: Sendable {
    public init?(fileExtension: String)   // 大文字小文字を区別しない。非対応形式なら nil
    public var isVideo: Bool { get }
}
```

## ディレクトリ・ボリューム

```swift
public protocol DirectoryListing: Sendable {
    /// 直下の対応メディアファイルのみを返す（隠しファイル・サブフォルダ・非対応形式は除く）
    func mediaFiles(in folder: URL) async throws(ListingError) -> [MediaFile]
    /// 直下のフォルダのみを返す（隠しフォルダ・パッケージは除く）。名前の自然順
    func subfolders(of folder: URL) async throws(ListingError) -> [URL]
}

public enum ListingError: Error { case accessDenied, notFound, other(String) }

public protocol VolumeProviding: Sendable {
    func rootNodes() -> [FolderNode]                    // ホームフォルダ + マウント中のボリューム
    var changes: AsyncStream<[FolderNode]> { get }      // マウント・取り外しのたびに最新のルートを流す
}

public protocol FileSystemWatching: Sendable {
    /// 監視対象を差し替える。直下の追加・削除・名前変更が起きたフォルダの URL を流す
    func watch(_ folders: Set<URL>)
    var events: AsyncStream<Set<URL>> { get }
}
```

## 並べ替え

```swift
public func sorted(_ files: [MediaFile], by order: SortOrder) -> [MediaFile]
```

## ブラウザ状態（UI から呼ぶ中心のモデル）

```swift
@MainActor public final class BrowserModel {
    public private(set) var listing: FolderListing
    public private(set) var selection: SelectionState
    public private(set) var preview: PreviewContent
    public var sortOrder: SortOrder

    public func selectFolder(_ url: URL) async        // 前の読み込みを取り消してから一覧を読み込む
    public func select(_ urls: Set<URL>, focused: URL?)
    public func moveFocus(_ direction: FocusDirection) // 前後の項目。プレビューと先読みを更新する
    public func handleFileSystemEvent(_ folders: Set<URL>) async
}
```

- UI は `BrowserModel` の変化を監視して描画するだけにし、選択・プレビュー・先読みの判断を UI に持たせない

## プレビュー用デコード

```swift
public protocol ImageDecoding: Sendable {
    /// 長辺 maxPixelSize 以下にダウンサンプリングしてデコードする。アニメーションなら先頭フレーム
    func decode(_ url: URL, maxPixelSize: Int) async throws(DecodeError) -> DecodedImage
    func isAnimated(_ url: URL) -> Bool
}

public enum DecodeError: Error { case unreadable, unsupported, corrupted }

public actor DecodedImageCache {
    public init(costLimitBytes: Int)                   // 既定は 256MB（research.md R8）
}

public struct FitCalculator {
    /// 縦横比を保ってコンテナに収まる最大の矩形を、コンテナ中央に返す。拡大率に上限はなく、
    /// コンテナより小さい画像は拡大される（FR-028）。画像はトリミングしない
    public static func fit(imageSize: CGSize, in container: CGSize) -> CGRect
}
```

- スケールは `min(container.width / imageSize.width, container.height / imageSize.height)`。
  1 を上限にしないため、小さい画像では 1 を超える
- 返す矩形は `imageSize × スケール` をコンテナ内で中央に置いたもの。はみ出しも切り取りも生じない
- 幅・高さのいずれかが 0 以下の入力では `.zero` を返す（ゼロ除算を避ける）
- 呼び出し側は画像とコンテナを同じ単位（ピクセルまたはポイント）で渡す。`ImagePreviewView` は
  バッキング倍率を掛けたピクセルで計算し、結果をポイントに戻して配置する

## サムネイル

```swift
public protocol ThumbnailProviding: Sendable {
    /// 要求サイズは 64 / 128 / 256 / 512 の段階に丸める。結果はメモリにのみキャッシュする
    func thumbnail(for url: URL, pointSize: Double, scale: Double) async -> CGImage?
    /// 指定した URL と要求サイズの進行中要求だけを取り消す。他のサイズの要求は取り消さない
    func cancel(for url: URL, pointSize: Double, scale: Double)
}

public struct ThumbnailGridLayout {
    /// 利用可能な幅とサムネイルサイズから、列数と実際のセル幅を返す。
    /// セル幅は利用可能な幅を超えない（横スクロールを出さない: FR-015）
    public static func columns(availableWidth: Double, thumbnailSize: Double, spacing: Double) -> (count: Int, cellWidth: Double)
}

public struct ThumbnailScroll {
    /// フォーカス項目全体が見える最小の縦スクロール原点を返す（FR-017）。
    /// 既に見えていれば現在の可視原点を返す。0...(contentHeight - visibleHeight) にクランプし、
    /// ビューポートより高い項目は上端を合わせる。横方向は扱わない
    public static func offsetY(
        itemMinY: Double,
        itemMaxY: Double,
        visibleMinY: Double,
        visibleHeight: Double,
        contentHeight: Double
    ) -> Double
}
```

- `ThumbnailModeView` はレイアウト済みの `layoutAttributesForItem(at:)` のフレームと
  `scrollView.contentView.bounds` をこの関数へ渡し、結果をクリップビューの原点に適用する。
  UI は選択や移動量を自前で判断しない
- 不正な寸法（非有限値、負の高さ、可視高 0 など）では現在の原点を返し、クラッシュしない
- リスト形式の行頭アイコン（FR-048）は `pointSize: 16` とバッキング倍率で要求し、32px は
  64px 段階に丸められる。UI は取得中・失敗時に形式別の SF Symbol を表示し、取得後に同じ URL の
  セルへだけ差し替える（`IconPresentation`、[data-model.md](../data-model.md)）。
  セル再利用時は `cancel(for:pointSize:scale:)` で同じ 64px 要求だけを取り消す。
  サムネイル形式が同じ URL を 128px 以上で要求していても、それを巻き込んで取り消してはならない。
  ツリーのフォルダ種別アイコンは `FolderNode.Kind` から SF Symbol を選ぶ UI 表現で、Core の API は増やさない

## 矢印キーによる選択移動

```swift
public enum FocusMove: Sendable {
    case left, right, up, down
}

public enum FocusLayout: Sendable {
    case list
    case grid(columns: Int)
}

public struct FocusNavigator {
    /// 現在位置・件数・移動方向・レイアウトから移動先インデックスを返す（FR-017・046）。
    /// リスト形式は ↑↓ を ±1、←→ は移動なし。グリッドは ←→ を ±1、↑↓ を ∓列数。
    /// 0...(fileCount - 1) にクランプし、空リスト・移動不能（端）では nil を返す。
    /// リスト形式の ←→ は常に nil。currentIndex が nil の場合は 0 を返す。
    public static func targetIndex(
        currentIndex: Int?,
        fileCount: Int,
        move: FocusMove,
        layout: FocusLayout
    ) -> Int?
}
```

- 通常表示のサムネイル形式（`ThumbnailModeView`）とフルスクリーン（`FileListViewController`）は
  同じ関数を使い、移動規則を二重実装しない
- 呼び出し側は返されたインデックスを `BrowserModel.select([url], focused: url)` に渡すだけで、
  インデックス計算を UI に持たない
- `columns` が 0 以下の場合は 1 として扱う

## ファイル操作

```swift
public protocol FileOperating: Sendable {
    func conflicts(for operation: FileOperation) -> [URL]       // 操作先に同名がある元ファイル
    func execute(_ operation: FileOperation, resolution: ConflictResolution) async -> FileOperationResult
}

public enum ConflictResolution: Sendable { case replace, keepBoth, abort }

public enum NameValidation { case ok, needsExtensionChangeConfirmation, invalid(reason: String) }
public func validateNewName(_ name: String, for file: URL, existingNames: Set<String>) -> NameValidation

/// 「両方残す」用の名前を返す: "a.jpg" → "a 2.jpg" → "a 3.jpg" …
public func uniqueName(for name: String, existingNames: Set<String>) -> String
```

## 設定

```swift
public struct SettingsStore {
    public init(defaults: UserDefaults)               // テストでは専用のスイート名を渡す
    public var viewSettings: ViewSettings { get nonmutating set }
    public var playback: PlaybackOptions { get nonmutating set }
    public var confirmation: ConfirmationOptions { get nonmutating set }
}
```
