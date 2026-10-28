import Foundation
import ImageIO
import Testing
@testable import FixtureKit
import MediaViewerCore

@Suite("SlideshowFixture")
struct SlideshowFixtureTests {
    @Test("mixed は画像3件・GIF・短長動画・サブフォルダ・zip・非対応テキストを持つ")
    func mixedSet() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FixtureSets.slideshow(in: directory, generateVideos: false)

        let mixed = directory.appendingPathComponent("slideshow/mixed", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: mixed.path).sorted()
        #expect(names == [
            "01-image.jpg",
            "02-image.png",
            "03-image.jpg",
            "04-animation.gif",
            "05-video-1s.mp4",
            "06-video-10s.mov",
            "notes.txt",
            "photos.zip",
            "sub",
        ])
        #expect(FileManager.default.fileExists(
            atPath: mixed.appendingPathComponent("sub/inside.jpg").path
        ))
    }

    @Test("single は動画1件、empty は非メディアだけ、search は同名別場所を持つ")
    func smallSets() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FixtureSets.slideshow(in: directory, generateVideos: false)

        let root = directory.appendingPathComponent("slideshow", isDirectory: true)
        let single = root.appendingPathComponent("single", isDirectory: true)
        let singleNames = try FileManager.default.contentsOfDirectory(atPath: single.path).sorted()
        #expect(singleNames == ["only.mp4"])

        let empty = root.appendingPathComponent("empty", isDirectory: true)
        let emptyNames = try FileManager.default.contentsOfDirectory(atPath: empty.path).sorted()
        #expect(emptyNames == ["notes.txt"])

        for side in ["left", "right"] {
            let url = root.appendingPathComponent("search/\(side)/same.jpg")
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("slides.zip はルートの対応メディアと sub 階層を持つ")
    func slidesZip() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FixtureSets.slideshow(in: directory, generateVideos: false)

        let zip = directory.appendingPathComponent("slideshow/slides.zip")
        let index = try await ZipArchiveReader(kindNames: FixtureKit.kindNames).open(zip)

        #expect(index.items(in: "").map(\.name).sorted() == [
            "01.jpg",
            "02.png",
            "03-animation.gif",
            "04-video.mp4",
            "sub",
        ])
        #expect(index.items(in: "sub/").map(\.name).sorted() == ["10.jpg", "11.png"])
    }

    @Test("transitions は表示順が分かる5件を名前昇順で持ち、3件目だけデコードできない")
    func transitionsSet() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FixtureSets.slideshow(in: directory, generateVideos: false)

        let folder = directory.appendingPathComponent("slideshow/transitions", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(names == [
            "01-image.jpg",
            "02-video-1s.mp4",
            "03-broken.jpg",
            "04-image.png",
            "05-video-10s.mov",
        ])

        for name in ["01-image.jpg", "04-image.png"] {
            let source = CGImageSourceCreateWithURL(folder.appendingPathComponent(name) as CFURL, nil)
            let image = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            #expect(image != nil, "\(name) can be decoded")
        }
        let brokenSource = CGImageSourceCreateWithURL(
            folder.appendingPathComponent("03-broken.jpg") as CFURL, nil
        )
        let brokenImage = brokenSource.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
        #expect(brokenImage == nil, "03-broken.jpg cannot be decoded")
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SlideshowFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
