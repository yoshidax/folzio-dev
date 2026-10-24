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

    // MARK: - 表示名（FR-099〜101、R48・R50）

    @Test("表示名を付けると customName と displayName に反映される")
    func commitSetsDisplayName() {
        var favorites = FavoriteFolders(urls: [a, b])
        let changed = favorites.commitDisplayName("2025（バックアップ）", for: b, defaultName: "2025")
        #expect(changed)
        #expect(favorites.customName(for: b) == "2025（バックアップ）")
        #expect(favorites.displayName(for: b, defaultName: "2025") == "2025（バックアップ）")
        #expect(favorites.customName(for: a) == nil)
        #expect(favorites.displayName(for: a, defaultName: "a") == "a")
    }

    @Test("別の名前へ変更できる")
    func commitChangesDisplayName() {
        var favorites = FavoriteFolders(urls: [a])
        favorites.commitDisplayName("one", for: a, defaultName: "a")
        let changed = favorites.commitDisplayName("two", for: a, defaultName: "a")
        #expect(changed)
        #expect(favorites.customName(for: a) == "two")
    }

    @Test("空・空白だけで確定すると表示名を解除する")
    func commitBlankClearsDisplayName() {
        for blank in ["", "   "] {
            var favorites = FavoriteFolders(urls: [a])
            favorites.commitDisplayName("one", for: a, defaultName: "a")
            let changed = favorites.commitDisplayName(blank, for: a, defaultName: "a")
            #expect(changed, "\(blank.debugDescription)")
            #expect(favorites.customName(for: a) == nil)
            #expect(favorites.displayName(for: a, defaultName: "a") == "a")
        }
    }

    @Test("現在の表示名と同じ名前の確定は何もしない")
    func commitSameNameIsNoOp() {
        var favorites = FavoriteFolders(urls: [a])
        favorites.commitDisplayName("one", for: a, defaultName: "a")
        let before = favorites
        for same in ["one", " one ", "one\n"] {
            let changed = favorites.commitDisplayName(same, for: a, defaultName: "a")
            #expect(!changed, "\(same.debugDescription)")
            #expect(favorites == before)
        }
    }

    @Test("表示名なしの項目で defaultName と同じ名前を確定しても表示名は付かない（R50）")
    func commitDefaultNameWithoutCustomNameIsNoOp() {
        var favorites = FavoriteFolders(urls: [a])
        let changed = favorites.commitDisplayName("a", for: a, defaultName: "a")
        #expect(!changed)
        #expect(favorites.customName(for: a) == nil)
        #expect(favorites.customNamesByPath.isEmpty)
    }

    @Test("表示名ありの項目で defaultName と同じ名前を確定すると表示名として残る（EC-41）")
    func commitDefaultNameWithCustomNameIsKept() {
        var favorites = FavoriteFolders(urls: [a])
        favorites.commitDisplayName("one", for: a, defaultName: "a")
        let changed = favorites.commitDisplayName("a", for: a, defaultName: "a")
        #expect(changed)
        #expect(favorites.customName(for: a) == "a")
    }

    @Test("同じ表示名を複数の項目に付けられ、/ と : も受け付ける（EC-41）")
    func commitAllowsDuplicatesAndSpecialCharacters() {
        var favorites = FavoriteFolders(urls: [a, b])
        let changedA = favorites.commitDisplayName("same", for: a, defaultName: "a")
        let changedB = favorites.commitDisplayName("same", for: b, defaultName: "b")
        #expect(changedA)
        #expect(changedB)
        #expect(favorites.customName(for: a) == "same")
        #expect(favorites.customName(for: b) == "same")

        let changedSpecial = favorites.commitDisplayName("a/b:c", for: a, defaultName: "a")
        #expect(changedSpecial)
        #expect(favorites.customName(for: a) == "a/b:c")
    }

    @Test("未登録の場所への commit は false で何も変えない")
    func commitRejectsUnregistered() {
        var favorites = FavoriteFolders(urls: [a])
        let changed = favorites.commitDisplayName("x", for: d, defaultName: "d")
        #expect(!changed)
        #expect(favorites.customNamesByPath.isEmpty)
        #expect(favorites.customName(for: d) == nil)
    }

    @Test("remove で表示名も消え、add し直すと表示名なしになる（EC-44）")
    func removeDiscardsDisplayName() {
        var favorites = FavoriteFolders(urls: [a, b])
        favorites.commitDisplayName("one", for: b, defaultName: "b")
        favorites.remove(b)
        #expect(favorites.customNamesByPath.isEmpty)

        favorites.add(b)
        #expect(favorites.customName(for: b) == nil)
    }

    @Test("表記の違いでも同じ登録の表示名を引ける・設定できる")
    func displayNameMatchesAliases() {
        var favorites = FavoriteFolders(urls: [a])
        for alias in aliasesOfA {
            let changed = favorites.commitDisplayName("one", for: alias, defaultName: "a")
            #expect(changed, "\(alias.path)")
            #expect(favorites.customName(for: alias) == "one", "\(alias.path)")
            #expect(favorites.displayName(for: alias, defaultName: "a") == "one", "\(alias.path)")
            favorites.commitDisplayName("", for: a, defaultName: "a")
        }
    }

    @Test("init(customNames:) は未登録のキーと空になる値を捨て、長さと改行を整える")
    func initSanitizesCustomNames() {
        let long = String(repeating: "x", count: 256)
        let favorites = FavoriteFolders(
            urls: [a, b, c],
            customNames: [
                a.path: "one",
                d.path: "unregistered",
                b.path: "  ",
                c.path: long,
            ]
        )
        #expect(favorites.customNamesByPath == [a.path: "one", c.path: String(repeating: "x", count: 255)])

        let withNewline = FavoriteFolders(urls: [a], customNames: [a.path: "o\nne"])
        #expect(withNewline.customName(for: a) == "one")
    }

    @Test("customNamesByPath のキーは standardizedFileURL.path")
    func customNamesByPathUsesStandardizedPath() {
        var favorites = FavoriteFolders(urls: [URL(fileURLWithPath: "/tmp/fav/x/../a")])
        favorites.commitDisplayName("one", for: a, defaultName: "a")
        #expect(favorites.customNamesByPath == ["/tmp/fav/a": "one"])

        let fromAlias = FavoriteFolders(urls: [a], customNames: ["/tmp/fav/a/": "two"])
        #expect(fromAlias.customNamesByPath == ["/tmp/fav/a": "two"])
    }

    @Test("等価比較は表示名を含む")
    func equalityIncludesDisplayNames() {
        let plain = FavoriteFolders(urls: [a, b])
        let named = FavoriteFolders(urls: [a, b], customNames: [b.path: "one"])
        #expect(plain != named)
        #expect(named == FavoriteFolders(urls: [a, b], customNames: [b.path: "one"]))
    }
}
