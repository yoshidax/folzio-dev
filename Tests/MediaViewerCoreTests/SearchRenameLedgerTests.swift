import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SearchRenameLedger")
struct SearchRenameLedgerTests {
    private func url(_ path: String, isDirectory: Bool = false) -> URL {
        URL(fileURLWithPath: path, isDirectory: isDirectory)
    }

    private func folder(_ path: String) -> MediaFile {
        DirectoryLister.folderRow(at: url(path, isDirectory: true), creationDate: nil)
    }

    private func media(_ path: String) -> MediaFile {
        let url = url(path)
        return MediaFile(
            url: url,
            name: url.lastPathComponent,
            kind: .media(.jpeg),
            typeDescription: "JPEG イメージ",
            creationDate: nil,
            fileSize: 0
        )
    }

    private func renamed(_ from: String, _ to: String) -> RenamedFolder {
        RenamedFolder(from: url(from, isDirectory: true), to: url(to, isDirectory: true))
    }

    @Test("初期状態は空で、addStream は 0, 1, … を返す")
    func streamsAreNumbered() {
        var ledger = SearchRenameLedger()
        #expect(ledger.isEmpty)
        #expect(ledger.addStream(visits: SearchVisitLog()) == 0)
        #expect(ledger.addStream(visits: SearchVisitLog()) == 1)
        #expect(ledger.isEmpty)
    }

    @Test("place はその列挙を始めた後の名前の変更だけを順に当てる")
    func placeAppliesOnlyLaterRenames() {
        var ledger = SearchRenameLedger()
        ledger.recordRename(renamed("/r/q", "/r/qq"), visited: true)
        let index = ledger.addStream(visits: SearchVisitLog())
        ledger.recordRename(renamed("/r/a", "/r/b"), visited: true)
        ledger.recordRename(renamed("/r/b", "/r/c"), visited: true)

        #expect(ledger.place(media("/r/a/one.jpg"), fromStream: index)?.url.path == "/r/c/one.jpg")
        #expect(ledger.place(media("/r/z/one.jpg"), fromStream: index)?.url.path == "/r/z/one.jpg")
        // 列挙の開始前の名前の変更は当てない
        #expect(ledger.place(media("/r/q/one.jpg"), fromStream: index)?.url.path == "/r/q/one.jpg")
    }

    @Test("フォルダの行は URL の最後の要素が変わったときだけ name も変える")
    func folderNameFollowsLastComponent() {
        var ledger = SearchRenameLedger()
        let index = ledger.addStream(visits: SearchVisitLog())
        ledger.recordRename(renamed("/r/F", "/r/zzz"), visited: true)

        let row = ledger.place(folder("/r/F"), fromStream: index)
        #expect(row?.url.path == "/r/zzz")
        #expect(row?.name == "zzz")
        #expect(row?.kind == .folder)

        let child = ledger.place(media("/r/F/g.jpg"), fromStream: index)
        #expect(child?.url.path == "/r/zzz/g.jpg")
        #expect(child?.name == "g.jpg")

        // 祖先だけが変わったフォルダの行の name はそのまま
        let descendantFolder = ledger.place(folder("/r/F/sub"), fromStream: index)
        #expect(descendantFolder?.url.path == "/r/zzz/sub")
        #expect(descendantFolder?.name == "sub")
    }

    @Test("hasVisited は各列挙の開始後の名前の変更を逆順に戻した場所で記録を問う")
    func hasVisitedReversesRenames() {
        let log = SearchVisitLog()
        var ledger = SearchRenameLedger()
        let index = ledger.addStream(visits: log)
        log.record("/r/F")
        ledger.recordRename(renamed("/r/F", "/r/F1"), visited: true)
        ledger.recordRename(renamed("/r/F1", "/r/F2"), visited: true)

        #expect(ledger.hasVisited(url("/r/F")))
        #expect(ledger.hasVisited(url("/r/F1")))
        #expect(ledger.hasVisited(url("/r/F2")))
        #expect(!ledger.hasVisited(url("/r/other")))
        #expect(index == 0)

        // 複数の列挙のどれかに記録があれば true
        var second = SearchVisitLog()
        second.record("/r/G")
        _ = ledger.addStream(visits: second)
        #expect(ledger.hasVisited(url("/r/G")))
        #expect(ledger.hasVisited(url("/r/F2")))
    }

    @Test("未照合として扱った名前の変更は、元の場所の行を捨て、中の結果は付け替える")
    func rejudgedRenamesDropTheFolderRow() {
        var ledger = SearchRenameLedger()
        let index = ledger.addStream(visits: SearchVisitLog())
        ledger.recordRename(renamed("/r/F", "/r/F2"), visited: false)

        #expect(ledger.place(folder("/r/F"), fromStream: index) == nil)
        #expect(ledger.place(media("/r/F/g.jpg"), fromStream: index)?.url.path == "/r/F2/g.jpg")

        // 照合済みなら行も新しい場所に付け替えて残す
        var visited = SearchRenameLedger()
        let visitedIndex = visited.addStream(visits: SearchVisitLog())
        visited.recordRename(renamed("/r/F", "/r/F2"), visited: true)
        let row = visited.place(folder("/r/F"), fromStream: visitedIndex)
        #expect(row?.url.path == "/r/F2")
        #expect(row?.name == "F2")
    }

    @Test("名前の変更の後に始めた列挙の結果はそのまま残す")
    func laterStreamsAreUnaffected() {
        var ledger = SearchRenameLedger()
        ledger.recordRename(renamed("/r/F", "/r/F2"), visited: false)
        let index = ledger.addStream(visits: SearchVisitLog())

        #expect(ledger.place(folder("/r/F2"), fromStream: index)?.url.path == "/r/F2")
        #expect(ledger.place(media("/r/F2/g.jpg"), fromStream: index)?.url.path == "/r/F2/g.jpg")
    }
}
