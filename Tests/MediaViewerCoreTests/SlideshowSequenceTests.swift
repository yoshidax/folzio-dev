import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SlideshowSequence")
struct SlideshowSequenceTests {
    private let folder = URL(fileURLWithPath: "/tmp/slideshow-sequence", isDirectory: true)

    @Test("対象は表示順のメディアだけで、親・フォルダ・zip・zip 内フォルダを除く")
    func candidatesExcludeNonMedia() {
        let files = [
            row("..", .parent),
            media("a.jpg", .jpeg),
            row("album", .folder),
            media("b.png", .png),
            row("photos.zip", .archive),
            row("inner", .directory),
            media("c.mp4", .mp4),
        ]

        #expect(SlideshowSequence.candidates(in: files) == [url("a.jpg"), url("b.png"), url("c.mp4")])
        #expect(SlideshowSequence.hasMedia(in: files))
        #expect(!SlideshowSequence.hasMedia(in: [row("..", .parent), row("album", .folder)]))
    }

    @Test("開始は選択中のフォーカスメディア、なければ選択メディアの先頭、なければ先頭")
    func startTargetUsesSelection() {
        let files = [media("a.jpg", .jpeg), media("b.png", .png), media("c.mp4", .mp4)]

        #expect(SlideshowSequence.startTarget(
            in: files,
            selected: [url("b.png")],
            focused: url("b.png")
        ) == url("b.png"))

        #expect(SlideshowSequence.startTarget(
            in: files,
            selected: [url("c.mp4"), url("a.jpg")],
            focused: url("c.mp4")
        ) == url("c.mp4"))

        #expect(SlideshowSequence.startTarget(
            in: files,
            selected: [url("a.jpg"), url("c.mp4")],
            focused: nil
        ) == url("a.jpg"))

        #expect(SlideshowSequence.startTarget(
            in: files,
            selected: [],
            focused: nil
        ) == url("a.jpg"))

        #expect(SlideshowSequence.startTarget(
            in: files,
            selected: [url("c.mp4")],
            focused: url("a.jpg")
        ) == url("c.mp4"))
    }

    @Test("開始はフォルダ選択だけなら対象先頭、対象なしなら nil")
    func startTargetSkipsNonMediaSelection() {
        let files = [row("album", .folder), media("a.jpg", .jpeg)]

        #expect(SlideshowSequence.startTarget(
            in: files,
            selected: [url("album")],
            focused: url("album")
        ) == url("a.jpg"))

        #expect(SlideshowSequence.startTarget(
            in: [row("..", .parent), row("album", .folder)],
            selected: [url("album")],
            focused: url("album")
        ) == nil)
    }

    @Test("次は最新の一覧順で次へ進み、末尾から先頭へ戻る")
    func nextTargetWraps() {
        let files = [media("a.jpg", .jpeg), media("b.png", .png), media("c.mp4", .mp4)]

        #expect(SlideshowSequence.nextTarget(in: files, focused: url("a.jpg")) == url("b.png"))
        #expect(SlideshowSequence.nextTarget(in: files, focused: url("b.png")) == url("c.mp4"))
        #expect(SlideshowSequence.nextTarget(in: files, focused: url("c.mp4")) == url("a.jpg"))
        #expect(SlideshowSequence.nextTarget(in: files, focused: nil) == url("a.jpg"))
        #expect(SlideshowSequence.nextTarget(in: files, focused: url("album")) == url("a.jpg"))
    }

    @Test("対象が1件なら同じ対象を返し、0件なら nil")
    func nextTargetHandlesSmallLists() {
        #expect(SlideshowSequence.nextTarget(
            in: [media("only.jpg", .jpeg)],
            focused: url("only.jpg")
        ) == url("only.jpg"))

        #expect(SlideshowSequence.nextTarget(
            in: [media("only.jpg", .jpeg)],
            focused: nil
        ) == url("only.jpg"))

        #expect(SlideshowSequence.nextTarget(
            in: [row("album", .folder)],
            focused: nil
        ) == nil)
    }

    @Test("同名でも URL が違えば別の対象として順に進む")
    func sameNameDifferentLocations() {
        let left = mediaAt(folder.appendingPathComponent("left/same.jpg"))
        let right = mediaAt(folder.appendingPathComponent("right/same.jpg"))
        let archive = mediaAt(ArchiveURL.entry(
            archive: folder.appendingPathComponent("photos.zip"),
            path: "same.jpg"
        ))
        let files = [left, right, archive]

        #expect(SlideshowSequence.candidates(in: files) == [left.url, right.url, archive.url])
        #expect(SlideshowSequence.nextTarget(in: files, focused: left.url) == right.url)
        #expect(SlideshowSequence.nextTarget(in: files, focused: right.url) == archive.url)
        #expect(SlideshowSequence.nextTarget(in: files, focused: archive.url) == left.url)
    }

    @Test("並べ替え後の一覧を渡すと、その順で次を返す")
    func nextTargetUsesCurrentOrder() {
        let files = [media("c.mp4", .mp4), media("b.png", .png), media("a.jpg", .jpeg)]

        #expect(SlideshowSequence.nextTarget(in: files, focused: url("b.png")) == url("a.jpg"))
        #expect(SlideshowSequence.nextTarget(in: files, focused: url("a.jpg")) == url("c.mp4"))
    }

    private func url(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    private func media(_ name: String, _ kind: MediaKind) -> MediaFile {
        MediaFile(
            url: url(name),
            name: name,
            kind: .media(kind),
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }

    private func mediaAt(_ url: URL) -> MediaFile {
        MediaFile(
            url: url,
            name: url.lastPathComponent,
            kind: .media(.jpeg),
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }

    private func row(_ name: String, _ kind: ListItemKind) -> MediaFile {
        MediaFile(
            url: url(name),
            name: name,
            kind: kind,
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
    }
}
