import Foundation

/// 表示中の検索の条件と進み具合（FR-084・085、research.md R37）。`FolderListing.search` に置き、保存しない
public struct SearchListing: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case searching
        case finished
    }

    /// `SearchPattern.keyword`（検索バーに出す）
    public var keyword: String
    /// 確かめた検索起点ディレクトリ
    public var root: URL
    public var phase: Phase
    /// 見つかった件数（種類フィルタ適用前）。検索中は途中の件数
    public var totalCount: Int

    public init(keyword: String, root: URL, phase: Phase, totalCount: Int) {
        self.keyword = keyword
        self.root = root
        self.phase = phase
        self.totalCount = totalCount
    }

    /// 「場所」列とサムネイルのツールチップの文字列。起点のフォルダ名に、ファイルを含むフォルダまでの相対パスを `/` でつなぐ。
    /// 起点が `/` なら、ファイルを含むフォルダの絶対パス
    public func location(of fileURL: URL) -> String {
        let rootComponents = root.standardizedFileURL.pathComponents
        let folder = fileURL.deletingLastPathComponent().standardizedFileURL
        if rootComponents == ["/"] {
            return folder.path
        }

        let folderComponents = folder.pathComponents
        let relative: ArraySlice<String>
        if folderComponents.starts(with: rootComponents) {
            relative = folderComponents.dropFirst(rootComponents.count)
        } else {
            relative = []
        }
        return ([root.standardizedFileURL.lastPathComponent] + relative).joined(separator: "/")
    }
}
