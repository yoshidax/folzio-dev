import Foundation
import Testing
@testable import MediaViewerCore

@Suite("NavigationHistory")
struct NavigationHistoryTests {
    private func folder(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/n/\(name)", isDirectory: true)
    }

    private func location(_ name: String) -> HistoryLocation {
        HistoryLocation(folder: folder(name))
    }

    private func state(
        displayMode: DisplayMode = .list,
        thumbnailSize: Double = 128,
        paneLayout: PaneLayout = .all,
        filter: MediaTypeFilter = MediaTypeFilter(),
        showsZipFiles: Bool = false
    ) -> HistoryViewState {
        HistoryViewState(
            presentation: HistoryPresentation(
                displayMode: displayMode,
                thumbnailSize: thumbnailSize,
                paneLayout: paneLayout
            ),
            mediaTypeFilter: filter,
            showsZipFiles: showsZipFiles
        )
    }

    private func entry(
        _ name: String,
        displayMode: DisplayMode = .list,
        thumbnailSize: Double = 128,
        filter: MediaTypeFilter = MediaTypeFilter(),
        showsZipFiles: Bool = false,
        focused: String? = nil
    ) -> HistoryEntry {
        HistoryEntry(
            location: location(name),
            viewState: state(
                displayMode: displayMode,
                thumbnailSize: thumbnailSize,
                filter: filter,
                showsZipFiles: showsZipFiles
            ),
            focusedItem: focused.map(folder)
        )
    }

    @discardableResult
    private func record(
        _ history: inout NavigationHistory,
        _ name: String,
        kind: HistoryRecordKind = .navigation,
        leavingFocus: String? = nil,
        displayMode: DisplayMode = .list,
        thumbnailSize: Double = 128
    ) -> Bool {
        history.record(
            location: location(name),
            viewState: state(displayMode: displayMode, thumbnailSize: thumbnailSize),
            kind: kind,
            leavingFocus: leavingFocus.map(folder)
        )
    }

    private func name(_ history: NavigationHistory) -> String? {
        history.current?.location.folder.lastPathComponent
    }

    @Test("初期状態は現在がなく、戻る・進むも使えない")
    func emptyHistory() {
        let history = NavigationHistory()
        #expect(history.current == nil)
        #expect(history.count == 0)
        #expect(history.canGoBack == false)
        #expect(history.canGoForward == false)
        #expect(history.backEntries.isEmpty)
        #expect(history.forwardEntries.isEmpty)
    }

    @Test("最初の記録は戻る側を作らず、戻る・進むは使えない（起動直後）")
    func firstRecord() {
        var history = NavigationHistory()
        #expect(record(&history, "A"))
        #expect(history.backEntries.isEmpty)
        #expect(name(history) == "A")
        #expect(history.canGoBack == false)
        #expect(history.canGoForward == false)
    }

    @Test("A → B → C の記録は古い順の戻る側と現在を作る。同じ状態は記録しない")
    func recordsInOrder() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "C")
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A", "B"])
        #expect(name(history) == "C")
        #expect(history.count == 3)

        let version = history.version
        let recorded = history.record(
            location: location("C"),
            viewState: state(),
            kind: .navigation,
            leavingFocus: folder("C/1.jpg")
        )
        #expect(recorded == false)
        #expect(history.version == version)
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A", "B"])
        #expect(history.forwardEntries.isEmpty)
    }

    @Test("記録の leavingFocus は戻る側へ移した直前の履歴に入り、新しい履歴は nil")
    func leavingFocusIsRecorded() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B", leavingFocus: "A/2.jpg")
        #expect(history.backEntries.first?.focusedItem == folder("A/2.jpg"))
        #expect(history.current?.focusedItem == nil)
    }

    @Test("候補は戻る側の末尾と進む側の先頭")
    func candidates() {
        var history = NavigationHistory()
        #expect(history.candidate(.back) == nil)
        #expect(history.candidate(.forward) == nil)

        record(&history, "A")
        record(&history, "B")
        record(&history, "C")
        #expect(history.candidate(.back)?.location == location("B"))
        #expect(history.candidate(.forward) == nil)

        history.move(.back, leavingFocus: nil)
        #expect(history.candidate(.back)?.location == location("A"))
        #expect(history.candidate(.forward)?.location == location("C"))
    }

    @Test("move は離れる履歴にフォーカスを記録し、反対側へ移す")
    func movesBothWays() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B", leavingFocus: "A/1.jpg")
        record(&history, "C", leavingFocus: "B/1.jpg")

        let moved = history.move(.back, leavingFocus: folder("C/1.jpg"))
        #expect(moved?.location == location("B"))
        #expect(name(history) == "B")
        #expect(history.forwardEntries.map(\.location.folder.lastPathComponent) == ["C"])
        #expect(history.forwardEntries.first?.focusedItem == folder("C/1.jpg"))
        #expect(history.candidate(.forward)?.focusedItem == folder("C/1.jpg"))

        _ = history.move(.back, leavingFocus: folder("B/2.jpg"))
        #expect(name(history) == "A")
        #expect(history.forwardEntries.map(\.location.folder.lastPathComponent) == ["B", "C"])
        #expect(history.forwardEntries.first?.focusedItem == folder("B/2.jpg"))

        #expect(history.move(.forward, leavingFocus: folder("A/3.jpg"))?.location == location("B"))
        #expect(history.backEntries.last?.focusedItem == folder("A/3.jpg"))
    }

    @Test("候補がない方向の move は何も変えない")
    func moveWithoutCandidateDoesNothing() {
        var history = NavigationHistory()
        record(&history, "A")
        let version = history.version
        #expect(history.move(.back, leavingFocus: nil) == nil)
        #expect(history.move(.forward, leavingFocus: nil) == nil)
        #expect(history.version == version)
    }

    @Test("戻った後に新しい履歴を記録すると進む側を取り除く（分岐）")
    func branchClearsForward() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "C")
        _ = history.move(.back, leavingFocus: nil)
        _ = history.move(.back, leavingFocus: nil)
        #expect(history.forwardEntries.count == 2)

        record(&history, "E")
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(name(history) == "E")
        #expect(history.forwardEntries.isEmpty)
    }

    @Test("150 件を記録すると 100 件になり、99 回戻れる（FR-110・SC-031）")
    func capacityKeepsNewestHundred() {
        var history = NavigationHistory()
        for index in 0..<150 {
            record(&history, "F\(index)")
        }
        #expect(history.count == 100)
        #expect(history.backEntries.first?.location.folder.lastPathComponent == "F50")
        #expect(name(history) == "F149")

        var backCount = 0
        while history.move(.back, leavingFocus: nil) != nil {
            backCount += 1
        }
        #expect(backCount == 99)
        #expect(name(history) == "F50")
    }

    @Test("進む側がある状態で記録しても 100 件を超えない")
    func capacityWithForward() {
        var history = NavigationHistory()
        for index in 0..<100 {
            record(&history, "F\(index)")
        }
        for _ in 0..<50 {
            _ = history.move(.back, leavingFocus: nil)
        }
        record(&history, "New")
        #expect(history.count <= NavigationHistory.capacity)
        #expect(history.forwardEntries.isEmpty)
        #expect(name(history) == "New")
    }

    @Test("version は変更のたびに増え、変わらない操作では増えない")
    func versionChanges() {
        var history = NavigationHistory()
        let emptyVersion = history.version
        record(&history, "A")
        #expect(history.version > emptyVersion)
        let version = history.version
        record(&history, "A")
        #expect(history.version == version)
        history.dropCandidate(.back)
        #expect(history.version == version)
        history.removeEntries(within: [], keepingCurrent: true)
        #expect(history.version == version)
    }

    @Test("allEntries は戻る側・現在・進む側の順")
    func allEntriesOrder() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "C")
        _ = history.move(.back, leavingFocus: nil)
        #expect(history.allEntries.map(\.location.folder.lastPathComponent) == ["A", "B", "C"])
    }

    @Test("dropCandidate は見つからない候補を取り除き、隣り合う同じ履歴をまとめる")
    func dropCandidateConsolidates() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "A")
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A", "B"])

        history.dropCandidate(.back)
        #expect(history.backEntries.isEmpty)
        #expect(name(history) == "A")

        for _ in 0..<3 {
            history.dropCandidate(.back)
        }
        #expect(history.backEntries.isEmpty)
        #expect(name(history) == "A")
    }

    @Test("現在を含まない同じ状態の組は新しい方を残す")
    func consolidationKeepsNewerOutsideCurrent() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "A")
        record(&history, "C")
        history.removeEntries(within: [folder("B")], keepingCurrent: true)
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(name(history) == "C")
    }

    @Test("removeEntries は配下と zip の中を取り除き、兄弟の前方一致は残す")
    func removeEntriesWithin() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "B/x")
        history.record(
            location: HistoryLocation(
                folder: folder("B"),
                archive: ArchiveLocation(archive: URL(fileURLWithPath: "/tmp/n/B/t.zip"), directory: "d/")
            ),
            viewState: state(),
            kind: .navigation,
            leavingFocus: nil
        )
        record(&history, "B2")
        record(&history, "C")

        history.removeEntries(within: [folder("B")], keepingCurrent: true)
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A", "B2"])
        #expect(name(history) == "C")
    }

    @Test("keepingCurrent が false なら現在も取り除く")
    func removeEntriesRemovesCurrent() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")

        history.removeEntries(within: [folder("B")], keepingCurrent: false)
        #expect(history.current == nil)
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])

        var keeping = NavigationHistory()
        record(&keeping, "A")
        record(&keeping, "B")
        keeping.removeEntries(within: [folder("B")], keepingCurrent: true)
        #expect(name(keeping) == "B")
    }

    @Test("removeEntries(at:) は allEntries の位置で取り除き、範囲外は無視する")
    func removeEntriesAtPositions() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "C")

        history.removeEntries(at: [1])
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(name(history) == "C")

        history.removeEntries(at: [99])
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(name(history) == "C")

        history.removeEntries(at: [1])
        #expect(name(history) == nil)
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
    }

    @Test("renameFolder は現在を新しい場所に置き換え、ほかの履歴は取り除く")
    func renameFolderReplacesCurrent() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")

        history.renameFolder(RenamedFolder(from: folder("B"), to: folder("B2")))
        #expect(history.current?.location == location("B2"))
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
    }

    @Test("renameFolder は戻る側・進む側の元の場所を取り除き、現在の配下は付け替える")
    func renameFolderRemovesOthers() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "C")
        history.renameFolder(RenamedFolder(from: folder("B"), to: folder("B2")))
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(name(history) == "C")

        var below = NavigationHistory()
        record(&below, "B")
        record(&below, "B/x")
        below.renameFolder(RenamedFolder(from: folder("B"), to: folder("B2")))
        #expect(below.current?.location == location("B2/x"))
        #expect(below.backEntries.isEmpty)

        var forward = NavigationHistory()
        record(&forward, "A")
        record(&forward, "B")
        record(&forward, "C")
        _ = forward.move(.back, leavingFocus: nil)
        _ = forward.move(.back, leavingFocus: nil)
        forward.renameFolder(RenamedFolder(from: folder("B"), to: folder("B2")))
        #expect(forward.forwardEntries.map(\.location.folder.lastPathComponent) == ["C"])
        #expect(name(forward) == "A")
    }

    @Test("関係のない名前の変更は version も変えない")
    func unrelatedRenameDoesNothing() {
        var history = NavigationHistory()
        record(&history, "A")
        let version = history.version
        history.renameFolder(RenamedFolder(from: folder("B"), to: folder("B2")))
        #expect(history.version == version)
        #expect(history.current?.location == location("A"))
    }

    @Test("replaceCurrentLocation は場所だけを変え、進む側を残し、隣とまとめる")
    func replaceCurrentLocation() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "C")
        _ = history.move(.back, leavingFocus: nil)
        #expect(history.forwardEntries.count == 1)

        history.replaceCurrentLocation(location("A"))
        #expect(history.current?.location == location("A"))
        #expect(history.backEntries.isEmpty)
        #expect(history.forwardEntries.map(\.location.folder.lastPathComponent) == ["C"])
    }

    @Test("detachCurrent は現在を戻る側へ移し、removeCurrent は取り除く")
    func detachAndRemoveCurrent() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        history.detachCurrent()
        #expect(history.current == nil)
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A", "B"])
        #expect(history.forwardEntries.isEmpty)

        var removed = NavigationHistory()
        record(&removed, "A")
        record(&removed, "B")
        removed.removeCurrent()
        #expect(removed.current == nil)
        #expect(removed.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
    }

    @Test("現在がない状態でも候補へ移れ、記録すると現在になって進む側を消す")
    func movesAndRecordsWithoutCurrent() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "B")
        record(&history, "C")
        _ = history.move(.back, leavingFocus: nil)
        _ = history.move(.back, leavingFocus: nil)
        history.detachCurrent()
        #expect(history.current == nil)
        #expect(history.candidate(.forward)?.location == location("B"))

        #expect(history.move(.forward, leavingFocus: nil)?.location == location("B"))
        #expect(name(history) == "B")
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(history.forwardEntries.map(\.location.folder.lastPathComponent) == ["C"])

        history.detachCurrent()
        record(&history, "E")
        #expect(name(history) == "E")
        #expect(history.forwardEntries.isEmpty)
    }

    @Test("updateCurrentViewState は現在だけを書き換え、1つ前と同じならまとめる")
    func updateCurrentViewState() {
        var history = NavigationHistory()
        record(&history, "A")
        history.record(
            location: location("A"),
            viewState: state(displayMode: .thumbnails),
            kind: .navigation,
            leavingFocus: nil
        )
        #expect(history.backEntries.count == 1)
        #expect(history.current?.viewState.presentation.displayMode == .thumbnails)

        history.updateCurrentViewState(state(displayMode: .list))
        #expect(history.backEntries.isEmpty)
        #expect(history.count == 1)
        #expect(history.current?.viewState.presentation.displayMode == .list)
    }

    @Test("サムネイルサイズの連続した変更は1件にまとめる（US8-AS2）")
    func thumbnailSizeChangesMerge() {
        var history = NavigationHistory()
        record(&history, "A")
        for size in [144.0, 160, 176, 192, 208] {
            record(&history, "A", kind: .thumbnailSize, thumbnailSize: size)
        }
        #expect(history.count == 2)
        #expect(history.backEntries.first?.viewState.presentation.thumbnailSize == 128)
        #expect(history.current?.viewState.presentation.thumbnailSize == 208)
        _ = history.move(.back, leavingFocus: nil)
        #expect(history.current?.viewState.presentation.thumbnailSize == 128)
    }

    @Test("サムネイルサイズの間にほかの記録を挟むと別の履歴になる")
    func thumbnailSizeMergeStops() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "A", kind: .thumbnailSize, thumbnailSize: 160)
        history.record(
            location: location("A"),
            viewState: state(displayMode: .thumbnails, thumbnailSize: 160),
            kind: .viewChange,
            leavingFocus: nil
        )
        record(&history, "A", kind: .thumbnailSize, displayMode: .thumbnails, thumbnailSize: 192)
        #expect(history.count == 4)
        #expect(history.current?.viewState.presentation.thumbnailSize == 192)
    }

    @Test("戻る・進むの直後のサイズ変更は新しい履歴になり、進む側を消す（US8-AS7）")
    func thumbnailSizeAfterMoveIsNew() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "A", kind: .thumbnailSize, thumbnailSize: 160)
        _ = history.move(.back, leavingFocus: nil)
        #expect(history.current?.viewState.presentation.thumbnailSize == 128)
        #expect(history.canGoForward)

        record(&history, "A", kind: .thumbnailSize, thumbnailSize: 176)
        #expect(history.canGoForward == false)
        #expect(history.backEntries.count == 1)
        #expect(history.current?.viewState.presentation.thumbnailSize == 176)
    }

    @Test("元の大きさに戻したサイズ変更は1つにまとまり、その後の変更は新しい履歴になる")
    func thumbnailSizeReturningToOriginalMerges() {
        var history = NavigationHistory()
        record(&history, "A")
        record(&history, "A", kind: .thumbnailSize, thumbnailSize: 160)
        record(&history, "A", kind: .thumbnailSize, thumbnailSize: 128)
        #expect(history.count == 1)
        #expect(history.current?.viewState.presentation.thumbnailSize == 128)

        record(&history, "A", kind: .thumbnailSize, thumbnailSize: 176)
        #expect(history.count == 2)
        #expect(history.backEntries.first?.viewState.presentation.thumbnailSize == 128)
        #expect(history.current?.viewState.presentation.thumbnailSize == 176)
    }

    @Test("現在を取り除いた後のサイズ変更は新しい履歴になる")
    func thumbnailSizeWithoutCurrent() {
        var history = NavigationHistory()
        record(&history, "A")
        history.removeCurrent()
        record(&history, "A", kind: .thumbnailSize, thumbnailSize: 160)
        #expect(history.count == 1)
        #expect(history.backEntries.isEmpty)
        #expect(history.current?.viewState.presentation.thumbnailSize == 160)
    }

    @Test("説明の状態の遷移を順に再現する")
    func documentedTransitions() {
        var history = NavigationHistory()
        #expect(history.current == nil)

        record(&history, "A")
        #expect(history.allEntries.map(\.location.folder.lastPathComponent) == ["A"])

        record(&history, "B")
        record(&history, "C")
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A", "B"])
        #expect(name(history) == "C")

        _ = history.move(.back, leavingFocus: nil)
        _ = history.move(.back, leavingFocus: nil)
        #expect(history.backEntries.isEmpty)
        #expect(name(history) == "A")
        #expect(history.forwardEntries.map(\.location.folder.lastPathComponent) == ["B", "C"])

        record(&history, "E")
        #expect(history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(name(history) == "E")
        #expect(history.forwardEntries.isEmpty)
    }
}
