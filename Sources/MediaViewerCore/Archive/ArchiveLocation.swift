import Foundation

/// 表示中の zip とその中の階層（FR-069・070、data-model.md の ArchiveLocation）
public struct ArchiveLocation: Sendable, Hashable {
    /// zip ファイルのファイル URL
    public var archive: URL
    /// zip の中の階層のパス。最上位は空文字、それ以外は `a/b/` のように末尾が `/`
    public var directory: String

    public init(archive: URL, directory: String) {
        self.archive = archive
        self.directory = directory
    }

    /// 1つ上の階層。最上位では nil（zip を含むフォルダへ戻る）
    public var parent: ArchiveLocation? {
        guard !directory.isEmpty else { return nil }
        let trimmed = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
        guard let slash = trimmed.lastIndex(of: "/") else {
            return ArchiveLocation(archive: archive, directory: "")
        }
        return ArchiveLocation(archive: archive, directory: String(trimmed[...slash]))
    }
}
