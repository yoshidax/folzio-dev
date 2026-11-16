import Foundation

/// Pane from which an operation was started. Used to decide whether the confirmation modal can be skipped
/// (FR-024, FR-079; research.md R58).
public enum OperationOrigin: Sendable, Equatable {
    case fileList
    case tree
}

public enum ConfirmationPolicy {
    /// The setting that decides whether the operation confirms (FR-023, FR-024). Returns nil for operations that
    /// always confirm regardless of the settings: moving folders in the tree to the Trash.
    public static func target(for kind: FileOperation.Kind, origin: OperationOrigin) -> ConfirmationTarget? {
        switch kind {
        case .copy:
            return .copy
        case .move:
            return .move
        case .rename:
            return .rename
        case .trash:
            // In the tree, a row that is not selected can be right-clicked and deleted, so keep confirmation to
            // prevent mistakes (A-33, A-233).
            return origin == .fileList ? .trash : nil
        }
    }

    /// Whether a confirmation that is turned on must still be shown as an app-modal alert when there is no window
    /// for a sheet (EC-263). Operations that always confirmed in earlier versions (move, rename, and Trash from the
    /// tree) are never run without confirmation. Copy and Trash from the file list keep their earlier behavior and
    /// continue without confirmation.
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
