import AppKit
import MediaViewerCore

@MainActor
enum IconCatalog {
    static func treeIcon(for kind: FolderNode.Kind) -> NSImage? {
        let name: String
        switch kind {
        case .home:
            name = "house"
        case .volume:
            name = "externaldrive"
        case .folder:
            name = "folder"
        }
        return symbol(named: name, pointSize: 13)
    }

    static func favoritesIcon() -> NSImage? {
        symbol(named: "star.fill", pointSize: 13)
    }

    static func fallbackIcon(for kind: MediaKind) -> NSImage? {
        let name: String
        switch kind {
        case .jpeg:
            name = "photo"
        case .png:
            name = "photo.on.rectangle"
        case .gif:
            name = "photo.stack"
        case .webp:
            name = "photo.circle"
        case .mp4:
            name = "film"
        case .mov:
            name = "video"
        }
        return symbol(named: name, pointSize: 16)
    }

    private static func symbol(named name: String, pointSize: CGFloat) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: .regular
        )
        guard let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration) else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}
