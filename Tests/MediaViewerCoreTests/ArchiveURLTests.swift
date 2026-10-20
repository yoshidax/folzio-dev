import Foundation
import Testing
@testable import MediaViewerCore

@Suite("ArchiveURL")
struct ArchiveURLTests {
    private let archive = URL(fileURLWithPath: "/tmp/z/写真 集.zip")

    @Test("項目の URL は mvzip スキームで、名前と拡張子を返す")
    func entryURLShape() {
        let url = ArchiveURL.entry(archive: archive, path: "sub/a b.jpg")
        #expect(url.scheme == "mvzip")
        #expect(url.lastPathComponent == "a b.jpg")
        #expect(url.pathExtension == "jpg")
        #expect(url.isFileURL == false)
    }

    @Test("parse で元の値に戻る")
    func parseRoundTrip() throws {
        let url = ArchiveURL.entry(archive: archive, path: "sub/a b.jpg")
        let parsed = try #require(ArchiveURL.parse(url))
        #expect(parsed.archive == archive)
        #expect(parsed.path == "sub/a b.jpg")
        #expect(parsed.isParentLink == false)
    }

    @Test("日本語・空白・#・?・% を含むパスと zip のパスでも往復で一致する")
    func parseRoundTripWithSpecialCharacters() throws {
        let archives = [
            archive,
            URL(fileURLWithPath: "/tmp/z/a#b?c%d;e f.zip"),
            URL(fileURLWithPath: "/tmp/日本語/フォルダ 1/写真.zip"),
        ]
        let paths = [
            "写真/日本語 name.jpg",
            "a#b/c?d/e%20f.png",
            "100%/;semi;/x.gif",
            "sp ace/",
        ]
        for archive in archives {
            for path in paths {
                let url = ArchiveURL.entry(archive: archive, path: path)
                let parsed = try #require(ArchiveURL.parse(url))
                #expect(parsed.archive == archive)
                #expect(parsed.path == path)
                #expect(parsed.isParentLink == false)
            }
        }
    }

    @Test("ディレクトリは末尾の / を保ち、最上位は空のパス")
    func directoryAndRoot() throws {
        let directory = ArchiveURL.entry(archive: archive, path: "sub/")
        #expect(try #require(ArchiveURL.parse(directory)).path == "sub/")
        #expect(directory.absoluteString.hasPrefix("mvzip:///sub/?archive="))

        let root = ArchiveURL.entry(archive: archive, path: "")
        #expect(root.absoluteString.hasPrefix("mvzip:///?archive="))
        let parsed = try #require(ArchiveURL.parse(root))
        #expect(parsed.path == "")
        #expect(parsed.archive == archive)
    }

    @Test("parentLink は fragment が parent で、同じ階層どうしだけが等しい")
    func parentLink() throws {
        let location = ArchiveLocation(archive: archive, directory: "sub/")
        let link = ArchiveURL.parentLink(of: location)
        #expect(link.fragment == "parent")
        let parsed = try #require(ArchiveURL.parse(link))
        #expect(parsed.isParentLink == true)
        #expect(parsed.path == "sub/")
        #expect(parsed.archive == archive)

        #expect(link == ArchiveURL.parentLink(of: ArchiveLocation(archive: archive, directory: "sub/")))
        #expect(link != ArchiveURL.parentLink(of: ArchiveLocation(archive: archive, directory: "")))
        #expect(link != ArchiveURL.parentLink(of: ArchiveLocation(archive: archive, directory: "sub/deep/")))
        #expect(link != ArchiveURL.entry(archive: archive, path: "sub/"))
    }

    @Test("同じ引数で作った URL は等しく、Set で1つにまとまる")
    func equalityAndHashing() {
        let first = ArchiveURL.entry(archive: archive, path: "sub/a b.jpg")
        let second = ArchiveURL.entry(archive: archive, path: "sub/a b.jpg")
        #expect(first == second)
        let set: Set<URL> = [first, second, ArchiveURL.entry(archive: archive, path: "sub/c.jpg")]
        #expect(set.count == 2)
    }

    @Test("ファイル URL や mvzip 以外のスキームの parse は nil")
    func parseRejectsOtherSchemes() {
        #expect(ArchiveURL.parse(URL(fileURLWithPath: "/tmp/a.jpg")) == nil)
        #expect(ArchiveURL.parse(URL(string: "other:///a.jpg?archive=%2Ftmp%2Fz.zip")!) == nil)
    }

    @Test("archive の指定がない mvzip の URL は parse できない")
    func parseRejectsMissingArchive() {
        #expect(ArchiveURL.parse(URL(string: "mvzip:///a.jpg")!) == nil)
    }

    @Test("ArchiveLocation.parent は1つ上の階層を返し、最上位では nil")
    func locationParent() {
        let deep = ArchiveLocation(archive: archive, directory: "a/b/")
        #expect(deep.parent == ArchiveLocation(archive: archive, directory: "a/"))
        #expect(deep.parent?.parent == ArchiveLocation(archive: archive, directory: ""))
        #expect(deep.parent?.parent?.parent == nil)
    }
}
