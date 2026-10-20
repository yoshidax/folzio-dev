import Testing
@testable import MediaViewerCore

@Suite("FocusNavigator")
struct FocusNavigatorTests {
    @Test("リスト形式は上下で前後に移動する")
    func listMovesVertically() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 2,
            fileCount: 5,
            move: .up,
            layout: .list
        ) == 1)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 2,
            fileCount: 5,
            move: .down,
            layout: .list
        ) == 3)
    }

    @Test("リスト形式の左右は移動しない")
    func listIgnoresHorizontalMoves() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 2,
            fileCount: 5,
            move: .left,
            layout: .list
        ) == nil)
        #expect(FocusNavigator.targetIndex(
            currentIndex: nil,
            fileCount: 5,
            move: .right,
            layout: .list
        ) == nil)
    }

    @Test("リスト形式は端で停止する")
    func listStopsAtEnds() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 0,
            fileCount: 5,
            move: .up,
            layout: .list
        ) == nil)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 4,
            fileCount: 5,
            move: .down,
            layout: .list
        ) == nil)
    }

    @Test("サムネイル形式は左右で前後に移動する")
    func gridMovesHorizontally() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 4,
            fileCount: 10,
            move: .left,
            layout: .grid(columns: 4)
        ) == 3)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 4,
            fileCount: 10,
            move: .right,
            layout: .grid(columns: 4)
        ) == 5)
    }

    @Test("サムネイル形式は上下で行単位に移動する")
    func gridMovesByRow() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 6,
            fileCount: 10,
            move: .up,
            layout: .grid(columns: 4)
        ) == 2)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 2,
            fileCount: 10,
            move: .down,
            layout: .grid(columns: 4)
        ) == 6)
    }

    @Test("サムネイル形式は端で停止する")
    func gridStopsAtEnds() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 0,
            fileCount: 10,
            move: .left,
            layout: .grid(columns: 4)
        ) == nil)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 9,
            fileCount: 10,
            move: .right,
            layout: .grid(columns: 4)
        ) == nil)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 0,
            fileCount: 10,
            move: .up,
            layout: .grid(columns: 4)
        ) == nil)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 1,
            fileCount: 10,
            move: .up,
            layout: .grid(columns: 4)
        ) == 0)
    }

    @Test("最終行が短い場合は範囲内にクランプする")
    func gridClampsShortLastRow() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 8,
            fileCount: 9,
            move: .down,
            layout: .grid(columns: 4)
        ) == nil)
    }

    @Test("現在位置がない場合は先頭を選ぶ")
    func selectsFirstItemWhenNoFocus() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: nil,
            fileCount: 3,
            move: .down,
            layout: .grid(columns: 4)
        ) == 0)
    }

    @Test("空リストでは移動先がない")
    func emptyListReturnsNil() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: nil,
            fileCount: 0,
            move: .down,
            layout: .list
        ) == nil)
    }

    @Test("列数が0以下なら1列として扱う")
    func invalidColumnCountFallsBackToOne() {
        #expect(FocusNavigator.targetIndex(
            currentIndex: 1,
            fileCount: 5,
            move: .up,
            layout: .grid(columns: 0)
        ) == 0)
        #expect(FocusNavigator.targetIndex(
            currentIndex: 1,
            fileCount: 5,
            move: .down,
            layout: .grid(columns: -2)
        ) == 2)
    }
}
