import Foundation

public struct ViewSettings: Sendable, Equatable {
    public static let defaultThumbnailSize: Double = 128
    public static let minimumThumbnailSize: Double = 48
    public static let maximumThumbnailSize: Double = 512

    public var displayMode: DisplayMode
    public var sortOrder: SortOrder
    public var lastFolder: URL?
    public var showsToolbar: Bool
    private var storedThumbnailSize: Double

    public var thumbnailSize: Double {
        get { storedThumbnailSize }
        set { storedThumbnailSize = Self.clampThumbnailSize(newValue) }
    }

    public init(
        displayMode: DisplayMode = .list,
        thumbnailSize: Double = defaultThumbnailSize,
        sortOrder: SortOrder = SortOrder(),
        lastFolder: URL? = nil,
        showsToolbar: Bool = false
    ) {
        self.displayMode = displayMode
        self.storedThumbnailSize = Self.clampThumbnailSize(thumbnailSize)
        self.sortOrder = sortOrder
        self.lastFolder = lastFolder
        self.showsToolbar = showsToolbar
    }

    public static func clampThumbnailSize(_ value: Double) -> Double {
        guard value.isFinite else { return defaultThumbnailSize }
        return min(max(value, minimumThumbnailSize), maximumThumbnailSize)
    }
}

public enum DisplayMode: String, Sendable, CaseIterable {
    case list
    case thumbnails
}

public enum SortColumn: String, Sendable, CaseIterable {
    case name
    case creationDate
    case kind
    /// 検索結果の表示中だけ使う（FR-084）。保存しない
    case location
}

public struct SortOrder: Sendable, Equatable {
    public var column: SortColumn
    public var ascending: Bool

    public init(column: SortColumn = .name, ascending: Bool = true) {
        self.column = column
        self.ascending = ascending
    }
}

public struct PlaybackOptions: Sendable, Equatable {
    public var autoplay: Bool
    public var loop: Bool

    public init(autoplay: Bool = true, loop: Bool = true) {
        self.autoplay = autoplay
        self.loop = loop
    }
}

public struct ConfirmationOptions: Sendable, Equatable {
    public var confirmBeforeFileOperations: Bool

    public init(confirmBeforeFileOperations: Bool = true) {
        self.confirmBeforeFileOperations = confirmBeforeFileOperations
    }
}
