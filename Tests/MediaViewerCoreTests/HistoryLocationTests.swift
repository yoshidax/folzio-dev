import Foundation
import Testing
@testable import MediaViewerCore

@Suite("HistoryLocation")
struct HistoryLocationTests {
    private func folder(_ path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    private func file(_ path: String) -> URL {
        URL(fileURLWithPath: path)
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

    @Test("場所は末尾の /・.・.. を無視して比べ、別の場所とは違う")
    func equalityNormalizesPaths() {
        #expect(HistoryLocation(folder: folder("/tmp/h/A")) == HistoryLocation(folder: folder("/tmp/h/A/")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A")) == HistoryLocation(folder: folder("/tmp/h/./A")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A")) == HistoryLocation(folder: folder("/tmp/h/x/../A")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A")) != HistoryLocation(folder: folder("/tmp/h/B")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A")) != HistoryLocation(folder: folder("/tmp/h/A2")))
    }

    @Test("通常のフォルダと zip の中の場所は別物として比べる")
    func equalitySeparatesArchive() {
        let normal = HistoryLocation(folder: folder("/tmp/h/A"))
        let archive = HistoryLocation(
            folder: folder("/tmp/h/A"),
            archive: ArchiveLocation(archive: file("/tmp/h/A/t.zip"), directory: "d/")
        )
        #expect(normal != archive)
        #expect(archive == HistoryLocation(
            folder: folder("/tmp/h/A"),
            archive: ArchiveLocation(archive: file("/tmp/h/A/./t.zip"), directory: "d/")
        ))
        #expect(archive != HistoryLocation(
            folder: folder("/tmp/h/A"),
            archive: ArchiveLocation(archive: file("/tmp/h/A/t.zip"), directory: "e/")
        ))
    }

    @Test("存在しないパスでも比べられる")
    func equalityDoesNotNeedExistingPaths() {
        #expect(HistoryLocation(folder: folder("/tmp/n/missing")) == HistoryLocation(folder: folder("/tmp/n/missing/")))
        #expect(HistoryLocation(folder: folder("/tmp/n/missing")) != HistoryLocation(folder: folder("/tmp/n/other")))
    }

    @Test("isWithin は自身と配下だけを指し、兄弟の前方一致を取り違えない")
    func isWithinUsesPathComponents() {
        let photo = HistoryLocation(folder: folder("/tmp/h/Photo"))
        #expect(photo.isWithin(folder("/tmp/h/Photos")) == false)
        #expect(photo.isWithin(folder("/tmp/h/Photo")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A/B")).isWithin(folder("/tmp/h/A")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A/B")).isWithin(folder("/tmp/h/A/B")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A/B")).isWithin(folder("/tmp/h/A/B/C")) == false)
        #expect(HistoryLocation(folder: folder("/tmp/h/A")).isWithin(folder("/")) == true)
        #expect(HistoryLocation(folder: folder("/tmp/h/A")).isWithin(folder("/tmp/other")) == false)
    }

    @Test("zip の中の場所は zip ファイルで配下を判断する")
    func isWithinArchiveUsesArchiveFile() {
        let location = HistoryLocation(
            folder: folder("/tmp/h/A"),
            archive: ArchiveLocation(archive: file("/tmp/h/A/t.zip"), directory: "d/")
        )
        #expect(location.isWithin(file("/tmp/h/A/t.zip")))
        #expect(location.isWithin(folder("/tmp/h/A")))
        #expect(location.isWithin(file("/tmp/h/A/t.zip/child")) == false)
        #expect(location.isWithin(folder("/tmp/h/Other")) == false)
        #expect(location.isWithin(folder("/")) == true)
    }

    @Test("rebased はフォルダと zip の両方を付け替える")
    func rebasedFollowsRename() {
        let renamed = RenamedFolder(from: folder("/tmp/h/A"), to: folder("/tmp/h/A2"))
        #expect(HistoryLocation(folder: folder("/tmp/h/A")).rebased(by: renamed)
            == HistoryLocation(folder: folder("/tmp/h/A2")))
        #expect(HistoryLocation(folder: folder("/tmp/h/A/B")).rebased(by: renamed)
            == HistoryLocation(folder: folder("/tmp/h/A2/B")))
        #expect(HistoryLocation(
            folder: folder("/tmp/h/A"),
            archive: ArchiveLocation(archive: file("/tmp/h/A/t.zip"), directory: "d/")
        ).rebased(by: renamed) == HistoryLocation(
            folder: folder("/tmp/h/A2"),
            archive: ArchiveLocation(archive: file("/tmp/h/A2/t.zip"), directory: "d/")
        ))
        #expect(HistoryLocation(folder: folder("/tmp/h/Other")).rebased(by: renamed) == nil)
        #expect(HistoryLocation(folder: folder("/tmp/h/A3")).rebased(by: renamed) == nil)
    }

    @Test("hasSameState は場所と表示の状態だけを比べる")
    func hasSameStateIgnoresFocus() {
        let location = HistoryLocation(folder: folder("/tmp/h/A"))
        let base = HistoryEntry(location: location, viewState: state())
        let focused = HistoryEntry(location: location, viewState: state(), focusedItem: file("/tmp/h/A/1.jpg"))
        #expect(base.hasSameState(as: focused))

        let variations = [
            HistoryViewState(
                presentation: HistoryPresentation(displayMode: .thumbnails, thumbnailSize: 128, paneLayout: .all),
                mediaTypeFilter: MediaTypeFilter(),
                showsZipFiles: false
            ),
            HistoryViewState(
                presentation: HistoryPresentation(displayMode: .list, thumbnailSize: 256, paneLayout: .all),
                mediaTypeFilter: MediaTypeFilter(),
                showsZipFiles: false
            ),
            HistoryViewState(
                presentation: HistoryPresentation(displayMode: .list, thumbnailSize: 128, paneLayout: .previewOnly),
                mediaTypeFilter: MediaTypeFilter(),
                showsZipFiles: false
            ),
            HistoryViewState(
                presentation: HistoryPresentation(displayMode: .list, thumbnailSize: 128, paneLayout: .all),
                mediaTypeFilter: MediaTypeFilter(imagesOnly: true),
                showsZipFiles: false
            ),
            HistoryViewState(
                presentation: HistoryPresentation(displayMode: .list, thumbnailSize: 128, paneLayout: .all),
                mediaTypeFilter: MediaTypeFilter(),
                showsZipFiles: true
            ),
        ]
        for variation in variations {
            #expect(base.hasSameState(as: HistoryEntry(location: location, viewState: variation)) == false)
        }
    }
}
