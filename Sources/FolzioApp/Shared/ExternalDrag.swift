import AppKit

/// Drags between this app and other apps (TAK-74). Drags that start and end in this app's views are handled by
/// `InternalDrag` and keep their own rules (FR-020).
@MainActor
enum ExternalDrag {
    /// Operations offered when an item from the tree, the list, or the thumbnails is dropped outside the app. The
    /// destination app (such as Finder) chooses between copy and move, so this app shows no confirmation (FR-344).
    /// `.generic` is included because the system narrows the mask to `.generic` while Command is held. `.delete` lets
    /// the Dock Trash accept the items; this app never deletes anything itself when a drag ends with `.delete`.
    /// `.link` is left out because creating aliases is out of scope (A-206).
    static let sourceOperationMaskOutsideApp: NSDragOperation = [.copy, .move, .generic, .delete]
}
