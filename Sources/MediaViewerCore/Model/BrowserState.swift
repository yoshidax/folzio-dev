import Foundation

public struct FolderListing: Sendable {
    public enum State: Sendable, Equatable {
        case loading
        case loaded
        case empty
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
