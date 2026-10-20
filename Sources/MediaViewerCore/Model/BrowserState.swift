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

    public init(folder: URL, files: [MediaFile] = [], state: State = .empty) {
        self.folder = folder
        self.files = files
        self.state = state
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
    case video(URL)
    case unavailable(name: String, reason: String)
}

public enum FocusDirection: Sendable {
    case previous
    case next
}
