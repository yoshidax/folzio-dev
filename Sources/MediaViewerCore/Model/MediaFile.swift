import Foundation

public struct MediaFile: Identifiable, Hashable, Sendable {
    public var url: URL
    public var name: String
    public var kind: ListItemKind
    public var typeDescription: String
    public var creationDate: Date?
    public var fileSize: Int64

    public init(
        url: URL,
        name: String,
        kind: ListItemKind,
        typeDescription: String,
        creationDate: Date?,
        fileSize: Int64
    ) {
        self.url = url
        self.name = name
        self.kind = kind
        self.typeDescription = typeDescription
        self.creationDate = creationDate
        self.fileSize = fileSize
    }

    public var id: URL { url }

    public static func == (lhs: MediaFile, rhs: MediaFile) -> Bool {
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
