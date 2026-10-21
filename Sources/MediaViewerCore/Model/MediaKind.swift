public enum MediaKind: String, CaseIterable, Sendable {
    case jpeg
    case png
    case gif
    case webp
    case mp4
    case mov

    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg":
            self = .jpeg
        case "png":
            self = .png
        case "gif":
            self = .gif
        case "webp":
            self = .webp
        case "mp4":
            self = .mp4
        case "mov":
            self = .mov
        default:
            return nil
        }
    }

    public var isVideo: Bool {
        switch self {
        case .mp4, .mov:
            return true
        case .jpeg, .png, .gif, .webp:
            return false
        }
    }
}

/// ファイルリストの行の種類（FR-068〜070・076・077、data-model.md の ListItemKind）。`MediaFile.kind` の型
public enum ListItemKind: Sendable, Hashable {
    /// 対応メディアファイル
    case media(MediaKind)
    /// 通常のフォルダの zip ファイル
    case archive
    /// 通常のフォルダのサブフォルダ（ファイル操作の対象）
    case folder
    /// zip の中のディレクトリ（読み取り専用）
    case directory
    /// 先頭行 `..`（zip の中と、ツリーのルート以外の通常のフォルダ）
    case parent

    public var isMedia: Bool {
        if case .media = self { return true }
        return false
    }

    public var mediaKind: MediaKind? {
        if case .media(let kind) = self { return kind }
        return nil
    }

    /// `.media` の動画のときだけ true
    public var isVideo: Bool {
        mediaKind?.isVideo ?? false
    }

    /// ダブルクリック・⌘↓ で開ける行（`.archive` / `.folder` / `.directory` / `.parent`）
    public var opensAsContainer: Bool {
        switch self {
        case .media:
            return false
        case .archive, .folder, .directory, .parent:
            return true
        }
    }

    /// 並べ替えの第2キーに使う文字列
    var sortKey: String {
        switch self {
        case .media(let kind): return kind.rawValue
        case .archive: return "archive"
        case .folder: return "folder"
        case .directory: return "directory"
        case .parent: return "parent"
        }
    }
}
