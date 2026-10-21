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
}
