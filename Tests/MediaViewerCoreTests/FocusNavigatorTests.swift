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

    // MARK: - isNavigable 付き（FR-046）

    private func target(
        _ kinds: [ListItemKind],
        from currentIndex: Int?,
        _ move: FocusMove,
        _ layout: FocusLayout
    ) -> Int? {
        FocusNavigator.targetIndex(
            currentIndex: currentIndex,
            fileCount: kinds.count,
            move: move,
            layout: layout,
            isNavigable: { kinds[$0].isMedia }
        )
    }

    @Test("リスト形式はメディア以外の行を読み飛ばして次のメディアに移動する")
    func navigableListSkipsNonMedia() {
        let kinds: [ListItemKind] = [.media(.jpeg), .directory, .directory, .media(.png)]
        #expect(target(kinds, from: 0, .down, .list) == 3)
        #expect(target(kinds, from: 3, .up, .list) == 0)
    }

    @Test("グリッドは上の行に移動できる行がなければ nil、左右は読み飛ばす")
    func navigableGrid() {
        let kinds: [ListItemKind] = [.parent, .directory, .media(.jpeg), .media(.png)]
        #expect(target(kinds, from: 2, .up, .grid(columns: 2)) == nil)
        #expect(target(kinds, from: 3, .left, .grid(columns: 2)) == 2)
        #expect(target(kinds, from: 2, .right, .grid(columns: 2)) == 3)
    }

    @Test("グリッドの上下は列数ずつ、メディアに当たるまで繰り返す")
    func navigableGridVerticalRepeats() {
        let kinds: [ListItemKind] = [
            .media(.jpeg), .directory,
            .directory, .directory,
            .media(.png), .media(.gif),
        ]
        #expect(target(kinds, from: 0, .down, .grid(columns: 2)) == 4)
        #expect(target(kinds, from: 4, .up, .grid(columns: 2)) == 0)
        // 1 から ↑ は既存の関数と同じく先頭へクランプされ、0 がメディアなので止まる
        #expect(target(kinds, from: 5, .up, .grid(columns: 2)) == 0)
    }

    @Test("移動先の方向にメディアがなければ nil")
    func navigableNoMediaInDirection() {
        let kinds: [ListItemKind] = [.media(.jpeg), .directory, .directory]
        #expect(target(kinds, from: 0, .down, .list) == nil)
        #expect(target(kinds, from: 2, .down, .list) == nil)
    }

    @Test("フォルダと .. の行も読み飛ばす")
    func navigableSkipsFolders() {
        let kinds: [ListItemKind] = [.parent, .folder, .media(.jpeg), .folder, .media(.png)]
        #expect(target(kinds, from: 2, .down, .list) == 4)
        #expect(target(kinds, from: 2, .up, .list) == nil)
    }

    @Test("全部がメディアでなければ nil")
    func navigableAllNonMedia() {
        let kinds: [ListItemKind] = [.parent, .directory, .archive]
        #expect(target(kinds, from: 0, .down, .list) == nil)
        #expect(target(kinds, from: nil, .down, .list) == nil)
        #expect(target(kinds, from: nil, .right, .grid(columns: 2)) == nil)
    }

    @Test("currentIndex が nil のときは先頭から順に最初のメディアの位置")
    func navigableNilCurrentIndex() {
        let kinds: [ListItemKind] = [.parent, .directory, .media(.jpeg), .media(.png)]
        #expect(target(kinds, from: nil, .down, .list) == 2)
        #expect(target(kinds, from: nil, .up, .list) == 2)
        #expect(target(kinds, from: nil, .right, .grid(columns: 2)) == 2)
        #expect(target(kinds, from: nil, .left, .grid(columns: 2)) == 2)
    }

    @Test("リスト形式の左右と空リストは nil のまま")
    func navigableKeepsBaseNilCases() {
        let kinds: [ListItemKind] = [.media(.jpeg), .media(.png)]
        #expect(target(kinds, from: 0, .right, .list) == nil)
        #expect(target(kinds, from: nil, .left, .list) == nil)
        #expect(target([], from: nil, .down, .list) == nil)
    }

    @Test("isNavigable が常に true なら既存の関数と同じ結果になる")
    func navigableAlwaysTrueMatchesBase() {
        let layouts: [FocusLayout] = [.list, .grid(columns: 1), .grid(columns: 3), .grid(columns: 0), .grid(columns: 10)]
        let moves: [FocusMove] = [.left, .right, .up, .down]
        for count in [0, 1, 2, 5, 10] {
            let currents: [Int?] = [nil] + (0..<count).map { Optional($0) }
            for layout in layouts {
                for move in moves {
                    for current in currents {
                        let expected = FocusNavigator.targetIndex(
                            currentIndex: current, fileCount: count, move: move, layout: layout
                        )
                        let actual = FocusNavigator.targetIndex(
                            currentIndex: current, fileCount: count, move: move, layout: layout,
                            isNavigable: { _ in true }
                        )
                        #expect(
                            actual == expected,
                            "count=\(count) current=\(String(describing: current)) move=\(move) layout=\(layout)"
                        )
                    }
                }
            }
        }
    }
}
