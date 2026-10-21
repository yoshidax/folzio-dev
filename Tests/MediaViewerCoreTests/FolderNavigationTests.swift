import Foundation
import Testing
@testable import MediaViewerCore

@Suite("FolderNavigation")
struct FolderNavigationTests {
    private static let roots = [
        URL(fileURLWithPath: "/", isDirectory: true),
        URL(fileURLWithPath: "/Users/me", isDirectory: true),
        URL(fileURLWithPath: "/Volumes/Ext", isDirectory: true),
    ]

    private func folder(_ path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    private func enclosing(_ path: String, roots: [URL] = Self.roots) -> String? {
        FolderNavigation.enclosingFolder(of: folder(path), roots: roots)?.standardizedFileURL.path
    }

    @Test("ルートそのものでは nil", arguments: ["/", "/Users/me", "/Users/me/", "/Volumes/Ext", "/Volumes/Ext/"])
    func rootHasNoEnclosingFolder(path: String) {
        #expect(enclosing(path) == nil)
    }

    @Test("ホームの配下は、最も深いルートのホームの中で親を返す")
    func deepestRootWins() {
        #expect(enclosing("/Users/me/a") == "/Users/me")
        #expect(enclosing("/Users/me/a/b") == "/Users/me/a")
    }

    @Test("起動ボリュームと外付けボリュームの中で親を返す")
    func volumes() {
        #expect(enclosing("/Users/x") == "/Users")
        #expect(enclosing("/Users") == "/")
        #expect(enclosing("/Volumes/Ext/p") == "/Volumes/Ext")
    }

    @Test("パスの要素で比べ、文字列の前方一致で誤らない")
    func comparesPathComponents() {
        let homeOnly = [folder("/Users/me")]
        #expect(enclosing("/Users/me2/a", roots: homeOnly) == nil)
        #expect(enclosing("/Users/me/./a/../b/c", roots: homeOnly) == "/Users/me/b")
        #expect(enclosing("/Users/me/./a/../b", roots: homeOnly) == "/Users/me")
    }

    @Test("どのルートにも含まれない、またはルートが空なら nil")
    func outsideRoots() {
        #expect(enclosing("/Volumes/Other/a", roots: [folder("/Users/me"), folder("/Volumes/Ext")]) == nil)
        #expect(enclosing("/Users/me/a", roots: []) == nil)
    }

    // MARK: - folderToShow(afterTrashing:showing:roots:)（FR-079）

    private static let trashRoots = [
        URL(fileURLWithPath: "/", isDirectory: true),
        URL(fileURLWithPath: "/Users/me", isDirectory: true),
    ]

    private func shown(_ trashed: [String], showing: String, roots: [URL] = Self.trashRoots) -> String? {
        FolderNavigation.folderToShow(
            afterTrashing: trashed.map { folder($0) },
            showing: folder(showing),
            roots: roots
        )?.standardizedFileURL.path
    }

    @Test("表示中のフォルダ自身をゴミ箱に入れたら親を返す")
    func trashedShowingFolder() {
        #expect(shown(["/Users/me/a/b"], showing: "/Users/me/a/b") == "/Users/me/a")
    }

    @Test("祖先をゴミ箱に入れたら祖先の親を返す（ルートそのものが親でもよい）")
    func trashedAncestor() {
        #expect(shown(["/Users/me/a"], showing: "/Users/me/a/b/c") == "/Users/me")
    }

    @Test("複数なら最も浅いものの親を返し、配列の順に依らない")
    func shallowestWins() {
        #expect(shown(["/Users/me/a/b", "/Users/me/a"], showing: "/Users/me/a/b/c") == "/Users/me")
        #expect(shown(["/Users/me/a", "/Users/me/a/b"], showing: "/Users/me/a/b/c") == "/Users/me")
    }

    @Test("兄弟・配下だけ・名前の接頭辞だけ・空・ルート・ルートが空は nil")
    func unrelatedIsNil() {
        #expect(shown(["/Users/me/a/x"], showing: "/Users/me/a/b") == nil)
        #expect(shown(["/Users/me/a/b/c"], showing: "/Users/me/a/b") == nil)
        #expect(shown(["/Users/me/a/b"], showing: "/Users/me/a/b2") == nil)
        #expect(shown([], showing: "/Users/me/a/b") == nil)
        #expect(shown(["/Users/me"], showing: "/Users/me/a") == nil)
        #expect(shown(["/Users/me/a/b"], showing: "/Users/me/a/b", roots: []) == nil)
    }

    @Test("末尾の / や .. を含む表記でも同じ結果になる")
    func standardizesPaths() {
        #expect(shown(["/Users/me/a/b/"], showing: "/Users/me/a/b") == "/Users/me/a")
        #expect(shown(["/Users/me/a/b"], showing: "/Users/me/a/b/") == "/Users/me/a")
        #expect(shown(["/Users/me/a/x/../b"], showing: "/Users/me/a/b/c") == "/Users/me/a")
        #expect(shown(["/Users/me/a/b"], showing: "/Users/me/a/x/../b") == "/Users/me/a")
    }
}
