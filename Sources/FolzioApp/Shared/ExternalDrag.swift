import AppKit

/// Drags between this app and other apps (TAK-74). Drags that start and end in this app's views are handled by
/// `InternalDrag` and keep their own rules (FR-020).
@MainActor
enum ExternalDrag {
    /// Operations offered when an item from the tree, the list, or the thumbnails is dropped outside the app. The
    /// destination app (such as Finder) chooses between copy and move, so this app shows no confirmation (FR-344).
    /// `.generic` is included because the system narrows the mask to `.generic` while Command is held.
    /// `.delete` is left out: the Dock Trash leaves the deletion to the drag source, and this app does not delete
    /// items at the end of a drag, so dragging to the Dock Trash is not supported (FR-344).
    /// `.link` is left out because creating aliases is out of scope (A-206).
    static let sourceOperationMaskOutsideApp: NSDragOperation = [.copy, .move, .generic]
}
