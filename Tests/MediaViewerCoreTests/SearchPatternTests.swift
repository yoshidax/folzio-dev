import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SearchPattern")
struct SearchPatternTests {
    private let nfdGa = "か\u{3099}.png".decomposedStringWithCanonicalMapping

    private func pattern(_ keyword: String) throws -> SearchPattern {
        try #require(SearchPattern(keyword: keyword))
    }

    @Test("空・空白だけのキーワードは nil。前後の空白を除き、ワイルドカードの有無を持つ")
    func initTrimsAndRejectsEmpty() throws {
        #expect(SearchPattern(keyword: "") == nil)
        #expect(SearchPattern(keyword: "  ") == nil)
        #expect(SearchPattern(keyword: "\n\t") == nil)
        #expect(try pattern(" cat ").keyword == "cat")
        #expect(try pattern("cat").usesWildcards == false)
        #expect(try pattern("*.png").usesWildcards == true)
        #expect(try pattern("IMG_?.jpg").usesWildcards == true)
        #expect(try pattern("[1].jpg").usesWildcards == false)
    }

    @Test("ワイルドカードなしは拡張子を含むファイル名への部分一致で、大文字小文字を区別しない")
    func substringMatch() throws {
        let cat = try pattern("cat")
        #expect(cat.matches(fileName: "Cat01.jpg"))
        #expect(cat.matches(fileName: "my_cat.mov"))
        #expect(cat.matches(fileName: "CAT.PNG"))
        #expect(!cat.matches(fileName: "dog.png"))
        #expect(try pattern("png").matches(fileName: "a.png"))
    }

    @Test("NFC と NFD の違いは区別せず、濁点・全角・ひらがなとカタカナは区別する")
    func normalization() throws {
        #expect(nfdGa.unicodeScalars.contains("\u{3099}"))
        #expect(try pattern("が").matches(fileName: nfdGa))
        #expect(try pattern("が".decomposedStringWithCanonicalMapping).matches(fileName: "が.png"))
        #expect(!(try pattern("か").matches(fileName: "が.png")))
        #expect(!(try pattern("ｃａｔ").matches(fileName: "cat.jpg")))
        #expect(!(try pattern("ネコ").matches(fileName: "ねこ.jpg")))
    }

    @Test("ワイルドカードありはファイル名全体との一致")
    func wildcardMatch() throws {
        let png = try pattern("*.png")
        #expect(png.matches(fileName: "a.png"))
        #expect(!png.matches(fileName: "a.png.txt"))
        #expect(!png.matches(fileName: "a.PNG.bak"))
        #expect(try pattern("*.PNG").matches(fileName: "a.png"))

        let img = try pattern("IMG_????.jpg")
        #expect(img.matches(fileName: "IMG_0001.jpg"))
        #expect(!img.matches(fileName: "IMG_12.jpg"))
        #expect(!img.matches(fileName: "IMG_00001.jpg"))

        let star = try pattern("*")
        #expect(star.matches(fileName: "a.jpg"))
        #expect(star.matches(fileName: "x"))

        let abc = try pattern("a*b*c")
        #expect(abc.matches(fileName: "aXbYc"))
        #expect(abc.matches(fileName: "abc"))
        #expect(!abc.matches(fileName: "acb"))

        #expect(try pattern("**.jpg").matches(fileName: "x.jpg"))
        #expect(try pattern("?.png").matches(fileName: nfdGa))
        #expect(!(try pattern("cat*").matches(fileName: "my_cat.mov")))
    }

    @Test("記号はただの文字として扱う")
    func symbolsAreLiteral() throws {
        let bracket = try pattern("[1].jpg")
        #expect(bracket.matches(fileName: "[1].jpg"))
        #expect(!bracket.matches(fileName: "1.jpg"))
        #expect(try pattern("a\\b").matches(fileName: "a\\b.jpg"))
    }

    @Test("長い名前と多くの * でも一致しない結果をすぐ返す")
    func longNameDoesNotHang() throws {
        let name = String(repeating: "a", count: 200)
        #expect(!(try pattern("*a*a*a*a*b").matches(fileName: name)))
        #expect(try pattern("*a*a*a*a*").matches(fileName: name))
    }
}
