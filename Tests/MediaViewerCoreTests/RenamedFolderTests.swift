import Foundation
import Testing
@testable import MediaViewerCore

@Suite("RenamedFolder")
struct RenamedFolderTests {
    private let renamed = RenamedFolder(
        from: URL(fileURLWithPath: "/tmp/r/Album/2025"),
        to: URL(fileURLWithPath: "/tmp/r/Album/2025b")
    )

    @Test("名前を変えたフォルダ自身を付け替える。ディレクトリを表す URL は結果もディレクトリ")
    func rebasesFolderItself() {
        #expect(renamed.rebase(URL(fileURLWithPath: "/tmp/r/Album/2025"))?.path == "/tmp/r/Album/2025b")
        let directory = renamed.rebase(URL(fileURLWithPath: "/tmp/r/Album/2025/", isDirectory: true))
        #expect(directory?.path == "/tmp/r/Album/2025b")
        #expect(directory?.hasDirectoryPath == true)
    }

    @Test("配下の URL を付け替える")
    func rebasesDescendants() {
        #expect(
            renamed.rebase(URL(fileURLWithPath: "/tmp/r/Album/2025/Trip/a.jpg"))?.path
                == "/tmp/r/Album/2025b/Trip/a.jpg"
        )
    }

    @Test("名前の前方が同じ兄弟のフォルダは付け替えない", arguments: [
        "/tmp/r/Album/20250/a.jpg",
        "/tmp/r/Album/2025b/a.jpg",
    ])
    func ignoresSiblingsWithSharedPrefix(path: String) {
        #expect(renamed.rebase(URL(fileURLWithPath: path)) == nil)
    }

    @Test("関係のない URL は nil で、rebaseOrSelf は元の URL を返す", arguments: [
        "/tmp/r/Album/Other",
        "/tmp/r/Album",
        "/tmp/x",
    ])
    func ignoresUnrelatedURLs(path: String) {
        let url = URL(fileURLWithPath: path)
        #expect(renamed.rebase(url) == nil)
        #expect(renamed.rebaseOrSelf(url) == url)
    }

    @Test("表記の違い（. と ..）を含む URL も付け替える", arguments: [
        "/tmp/r/Album/./2025/a.jpg",
        "/tmp/r/Album/x/../2025/a.jpg",
    ])
    func rebasesNonStandardizedURLs(path: String) {
        #expect(renamed.rebase(URL(fileURLWithPath: path))?.path == "/tmp/r/Album/2025b/a.jpg")
    }

    @Test("zip の中の項目と .. は、zip の場所を付け替えて作り直す")
    func rebasesArchiveURLs() {
        let oldArchive = URL(fileURLWithPath: "/tmp/r/Album/2025/t.zip")
        let newArchive = URL(fileURLWithPath: "/tmp/r/Album/2025b/t.zip")
        #expect(
            renamed.rebase(ArchiveURL.entry(archive: oldArchive, path: "dir/a.jpg"))
                == ArchiveURL.entry(archive: newArchive, path: "dir/a.jpg")
        )
        #expect(
            renamed.rebase(ArchiveURL.parentLink(of: ArchiveLocation(archive: oldArchive, directory: "dir/")))
                == ArchiveURL.parentLink(of: ArchiveLocation(archive: newArchive, directory: "dir/"))
        )
        let unrelated = URL(fileURLWithPath: "/tmp/r/Other/t.zip")
        #expect(renamed.rebase(ArchiveURL.entry(archive: unrelated, path: "a.jpg")) == nil)
    }

    @Test("通常のフォルダの .. とファイル以外のスキームは nil")
    func ignoresOtherSchemes() {
        #expect(renamed.rebase(ParentLink.url(for: URL(fileURLWithPath: "/tmp/r/Album/2025"))) == nil)
        #expect(renamed.rebase(URL(string: "https://example.com/")!) == nil)
    }

    @Test("from と to が同じなら、自身と配下はそのままの場所を返す")
    func sameLocationKeepsURLs() {
        let same = RenamedFolder(from: renamed.from, to: renamed.from)
        #expect(same.rebase(URL(fileURLWithPath: "/tmp/r/Album/2025"))?.path == "/tmp/r/Album/2025")
        #expect(same.rebase(URL(fileURLWithPath: "/tmp/r/Album/2025/a.jpg"))?.path == "/tmp/r/Album/2025/a.jpg")
    }
}
