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

    // MARK: - Location and sortedMerge (FR-084, 085)

    @Test("場所は親フォルダのパスの自然順で、同じ場所では名前の自然順")
    func sortsByLocation() {
        let files = ["/r/b/x.jpg", "/r/a/z.jpg", "/r/a/y.jpg", "/r/a10/w.jpg", "/r/a2/v.jpg"].map(located)
        let ascending = sorted(files, by: SortOrder(column: .location, ascending: true))
        #expect(ascending.map(\.url.path) == ["/r/a/y.jpg", "/r/a/z.jpg", "/r/a2/v.jpg", "/r/a10/w.jpg", "/r/b/x.jpg"])

        let descending = sorted(files, by: SortOrder(column: .location, ascending: false))
        #expect(descending.map(\.url.path) == ["/r/b/x.jpg", "/r/a10/w.jpg", "/r/a2/v.jpg", "/r/a/y.jpg", "/r/a/z.jpg"])
    }

    @Test("sortedMerge は sorted(a + b) と同じ配列になり、同順位は a の行が先")
    func sortedMergeMatchesSorted() {
        var generator = SeededGenerator(seed: 0x5EA2C4)
        let dates: [Date?] = [nil, Date(timeIntervalSince1970: 100), Date(timeIntervalSince1970: 200), Date(timeIntervalSince1970: 300)]
        let names = ["a.jpg", "b.png", "c 2.jpg", "img10.mp4", "img2.jpg", "Cat.mov", "z.webp"]
        let folders = ["/r/a", "/r/a2", "/r/a10", "/r/b"]
        let types = ["JPEG イメージ", "PNG イメージ", "ムービー"]
        var serial = 0
        func randomFiles() -> [MediaFile] {
            let count = Int.random(in: 0...50, using: &generator)
            return (0..<count).map { _ in
                serial += 1
                let name = names.randomElement(using: &generator)!
                let folder = folders.randomElement(using: &generator)!
                return MediaFile(
                    // Also create rows with the same name and location (ties), distinguished by a fileSize sequence
                    // number.
                    url: URL(fileURLWithPath: "\(folder)/\(name)"),
                    name: name,
                    kind: .media(MediaKind(fileExtension: (name as NSString).pathExtension) ?? .jpeg),
                    typeDescription: types.randomElement(using: &generator)!,
                    creationDate: dates.randomElement(using: &generator)!,
                    fileSize: Int64(serial)
                )
            }
        }

        for column in [SortColumn.name, .creationDate, .kind, .location] {
            for ascending in [true, false] {
                let order = SortOrder(column: column, ascending: ascending)
                for _ in 0..<100 {
                    let a = sorted(randomFiles(), by: order)
                    let b = sorted(randomFiles(), by: order)
                    let merged = sortedMerge(a, b, by: order)
                    let expected = sorted(a + b, by: order)
                    #expect(merged.map(\.fileSize) == expected.map(\.fileSize), "column=\(column) ascending=\(ascending)")
                }
            }
        }
    }

    @Test("sortedMerge は片方が空でも一致する")
    func sortedMergeWithEmptySide() {
        let order = SortOrder(column: .name, ascending: true)
        let files = sorted([file("b.jpg"), file("a.jpg")], by: order)
        #expect(sortedMerge(files, [], by: order).map(\.name) == ["a.jpg", "b.jpg"])
        #expect(sortedMerge([], files, by: order).map(\.name) == ["a.jpg", "b.jpg"])
        #expect(sortedMerge([], [], by: order).isEmpty)
    }

    private func located(_ path: String) -> MediaFile {
        let url = URL(fileURLWithPath: path)
        return MediaFile(
            url: url,
            name: url.lastPathComponent,
            kind: .media(.jpeg),
            typeDescription: "JPEG イメージ",
            creationDate: nil,
            fileSize: 0
        )
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

/// Fixed-seed random number generator (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
