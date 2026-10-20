import Foundation
import Testing
@testable import MediaViewerCore

@Suite("MediaTypeFilter")
struct MediaTypeFilterTests {
    private static let combinations: [(imagesOnly: Bool, videosOnly: Bool)] = [
        (false, false), (true, false), (false, true), (true, true),
    ]

    @Test("既定値は両方オフ")
    func defaultsAreOff() {
        let filter = MediaTypeFilter()
        #expect(filter.imagesOnly == false)
        #expect(filter.videosOnly == false)
    }

    @Test("includes は 4 通りの組み合わせで全 6 種に対して正しい")
    func includesForAllCombinations() {
        for combo in Self.combinations {
            let filter = MediaTypeFilter(imagesOnly: combo.imagesOnly, videosOnly: combo.videosOnly)
            for kind in MediaKind.allCases {
                let expected: Bool
                switch (combo.imagesOnly, combo.videosOnly) {
                case (true, false): expected = !kind.isVideo
                case (false, true): expected = kind.isVideo
                default: expected = true
                }
                #expect(
                    filter.includes(kind) == expected,
                    "imagesOnly=\(combo.imagesOnly) videosOnly=\(combo.videosOnly) kind=\(kind)"
                )
            }
        }
    }

    @Test("isFiltering は片方だけがオンのときだけ true")
    func isFilteringOnlyWhenExactlyOneIsOn() {
        #expect(MediaTypeFilter(imagesOnly: false, videosOnly: false).isFiltering == false)
        #expect(MediaTypeFilter(imagesOnly: true, videosOnly: false).isFiltering == true)
        #expect(MediaTypeFilter(imagesOnly: false, videosOnly: true).isFiltering == true)
        #expect(MediaTypeFilter(imagesOnly: true, videosOnly: true).isFiltering == false)
    }

    @Test("apply は並び順を保って絞り込む")
    func applyKeepsOrder() {
        let folder = URL(fileURLWithPath: "/tmp/filter", isDirectory: true)
        let files = ["b.mov", "a.jpg", "c.mp4", "d.png"].map { file($0, in: folder) }

        #expect(MediaTypeFilter(imagesOnly: true).apply(to: files).map(\.name) == ["a.jpg", "d.png"])
        #expect(MediaTypeFilter(videosOnly: true).apply(to: files).map(\.name) == ["b.mov", "c.mp4"])
        #expect(MediaTypeFilter().apply(to: files).map(\.name) == files.map(\.name))
        #expect(
            MediaTypeFilter(imagesOnly: true, videosOnly: true).apply(to: files).map(\.name)
                == files.map(\.name)
        )
    }

    @Test("apply は media 以外の行（zip・ディレクトリ・...）を常に残し、並び順も保つ")
    func applyKeepsNonMediaRows() {
        let folder = URL(fileURLWithPath: "/tmp/filter", isDirectory: true)
        let files = [
            item("...", .parent, in: folder),
            item("sub", .directory, in: folder),
            item("a.jpg", .media(.jpeg), in: folder),
            item("pack.zip", .archive, in: folder),
            item("b.mov", .media(.mov), in: folder),
            item("c.png", .media(.png), in: folder),
        ]

        #expect(
            MediaTypeFilter(imagesOnly: true).apply(to: files).map(\.name)
                == ["...", "sub", "a.jpg", "pack.zip", "c.png"]
        )
        #expect(
            MediaTypeFilter(videosOnly: true).apply(to: files).map(\.name)
                == ["...", "sub", "pack.zip", "b.mov"]
        )
        #expect(MediaTypeFilter().apply(to: files).map(\.name) == files.map(\.name))
    }

    @Test("media が 1 つもなくても、media 以外の行は絞り込み中でも残る")
    func applyKeepsOnlyNonMediaRows() {
        let folder = URL(fileURLWithPath: "/tmp/filter", isDirectory: true)
        let files = [item("...", .parent, in: folder), item("sub", .directory, in: folder)]
        #expect(MediaTypeFilter(imagesOnly: true).apply(to: files).map(\.name) == ["...", "sub"])
        #expect(MediaTypeFilter(videosOnly: true).apply(to: files).map(\.name) == ["...", "sub"])
    }

    @Test("apply は空配列に対して空配列を返す")
    func applyToEmpty() {
        for combo in Self.combinations {
            let filter = MediaTypeFilter(imagesOnly: combo.imagesOnly, videosOnly: combo.videosOnly)
            #expect(filter.apply(to: []).isEmpty)
        }
    }

    @Test("noMatchesMessage は絞り込み中だけ種類に応じた文言を返す")
    func noMatchesMessageText() {
        #expect(
            MediaTypeFilter(imagesOnly: true).noMatchesMessage
                == "画像のみ表示中: 該当するファイルはありません"
        )
        #expect(
            MediaTypeFilter(videosOnly: true).noMatchesMessage
                == "動画のみ表示中: 該当するファイルはありません"
        )
        #expect(MediaTypeFilter().noMatchesMessage == nil)
        #expect(MediaTypeFilter(imagesOnly: true, videosOnly: true).noMatchesMessage == nil)
    }

    // MARK: - SelectionState.restricted(toVisible:)

    @Test("フォーカスが表示中のままなら選択は表示中のものだけになりフォーカスは保たれる")
    func restrictedKeepsVisibleFocus() {
        let (a, b, v) = (url("a.jpg"), url("b.png"), url("v.mov"))
        let state = SelectionState(selected: [a, v], focused: a)
        let result = state.restricted(toVisible: [a, b])
        #expect(result.selected == [a])
        #expect(result.focused == a)
    }

    @Test("フォーカスが非表示になり選択が残るとき、表示順で最後の選択中のものがフォーカスになる")
    func restrictedMovesFocusToLastVisibleSelected() {
        let (a, b, c, v) = (url("a.jpg"), url("b.png"), url("c.gif"), url("v.mov"))
        let state = SelectionState(selected: [a, c, v], focused: v)

        let first = state.restricted(toVisible: [c, b, a])
        #expect(first.selected == [a, c])
        #expect(first.focused == a)

        let second = state.restricted(toVisible: [a, b, c])
        #expect(second.selected == [a, c])
        #expect(second.focused == c)
    }

    @Test("選択が残らないときは選択が空でフォーカスは nil")
    func restrictedClearsWhenNothingRemains() {
        let (a, b, v) = (url("a.jpg"), url("b.png"), url("v.mov"))
        let result = SelectionState(selected: [v], focused: v).restricted(toVisible: [a, b])
        #expect(result.selected.isEmpty)
        #expect(result.focused == nil)
    }

    @Test("フォーカスがないときは nil のまま")
    func restrictedKeepsNilFocus() {
        let a = url("a.jpg")
        let result = SelectionState(selected: [a], focused: nil).restricted(toVisible: [a])
        #expect(result.selected == [a])
        #expect(result.focused == nil)
    }

    @Test("表示が空なら選択は空でフォーカスは nil")
    func restrictedToEmptyVisible() {
        let (a, v) = (url("a.jpg"), url("v.mov"))
        let result = SelectionState(selected: [a, v], focused: a).restricted(toVisible: [])
        #expect(result.selected.isEmpty)
        #expect(result.focused == nil)
    }

    // MARK: - Helpers

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/filter", isDirectory: true).appendingPathComponent(name)
    }

    private func item(_ name: String, _ kind: ListItemKind, in folder: URL) -> MediaFile {
        MediaFile(
            url: folder.appendingPathComponent(name),
            name: name,
            kind: kind,
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }

    private func file(_ name: String, in folder: URL) -> MediaFile {
        MediaFile(
            url: folder.appendingPathComponent(name),
            name: name,
            kind: .media(MediaKind(fileExtension: (name as NSString).pathExtension) ?? .jpeg),
            typeDescription: "JPEG イメージ",
            creationDate: nil,
            fileSize: 0
        )
    }
}
