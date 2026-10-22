import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SearchListing")
struct SearchListingTests {
    private func listing(root: String, isDirectory: Bool = true) -> SearchListing {
        SearchListing(
            keyword: "cat",
            root: URL(fileURLWithPath: root, isDirectory: isDirectory),
            phase: .searching,
            totalCount: 0
        )
    }

    private func file(_ path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    @Test("起点のフォルダ名に、ファイルを含むフォルダまでの相対パスをつなぐ")
    func locationUnderRoot() {
        let search = listing(root: "/Users/me/Pictures")
        #expect(search.location(of: file("/Users/me/Pictures/a.jpg")) == "Pictures")
        #expect(search.location(of: file("/Users/me/Pictures/2024/trip/a.jpg")) == "Pictures/2024/trip")
    }

    @Test("起点が / なら絶対パス")
    func locationUnderFilesystemRoot() {
        let search = listing(root: "/")
        #expect(search.location(of: file("/Users/me/a.jpg")) == "/Users/me")
        #expect(search.location(of: file("/a.jpg")) == "/")
    }

    @Test("空白・日本語を含むパスと、末尾に / がある起点")
    func locationWithSpacesAndJapanese() {
        let expected = "写真 2024/旅行"
        let path = "/Users/me/写真 2024/旅行/a.jpg"
        #expect(listing(root: "/Users/me/写真 2024").location(of: file(path)) == expected)
        let trailing = SearchListing(
            keyword: "cat",
            root: URL(string: "file:///Users/me/%E5%86%99%E7%9C%9F%202024/")!,
            phase: .finished,
            totalCount: 0
        )
        #expect(trailing.root.absoluteString.hasSuffix("/"))
        #expect(trailing.location(of: file(path)) == expected)
    }
}
