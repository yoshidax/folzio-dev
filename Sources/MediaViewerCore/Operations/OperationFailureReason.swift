import Foundation

/// ファイル操作が失敗した理由（表示言語に依存しない値）。文言は `MediaViewerLocalization` が決める。
/// OS が返す理由は `systemReason` にそのまま持ち、訳し直さない（EC-111）
public enum OperationFailureReason: Error, Sendable, Equatable {
    case noDestination
    case destinationNotFound
    case sourceNotFound
    case intoItself
    case invalidName(NameValidationFailure)
    case sameNameExists
    case sameNameAtDestination
    case trashExistingFailed(systemReason: String)
    /// コピー・移動・名前の変更そのものが OS に拒否されたときの理由
    case systemFailure(systemReason: String)
}
