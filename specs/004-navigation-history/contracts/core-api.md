# Contract: MediaViewerCore の公開 API（追加・変更）

既存の API は `specs/001-three-pane-media-viewer/contracts/core-api.md`・`specs/002-favorite-folder-rename/contracts/core-api.md`・
`specs/003-tree-folder-rename-delete/contracts/core-api.md` を参照。ここでは追加・変更するものだけを書く。
意味と不変条件は [data-model.md](../data-model.md)、判断の根拠は [research.md](../research.md) の R68〜R77。

## 履歴の値型（新規、Sources/MediaViewerCore/History/HistoryEntry.swift）

```swift
public struct HistoryLocation: Sendable, Equatable {
    public var folder: URL
    public var archive: ArchiveLocation?

    public init(folder: URL, archive: ArchiveLocation? = nil)

    /// パスを正規化して比べる（R69）
    public static func == (lhs: HistoryLocation, rhs: HistoryLocation) -> Bool
    /// url 自身か配下を指すか（zip の中は zip ファイルで判断する）
    public func isWithin(_ url: URL) -> Bool
    /// 名前を変えたフォルダに関係すれば新しい場所、なければ nil
    public func rebased(by renamed: RenamedFolder) -> HistoryLocation?
}

public struct HistoryPresentation: Sendable, Equatable {
    public var displayMode: DisplayMode
    public var thumbnailSize: Double
    public var paneLayout: PaneLayout
    public init(displayMode: DisplayMode, thumbnailSize: Double, paneLayout: PaneLayout)
}

public struct HistoryViewState: Sendable, Equatable {
    public var presentation: HistoryPresentation
    public var mediaTypeFilter: MediaTypeFilter
    public var showsZipFiles: Bool
    public init(presentation: HistoryPresentation, mediaTypeFilter: MediaTypeFilter, showsZipFiles: Bool)
}

public struct HistoryEntry: Sendable, Equatable {
    public var location: HistoryLocation
    public var viewState: HistoryViewState
    public var focusedItem: URL?
    public func hasSameState(as other: HistoryEntry) -> Bool
}

public enum HistoryRecordKind: Sendable, Equatable { case navigation, viewChange, thumbnailSize }
public enum HistoryDirection: Sendable, Equatable { case back, forward }
```

## NavigationHistory（新規、Sources/MediaViewerCore/History/NavigationHistory.swift）

```swift
public struct NavigationHistory: Sendable {
    public static let capacity = 100

    public private(set) var backEntries: [HistoryEntry]     // 古い順
    public private(set) var current: HistoryEntry?
    public private(set) var forwardEntries: [HistoryEntry]  // 近い順
    public private(set) var version: Int
    public var count: Int { get }
    public var canGoBack: Bool { get }
    public var canGoForward: Bool { get }

    public init()

    @discardableResult
    public mutating func record(location: HistoryLocation, viewState: HistoryViewState,
                                kind: HistoryRecordKind, leavingFocus: URL?) -> Bool
    public func candidate(_ direction: HistoryDirection) -> HistoryEntry?
    public mutating func dropCandidate(_ direction: HistoryDirection)
    @discardableResult
    public mutating func move(_ direction: HistoryDirection, leavingFocus: URL?) -> HistoryEntry?
    public mutating func updateCurrentViewState(_ viewState: HistoryViewState)
    public mutating func replaceCurrentLocation(_ location: HistoryLocation)
    public mutating func detachCurrent()
    public mutating func removeCurrent()
    public mutating func removeEntries(within urls: [URL], keepingCurrent: Bool)
    /// 位置は戻る側・現在・進む側を1列に並べた番号（`allEntries` の添字）
    public mutating func removeEntries(at positions: Set<Int>)
    public mutating func renameFolder(_ renamed: RenamedFolder)
    /// 戻る側・現在・進む側を1列に並べたもの（存在の確認に使う）
    public var allEntries: [HistoryEntry] { get }
}
```

## HistoryNavigator（新規、Sources/MediaViewerCore/History/HistoryNavigator.swift）

```swift
/// App が持つ表示の状態（表示形式・サムネイルサイズ・ペインの表示状態）の読み書き（R74）
@MainActor
public protocol HistoryPresentationHost: AnyObject {
    var historyPresentation: HistoryPresentation { get }
    /// 記録せずに表示の状態を戻す。保存の対象（表示形式・サイズ）は保存する（FR-108）
    func applyHistoryPresentation(_ presentation: HistoryPresentation)
}

@MainActor
@Observable
public final class HistoryNavigator {
    public private(set) var history: NavigationHistory
    public var canGoBack: Bool { get }      // 検索結果の表示中は true（FR-113）
    public var canGoForward: Bool { get }   // 検索結果の表示中は false
    public weak var presentationHost: (any HistoryPresentationHost)?

    /// model.onLocationEvent を自身に設定する
    public init(model: BrowserModel)

    public func goBack()
    public func goForward()
    /// 要求のキューが空になるまで待つ（テスト用）
    public func waitUntilIdle() async

    public func recordViewChange(_ kind: HistoryRecordKind)

    public func didRenameFolder(from oldURL: URL, to newURL: URL)
    public func didRenameItem(from oldURL: URL, to newURL: URL)
    public func didRemoveItems(_ urls: [URL])
    public func handleFileSystemEvent(_ folders: Set<URL>) async
    public func revalidateAll() async
}
```

## BrowserModel（変更、Sources/MediaViewerCore/Browser/BrowserModel.swift）

```swift
public enum LocationEvent: Sendable, Equatable {
    case navigated(leavingFocus: URL?)
    case relocated(vanished: [URL])
    case notFound(HistoryLocation)
}

public struct ResolvedHistoryLocation: Sendable {
    public let location: HistoryLocation
    // 非公開: 確認を始めたときの移動の世代、zip の索引または開けなかった理由
}

public enum HistoryLocationResolution: Sendable {
    case available(ResolvedHistoryLocation)
    case missing
    case superseded
}

extension BrowserModel {
    /// 場所を変えたときの同期の通知（R70）。HistoryNavigator が設定する。Observation の対象外
    public var onLocationEvent: ((LocationEvent) -> Void)? { get set }

    /// 今の表示の場所。検索結果の表示中と「見つからない」表示では nil
    public var historyLocation: HistoryLocation? { get }

    /// 表示を変えずに場所を確かめる。stat と zip の索引の作成は UI スレッドの外（R73）
    public func resolveHistoryLocation(_ location: HistoryLocation) async -> HistoryLocationResolution

    /// 確かめた場所を表示する。読み込みの完了を待たずに戻り、読み込みの後に focusing の行だけを選択する。
    /// treeSyncRequest を出し、lastFolder を保存する。onLocationEvent は呼ばない。世代が古ければ何もしない（R74）
    public func showHistoryLocation(_ resolved: ResolvedHistoryLocation, focusing: URL?)
}
```

既存の `selectFolder(_:)`・`openItem(_:)`・`goToEnclosingLevel()`・`leaveTrashedFolders(_:)`・`handleFileSystemEvent(_:)` は
シグネチャを変えず、data-model.md の表のとおり `onLocationEvent` を呼ぶようにする（内部の `navigateToFolder`・`returnToFolder`・
`selectFolder` に理由の引数を足す）。

## ArchiveIndex（変更、Sources/MediaViewerCore/Archive/ArchiveIndex.swift）

```swift
extension ArchiveIndex {
    /// 最上位（空文字）か、索引にあるディレクトリなら true（R73）
    public func containsDirectory(_ path: String) -> Bool
}
```

## PaneCommands（変更、Sources/MediaViewerCore/Model/PaneLayout.swift）

```swift
extension PaneCommands {
    /// ⌘[・⌘]・「移動」メニュー・ツールバーの戻る・進む（FR-112）
    public var canNavigateHistory: Bool { get }   // !isFullScreen && !isEditingText
}
```

## App 側の変更（参考。公開 API ではない）

| 型 | 変更 |
|---|---|
| `MainSplitViewController` | `HistoryNavigator` を作り、`presentationHost = self`。`HistoryPresentationHost` を実装（`setPaneLayout` を記録せずに呼ぶ経路と、`FileListViewController` の記録しない setter）。`@objc goBack(_:)`・`goForward(_:)` と `validateMenuItem`。`setPaneLayout` のユーザーの入口（メニュー・ツールバー）で `recordViewChange(.viewChange)` |
| `MainToolbarController` | `history` の項目を先頭に足す（`chevron.left`・`chevron.right`、`.momentary`）。`HistoryNavigator` の Observation と `validateToolbarItem` で各セグメントの有効・無効を更新 |
| `MainMenu` | 「移動」メニュー（「表示」の右）。「戻る」（`[`・⌘）・「進む」（`]`・⌘）、`target = nil` |
| `FileListViewController` | `onViewChange: ((HistoryRecordKind) -> Void)?` を足し、表示形式・サイズ（メニュー・下部のサイズバー・ツールバーからの `applyThumbnailSize`）・種類フィルタ・zip ファイルの表示のユーザーの入口で呼ぶ。記録しない `restore(displayMode:thumbnailSize:)` を足す |
| `DirectoryTreeViewController` | `eventTask` で `model.handleFileSystemEvent` の後に `history.handleFileSystemEvent`、`volumeTask` で `history.revalidateAll()` を呼ぶ |
| `FileOperationCoordinator` | 名前の変更（フォルダは `didRenameFolder`、ファイルは `didRenameItem`）・ゴミ箱と移動の成功した元の場所（`didRemoveItems`）を `HistoryNavigator` に知らせる |
