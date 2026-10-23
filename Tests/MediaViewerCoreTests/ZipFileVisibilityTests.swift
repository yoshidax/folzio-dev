import Foundation
import Testing
@testable import MediaViewerCore

@Suite("ZipFileVisibility")
struct ZipFileVisibilityTests {
    @Test("既定値は非表示")
    func defaultsAreHidden() {
        #expect(ZipFileVisibility().showsZipFiles == false)
        #expect(ZipFileVisibility(showsZipFiles: true).showsZipFiles == true)
    }

    @Test("false は zip ファイルの行だけを除き、残りの並び順を保つ")
    func hiddenRemovesOnlyArchiveRows() {
        let files = [
            item("b.zip", .archive),
            item("a.jpg", .media(.jpeg)),
            item("sub", .folder),
            item("inner", .directory),
            item("..", .parent),
        ]

        let result = ZipFileVisibility(showsZipFiles: false).apply(to: files)

        #expect(result.map(\.name) == ["a.jpg", "sub", "inner", ".."])
        #expect(result.map(\.url) == files.filter { $0.kind != .archive }.map(\.url))
    }

    @Test("false で zip ファイルだけの入力は空になる")
    func hiddenWithOnlyArchivesIsEmpty() {
        let files = [item("a.zip", .archive), item("b.zip", .archive)]
        #expect(ZipFileVisibility(showsZipFiles: false).apply(to: files).isEmpty)
    }

    @Test("false で zip ファイルを含まない入力は同じ並びのまま")
    func hiddenWithoutArchivesKeepsInput() {
        let files = [item("c.png", .media(.png)), item("a.jpg", .media(.jpeg)), item("sub", .folder)]
        let result = ZipFileVisibility(showsZipFiles: false).apply(to: files)
        #expect(result.map(\.url) == files.map(\.url))
    }

    @Test("空配列は空配列のまま")
    func emptyStaysEmpty() {
        #expect(ZipFileVisibility(showsZipFiles: false).apply(to: []).isEmpty)
        #expect(ZipFileVisibility(showsZipFiles: true).apply(to: []).isEmpty)
    }

    @Test("true は入力と完全に一致し、元の配列を変えない")
    func shownReturnsInputUnchanged() {
        let files = [
            item("b.zip", .archive),
            item("a.jpg", .media(.jpeg)),
            item("..", .parent),
            item("c.zip", .archive),
        ]
        let original = files

        let result = ZipFileVisibility(showsZipFiles: true).apply(to: files)

        #expect(result.count == original.count)
        #expect(result.map(\.url) == original.map(\.url))
        #expect(result.map(\.name) == original.map(\.name))
        #expect(files.map(\.url) == original.map(\.url))

        _ = ZipFileVisibility(showsZipFiles: false).apply(to: files)
        #expect(files.map(\.url) == original.map(\.url))
    }

    @Test("種類フィルタの結果に通すと、画像の行だけが残り zip ファイルも消える")
    func composesWithMediaTypeFilter() {
        let files = [
            item("a.jpg", .media(.jpeg)),
            item("b.mov", .media(.mov)),
            item("c.zip", .archive),
            item("d.png", .media(.png)),
        ]

        let filtered = MediaTypeFilter(imagesOnly: true).apply(to: files)
        #expect(filtered.map(\.name) == ["a.jpg", "c.zip", "d.png"])

        let result = ZipFileVisibility(showsZipFiles: false).apply(to: filtered)
        #expect(result.map(\.name) == ["a.jpg", "d.png"])
    }

    // MARK: - Helpers

    private func item(_ name: String, _ kind: ListItemKind) -> MediaFile {
        MediaFile(
            url: URL(fileURLWithPath: "/tmp/zip-visibility", isDirectory: true).appendingPathComponent(name),
            name: name,
            kind: kind,
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }
}
