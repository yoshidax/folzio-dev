import Foundation
import Testing
@testable import MediaViewerCore

@Suite("Sorting")
struct SortingTests {
    @Test("名前は自然順で比較する")
    func sortsNamesNaturally() {
        let files = [file("img10.jpg"), file("img2.jpg"), file("img1.jpg")]
        let result = sorted(files, by: SortOrder(column: .name, ascending: true))
        #expect(result.map(\.name) == ["img1.jpg", "img2.jpg", "img10.jpg"])

        let descending = sorted(files, by: SortOrder(column: .name, ascending: false))
        #expect(descending.map(\.name) == ["img10.jpg", "img2.jpg", "img1.jpg"])
    }

    @Test("作成日の nil は昇順でも降順でも最後に置く")
    func placesMissingCreationDateLast() {
        let old = Date(timeIntervalSince1970: 100)
        let new = Date(timeIntervalSince1970: 200)
        let files = [file("none.jpg", created: nil), file("old.jpg", created: old), file("new.jpg", created: new)]

        let ascending = sorted(files, by: SortOrder(column: .creationDate, ascending: true))
        #expect(ascending.map(\.name) == ["old.jpg", "new.jpg", "none.jpg"])

        let descending = sorted(files, by: SortOrder(column: .creationDate, ascending: false))
        #expect(descending.map(\.name) == ["new.jpg", "old.jpg", "none.jpg"])
    }

    @Test("同じ値のときは名前の自然順を第2キーにする")
    func breaksTiesByName() {
        let sameDate = Date(timeIntervalSince1970: 100)
        let files = [file("b.jpg", created: sameDate), file("a10.jpg", created: sameDate), file("a2.jpg", created: sameDate)]
        let result = sorted(files, by: SortOrder(column: .creationDate, ascending: true))
        #expect(result.map(\.name) == ["a2.jpg", "a10.jpg", "b.jpg"])
    }

    @Test("種類は表示名で並べる")
    func sortsByKindDescription() {
        let files = [
            file("c.mp4", typeDescription: "MPEG-4 ムービー"),
            file("b.jpg", typeDescription: "JPEG イメージ"),
            file("a.png", typeDescription: "PNG イメージ"),
        ]
        let result = sorted(files, by: SortOrder(column: .kind, ascending: true))
        #expect(result.map(\.name) == ["b.jpg", "c.mp4", "a.png"])
    }

    @Test(".. の行は並べ替えの列と向きに関わらず先頭に置く")
    func keepsParentRowFirst() {
        let created = Date(timeIntervalSince1970: 100)
        let files = [
            item("c.png", .media(.png), created: created),
            item("..", .parent, created: nil),
            item("a.jpg", .media(.jpeg), created: created),
            item("b", .directory, created: created),
        ]
        for column in [SortColumn.name, .creationDate, .kind] {
            for ascending in [true, false] {
                let result = sorted(files, by: SortOrder(column: column, ascending: ascending))
                #expect(result.first?.name == "..", "column=\(column) ascending=\(ascending)")
                #expect(result.count == files.count)
            }
        }
    }

    @Test("ディレクトリとメディアは区別なく名前の自然順に混ざる")
    func mixesDirectoriesAndMediaByName() {
        let files = [
            item("c.png", .media(.png)),
            item("..", .parent),
            item("b", .directory),
            item("a.jpg", .media(.jpeg)),
        ]
        let ascending = sorted(files, by: SortOrder(column: .name, ascending: true))
        #expect(ascending.map(\.name) == ["..", "a.jpg", "b", "c.png"])

        let descending = sorted(files, by: SortOrder(column: .name, ascending: false))
        #expect(descending.map(\.name) == ["..", "c.png", "b", "a.jpg"])
    }

    @Test("フォルダもファイルと区別なく並び、.. は常に先頭に置く")
    func mixesFoldersWithFiles() {
        let created = Date(timeIntervalSince1970: 100)
        let files = [
            item("c.png", .media(.png), created: created),
            item("d.zip", .archive, created: created),
            item("..", .parent, created: nil),
            item("b", .folder, created: created),
            item("a.jpg", .media(.jpeg), created: created),
        ]
        let ascending = sorted(files, by: SortOrder(column: .name, ascending: true))
        #expect(ascending.map(\.name) == ["..", "a.jpg", "b", "c.png", "d.zip"])
        let descending = sorted(files, by: SortOrder(column: .name, ascending: false))
        #expect(descending.map(\.name) == ["..", "d.zip", "c.png", "b", "a.jpg"])

        for column in [SortColumn.name, .creationDate, .kind] {
            for ascending in [true, false] {
                let result = sorted(files, by: SortOrder(column: column, ascending: ascending))
                #expect(result.first?.name == "..", "column=\(column) ascending=\(ascending)")
                #expect(result.count == files.count)
            }
        }
    }

    private func item(_ name: String, _ kind: ListItemKind, created: Date? = nil) -> MediaFile {
        MediaFile(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            kind: kind,
            typeDescription: "",
            creationDate: created,
            fileSize: 0
        )
    }

    private func file(
        _ name: String,
        created: Date? = nil,
        typeDescription: String = "JPEG イメージ"
    ) -> MediaFile {
        MediaFile(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            kind: .media(MediaKind(fileExtension: (name as NSString).pathExtension) ?? .jpeg),
            typeDescription: typeDescription,
            creationDate: created,
            fileSize: 0
        )
    }
}
