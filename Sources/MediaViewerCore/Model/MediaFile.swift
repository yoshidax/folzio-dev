import Foundation

public struct MediaFile: Identifiable, Hashable, Sendable {
    public enum KindNameSource: Sendable {
        case folder
        case zipArchive
    }
    public var url: URL
    public var name: String
    public var kind: ListItemKind
    public var typeDescription: String
    public var creationDate: Date?
    public var fileSize: Int64
    /// nil は OS または形式から得た、アプリが翻訳しない種類名。
    public var kindNameSource: KindNameSource?

    public init(
        url: URL,
        name: String,
        kind: ListItemKind,
        typeDescription: String,
        creationDate: Date?,
        fileSize: Int64,
        kindNameSource: KindNameSource? = nil
    ) {
        self.url = url
        self.name = name
        self.kind = kind
        self.typeDescription = typeDescription
        self.creationDate = creationDate
        self.fileSize = fileSize
        self.kindNameSource = kindNameSource
    }

    public var id: URL { url }

    public func localizedKindName(using names: KindNames) -> MediaFile {
        var result = self
        switch kindNameSource {
        case .folder: result.typeDescription = names.folder
        case .zipArchive: result.typeDescription = names.zipArchive
        case nil: break
        }
        return result
    }

    public static func == (lhs: MediaFile, rhs: MediaFile) -> Bool {
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

/// アプリが管理する種類名。並べ替え（種類の列）に表示中の名前を使うため、Core へ注入する（EC-112）
public struct KindNames: Sendable, Equatable {
    public var folder: String
    public var zipArchive: String

    public init(folder: String, zipArchive: String) {
        self.folder = folder
        self.zipArchive = zipArchive
    }
}
