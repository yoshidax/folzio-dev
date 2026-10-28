import Foundation

public struct MediaTypeFilter: Sendable, Equatable {
    public var imagesOnly: Bool
    public var videosOnly: Bool

    public init(imagesOnly: Bool = false, videosOnly: Bool = false) {
        self.imagesOnly = imagesOnly
        self.videosOnly = videosOnly
    }

    /// 片方だけがオンのときに絞り込む。両方オフ・両方オンは絞り込まない
    public var isFiltering: Bool {
        imagesOnly != videosOnly
    }

    public func includes(_ kind: MediaKind) -> Bool {
        guard isFiltering else { return true }
        return imagesOnly ? !kind.isVideo : kind.isVideo
    }

    public func apply(to files: [MediaFile]) -> [MediaFile] {
        guard isFiltering else { return files }
        // .media 以外の行（zip ファイル・ディレクトリ・...）は常に残す（FR-056）
        return files.filter { file in file.kind.mediaKind.map(includes) ?? true }
    }

    /// 絞り込み中に一覧が0件だったときの表示。文言は表示の層が選ぶ
    public var emptyState: EmptyState? {
        guard isFiltering else { return nil }
        return imagesOnly ? .imagesOnly : .videosOnly
    }

    public enum EmptyState: Sendable, Equatable {
        case imagesOnly
        case videosOnly
    }
}
