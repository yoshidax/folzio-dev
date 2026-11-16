import Foundation

/// Pane from which an operation was started. Used to decide whether the confirmation modal can be skipped
/// (FR-024, FR-079; research.md R58).
public enum OperationOrigin: Sendable, Equatable {
    case fileList
    case tree
}

public enum ConfirmationPolicy {
    /// The setting that decides whether the operation confirms (FR-023, FR-024). Every operation that confirms has
    /// one: moving folders in the tree to the Trash follows the same Trash setting as the file list, because a
    /// context click targets the clicked item in both panes and the Trash can undo it (FR-079, A-232, A-233).
    public static func target(for kind: FileOperation.Kind, origin: OperationOrigin) -> ConfirmationTarget {
        switch kind {
        case .copy:
            return .copy
        case .move:
            return .move
        case .rename:
            return .rename
        case .trash:
            return .trash
        }
    }

    /// Whether a confirmation that is turned on must still be shown as an app-modal alert when there is no window
    /// for a sheet (EC-263). Operations that always confirmed in earlier versions (move, rename, and Trash from the
    /// tree) are never run unconfirmed while their confirmation is on. Copy and Trash from the file list keep their
    /// earlier behavior and continue without confirmation.
    public static func requiresModalWithoutWindow(_ kind: FileOperation.Kind, origin: OperationOrigin) -> Bool {
        switch kind {
        case .copy:
            return false
        case .move, .rename:
            return true
        case .trash:
            return origin == .tree
        }
    }
}
