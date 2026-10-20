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
        return files.filter { file in file.kind.mediaKind.map(includes) ?? false }
    }

    public var noMatchesMessage: String? {
        guard isFiltering else { return nil }
        return imagesOnly
            ? "画像のみ表示中: 該当するファイルはありません"
            : "動画のみ表示中: 該当するファイルはありません"
    }
}
