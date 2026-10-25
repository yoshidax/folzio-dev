import Foundation

/// 履歴の「場所」（FR-108）。ファイルリストに表示していたフォルダと、zip の中の位置の組（R69）
public struct HistoryLocation: Sendable, Equatable {
    public var folder: URL
    public var archive: ArchiveLocation?

    public init(folder: URL, archive: ArchiveLocation? = nil) {
        self.folder = folder
        self.archive = archive
    }

    public static func == (lhs: HistoryLocation, rhs: HistoryLocation) -> Bool {
        HistoryPath.normalized(lhs.folder.path) == HistoryPath.normalized(rhs.folder.path)
            && lhs.archive?.directory == rhs.archive?.directory
            && lhs.archive.map { HistoryPath.normalized($0.archive.path) }
                == rhs.archive.map { HistoryPath.normalized($0.archive.path) }
    }

    /// `url` 自身か配下を指すか。zip の中は zip ファイルの場所で判断する（R73）
    public func isWithin(_ url: URL) -> Bool {
        if let archive {
            return HistoryPath.isWithin(archive.archive.path, url.path)
        }
        return HistoryPath.isWithin(folder.path, url.path)
    }

    /// 名前を変えたフォルダに関係すれば新しい場所、なければ nil（R69・R75）
    public func rebased(by renamed: RenamedFolder) -> HistoryLocation? {
        let newFolder = renamed.rebase(folder)
        if let archive {
            guard let newArchive = renamed.rebase(archive.archive) else { return nil }
            return HistoryLocation(
                folder: newFolder ?? folder,
                archive: ArchiveLocation(archive: newArchive, directory: archive.directory)
            )
        }
        guard let newFolder else { return nil }
        return HistoryLocation(folder: newFolder)
    }
}

/// 履歴の「表示の状態」のうち App が持つ部分（R74）
public struct HistoryPresentation: Sendable, Equatable {
    public var displayMode: DisplayMode
    public var thumbnailSize: Double
    public var paneLayout: PaneLayout

    public init(displayMode: DisplayMode, thumbnailSize: Double, paneLayout: PaneLayout) {
        self.displayMode = displayMode
        self.thumbnailSize = thumbnailSize
        self.paneLayout = paneLayout
    }
}

/// 履歴の「表示の状態」（FR-108）。種類フィルタと zip ファイルの表示は `BrowserModel` が持つ
public struct HistoryViewState: Sendable, Equatable {
    public var presentation: HistoryPresentation
    public var mediaTypeFilter: MediaTypeFilter
    public var showsZipFiles: Bool

    public init(
        presentation: HistoryPresentation,
        mediaTypeFilter: MediaTypeFilter,
        showsZipFiles: Bool
    ) {
        self.presentation = presentation
        self.mediaTypeFilter = mediaTypeFilter
        self.showsZipFiles = showsZipFiles
    }
}

/// 1件の履歴。`focusedItem` はその履歴から離れたときにフォーカスしていた行（FR-108）
public struct HistoryEntry: Sendable, Equatable {
    public var location: HistoryLocation
    public var viewState: HistoryViewState
    public var focusedItem: URL?

    public init(location: HistoryLocation, viewState: HistoryViewState, focusedItem: URL? = nil) {
        self.location = location
        self.viewState = viewState
        self.focusedItem = focusedItem
    }

    /// 場所と表示の状態だけを比べる（FR-107 の「同じ状態」、EC-59）
    public func hasSameState(as other: HistoryEntry) -> Bool {
        location == other.location && viewState == other.viewState
    }
}

public enum HistoryRecordKind: Sendable, Equatable {
    case navigation
    case viewChange
    case thumbnailSize
}

public enum HistoryDirection: Sendable, Equatable {
    case back
    case forward
}

/// `.`・`..` を取り除いたパスで場所を比べる（R69）。`RenamedFolder` と同じ規則
private enum HistoryPath {
    static func normalized(_ path: String) -> String {
        var contiguous = path
        contiguous.makeContiguousUTF8()
        let hasDotComponent = contiguous.withUTF8 { bytes -> Bool in
            guard let base = bytes.baseAddress else { return false }
            return memmem(base, bytes.count, "/.", 2) != nil
        }
        guard hasDotComponent else { return contiguous }

        var parts: [Substring] = []
        for component in path.split(separator: "/") {
            switch component {
            case ".":
                continue
            case "..":
                if !parts.isEmpty { parts.removeLast() }
            default:
                parts.append(component)
            }
        }
        return "/" + parts.joined(separator: "/")
    }

    static func components(_ path: String) -> [Substring] {
        normalized(path).split(separator: "/", omittingEmptySubsequences: true)
    }

    static func isWithin(_ path: String, _ base: String) -> Bool {
        let pathComponents = components(path)
        let baseComponents = components(base)
        guard !baseComponents.isEmpty else { return true }
        guard pathComponents.count >= baseComponents.count else { return false }
        return pathComponents.prefix(baseComponents.count).elementsEqual(baseComponents)
    }
}
