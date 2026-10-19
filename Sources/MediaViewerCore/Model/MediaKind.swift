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
