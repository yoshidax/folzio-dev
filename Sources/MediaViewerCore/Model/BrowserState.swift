import Foundation

public struct FolderListing: Sendable {
    public enum State: Sendable, Equatable {
        case loading
        case loaded
        case empty
        case noMatches
        case denied
        case failed(String)
    }

    public var folder: URL
    public var files: [MediaFile]
    public var state: State
    /// zip の中を表示中なら、その zip と階層。通常のフォルダでは nil（`folder` は zip を含むフォルダのまま）
    public var archive: ArchiveLocation?
    /// 検索結果を表示中なら、その条件と進み具合。表示中は `folder` を検索前のフォルダのまま変えず、`archive` は nil（FR-084・085）
    public var search: SearchListing?

    public init(
        folder: URL,
        files: [MediaFile] = [],
        state: State = .empty,
        archive: ArchiveLocation? = nil,
        search: SearchListing? = nil
    ) {
        self.folder = folder
        self.files = files
        self.state = state
        self.archive = archive
        self.search = search
    }
}

/// ファイルリストの中での移動をツリーに伝える依頼（FR-078、research.md R31）。`BrowserModel.treeSyncRequest` で公開する
public struct TreeSyncRequest: Sendable, Equatable {
    /// ツリーで選択するフォルダ（ファイルリストに表示しているフォルダ）
    public let folder: URL
    /// 依頼のたびに増やす。ツリーは最新の `id` の結果だけを選択に反映する
    public let id: Int

    public init(folder: URL, id: Int) {
        self.folder = folder
        self.id = id
    }
}

public struct SelectionState: Sendable {
    public var selected: Set<URL>
    public var focused: URL?

    public init(selected: Set<URL> = [], focused: URL? = nil) {
        self.selected = selected
        self.focused = focused
    }
}

extension SelectionState {
    /// 表示中の URL（一覧の並び順）に合わせて選択を整理する
    public func restricted(toVisible orderedURLs: [URL]) -> SelectionState {
        let visible = Set(orderedURLs)
        let kept = selected.intersection(visible)

        let newFocused: URL?
        if let focused {
            if visible.contains(focused) {
                newFocused = focused
            } else {
                newFocused = orderedURLs.last { kept.contains($0) }
            }
        } else {
            newFocused = nil
        }
        return SelectionState(selected: kept, focused: newFocused)
    }
}

public enum PreviewContent {
    case empty
    case loading(URL)
    case image(DecodedImage)
    case animatedImage(URL)
    /// zip の中のアニメーション画像。`Data` は zip から読んだ項目の内容（プレビューを離れたら捨てる）
    case animatedImageData(URL, Data)
    case video(URL)
    case unavailable(name: String, reason: String)
}

public enum FocusDirection: Sendable {
    case previous
    case next
}
