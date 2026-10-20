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

    /// フルスクリーン用（FR-046）。移動先が `isNavigable(index) == false` なら、同じ方向に同じ規則で移動を繰り返す。
    /// 移動できる行に当たらないまま端に達したら nil。`currentIndex` が nil のときは、先頭から順に最初の移動できる行
    public static func targetIndex(
        currentIndex: Int?,
        fileCount: Int,
        move: FocusMove,
        layout: FocusLayout,
        isNavigable: (Int) -> Bool
    ) -> Int? {
        // 空リスト・リスト形式の左右は、既存の関数と同じく nil
        guard targetIndex(
            currentIndex: nil, fileCount: fileCount, move: move, layout: layout
        ) != nil else { return nil }

        guard var current = currentIndex else {
            return (0..<fileCount).first(where: isNavigable)
        }

        for _ in 0..<fileCount {
            guard let next = targetIndex(
                currentIndex: current, fileCount: fileCount, move: move, layout: layout
            ) else { return nil }
            if isNavigable(next) { return next }
            current = next
        }
        return nil
    }
}
