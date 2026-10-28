import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SearchVisitLog")
struct SearchVisitLogTests {
    @Test("記録したパスだけを含む")
    func recordsPaths() {
        let log = SearchVisitLog()
        #expect(!log.contains("/a"))
        log.record("/a")
        #expect(log.contains("/a"))
        #expect(!log.contains("/b"))
        #expect(!log.contains("/a/b"))
    }

    @Test("複数の Task から並行に記録しても、すべて残る")
    func concurrentRecords() async {
        let log = SearchVisitLog()
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 1_000 {
                group.addTask { log.record("/p/\(index)") }
            }
        }
        for index in 0 ..< 1_000 {
            #expect(log.contains("/p/\(index)"), "Record is missing: \(index)")
        }
    }
}
