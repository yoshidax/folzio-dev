import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SelectionIndex")
struct SelectionIndexTests {
    private func directory(_ index: Int) -> URL {
        URL(fileURLWithPath: "/selection/\(index)", isDirectory: true)
    }

    @Test("空の選択と空の一覧は空の IndexSet を返す")
    func emptyInputs() {
        #expect(SelectionIndex.indexes(of: [], in: []) == IndexSet())
        #expect(SelectionIndex.indexes(of: [directory(0)], in: []) == IndexSet())
        #expect(SelectionIndex.indexes(of: [], in: [directory(0)]) == IndexSet())
    }

    @Test("選択 URL の行番号を返し、一覧にない URL は無視する")
    func mapsSelectedURLs() {
        let urls = (0..<6).map(directory)
        let selected: Set<URL> = [urls[0], urls[2], urls[5], directory(99)]
        #expect(SelectionIndex.indexes(of: selected, in: urls) == IndexSet([0, 2, 5]))
    }

    @Test("一覧に同じ URL が重複する場合は最初の行を選ぶ")
    func duplicateURLsUseFirstRow() {
        let first = directory(0)
        let second = directory(1)
        let urls = [first, second, first, second]
        #expect(SelectionIndex.indexes(of: [first, second], in: urls) == IndexSet([0, 1]))
    }
}
