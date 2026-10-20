import Foundation

public enum FocusMove: Sendable {
    case left
    case right
    case up
    case down
}

public enum FocusLayout: Sendable {
    case list
    case grid(columns: Int)
}

public struct FocusNavigator {
    public static func targetIndex(
        currentIndex: Int?,
        fileCount: Int,
        move: FocusMove,
        layout: FocusLayout
    ) -> Int? {
        guard fileCount > 0 else { return nil }

        let delta: Int
        switch layout {
        case .list:
            switch move {
            case .up:
                delta = -1
            case .down:
                delta = 1
            case .left, .right:
                return nil
            }
        case let .grid(columns):
            let columns = max(1, columns)
            switch move {
            case .left:
                delta = -1
            case .right:
                delta = 1
            case .up:
                delta = -columns
            case .down:
                delta = columns
            }
        }

        guard let currentIndex else { return 0 }

        let target = min(fileCount - 1, max(0, currentIndex + delta))
        return target == currentIndex ? nil : target
    }
}
