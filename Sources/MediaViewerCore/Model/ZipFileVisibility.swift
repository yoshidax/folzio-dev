import Foundation

/// ファイルリストに zip ファイルの行を出すかどうかと、一覧への適用（FR-095・097、research.md R46）。
///
/// 適用は `BrowserModel.rebuildListing()` の1か所だけで、種類フィルタ（`MediaTypeFilter`）を通した結果に通す。
/// 保存しない値型で、永続化は `ViewSettings.showsZipFiles` が持つ。
public struct ZipFileVisibility: Sendable, Equatable {
    public var showsZipFiles: Bool

    public init(showsZipFiles: Bool = false) {
        self.showsZipFiles = showsZipFiles
    }

    /// `showsZipFiles` が true なら入力をそのまま返し、false なら `kind == .archive` の行だけを除く。
    /// 並び順を保ち、メディア・フォルダ・zip の中のディレクトリ・`..` は残す
    public func apply(to files: [MediaFile]) -> [MediaFile] {
        guard !showsZipFiles else { return files }
        return files.filter { $0.kind != .archive }
    }
}
