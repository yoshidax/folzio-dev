import Foundation

public struct FolderNode: Identifiable, Hashable, Sendable {
    public enum Kind: Sendable {
        case home
        case volume
        case folder
    }

    public enum AccessState: Sendable {
        case unknown
        case accessible
        case denied
    }

    public var url: URL
    public var name: String
    public var kind: Kind
    public var children: [FolderNode]?
    public var accessState: AccessState

    public init(
        url: URL,
        name: String,
        kind: Kind,
        children: [FolderNode]? = nil,
        accessState: AccessState = .unknown
    ) {
        self.url = url
        self.name = name
        self.kind = kind
        self.children = children
        self.accessState = accessState
    }

    public var id: URL { url }

    public static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
