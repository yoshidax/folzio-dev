import Foundation
import Testing
@testable import MediaViewerCore

@Suite("FavoriteFolders")
struct FavoriteFoldersTests {
    private let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
    private let b = URL(fileURLWithPath: "/tmp/fav/b", isDirectory: true)
    private let c = URL(fileURLWithPath: "/tmp/fav/c", isDirectory: true)
    private let d = URL(fileURLWithPath: "/tmp/fav/d", isDirectory: true)

    /// 登録済みの a と同じ場所を指す別表記（末尾の `/`・`..` を含む）
    private var aliasesOfA: [URL] {
        [
            a,
            URL(fileURLWithPath: "/tmp/fav/a/"),
            URL(fileURLWithPath: "/tmp/fav/x/../a"),
        ]
    }

    @Test("既定は空")
    func defaultsToEmpty() {
        #expect(FavoriteFolders().urls.isEmpty)
    }

    @Test("add は登録順に末尾へ追加する")
    func addAppendsInOrder() {
        var favorites = FavoriteFolders()
        let added = [a, b, c].map { favorites.add($0) }
        #expect(added == [true, true, true])
        #expect(favorites.urls == [a, b, c])
    }

    @Test("登録済みの場所は表記が違っても追加しない")
    func addRejectsDuplicates() {
        var favorites = FavoriteFolders(urls: [a])
        for alias in aliasesOfA {
            let added = favorites.add(alias)
            #expect(!added, "\(alias.path)")
            #expect(favorites.urls == [a])
        }
    }

    @Test("contains は表記の違いを同一視する")
    func containsMatchesAliases() {
        let favorites = FavoriteFolders(urls: [a])
        for alias in aliasesOfA {
            #expect(favorites.contains(alias), "\(alias.path)")
        }
        #expect(!favorites.contains(d))
    }

    @Test("remove は登録済みだけを取り除き、順序を保つ")
    func removeKeepsOrder() {
        var favorites = FavoriteFolders(urls: [a, b, c])
        let removedB = favorites.remove(b)
        #expect(removedB)
        #expect(favorites.urls == [a, c])

        let removedD = favorites.remove(d)
        #expect(!removedD)
        #expect(favorites.urls == [a, c])
    }

    @Test("remove は .. を含む表記でも取り除ける")
    func removeMatchesAliases() {
        var favorites = FavoriteFolders(urls: [a, b, c])
        let removed = favorites.remove(URL(fileURLWithPath: "/tmp/fav/x/../b"))
        #expect(removed)
        #expect(favorites.urls == [a, c])
    }

    @Test("init(urls:) は重複を先勝ちで除き、順序を保つ")
    func initRemovesDuplicates() {
        let favorites = FavoriteFolders(urls: [a, b, a, c, b])
        #expect(favorites.urls == [a, b, c])
    }
}
