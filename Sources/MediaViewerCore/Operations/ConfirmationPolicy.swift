import Foundation

/// 操作をどのペインから行ったか。確認モーダルを省略できるかの判断に使う（FR-024・FR-079、research.md R58）
public enum OperationOrigin: Sendable, Equatable {
    case fileList
    case tree
}

public enum ConfirmationPolicy {
    /// 確認モーダルの省略設定（FR-023）がオンのときに、確認を省略してよいか。
    /// コピーはどちらの経路でも、ゴミ箱はファイルリストからだけ省略できる。名前の変更と移動は常に確認する
    public static func isSkippable(_ kind: FileOperation.Kind, origin: OperationOrigin) -> Bool {
        switch kind {
        case .copy:
            return true
        case .trash:
            // ツリーでは選択中でない行を右クリックして削除できるため、取り違えを防ぐ確認を省略しない（A-33）
            return origin == .fileList
        case .move, .rename:
            return false
        }
    }
}
