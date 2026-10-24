import Foundation
import Testing
@testable import MediaViewerCore

@Suite("FavoriteName")
struct FavoriteNameTests {
    @Test("上限は 255 文字")
    func maximumLengthIs255() {
        #expect(FavoriteName.maximumLength == 255)
    }

    @Test("normalized は前後の空白と改行を取り除く")
    func normalizedTrimsWhitespace() {
        #expect(FavoriteName.normalized("  2025 ") == "2025")
        #expect(FavoriteName.normalized("\n2025\n") == "2025")
    }

    @Test("normalized は空・空白だけなら nil")
    func normalizedReturnsNilForBlank() {
        #expect(FavoriteName.normalized("") == nil)
        #expect(FavoriteName.normalized("   ") == nil)
        #expect(FavoriteName.normalized(" \n\t ") == nil)
    }

    @Test("中の改行（\\n・\\r\\n・U+2028）を取り除く")
    func removesInnerNewlines() {
        for newline in ["\n", "\r\n", "\u{2028}"] {
            #expect(FavoriteName.normalized("a\(newline)b") == "ab", "\(newline.unicodeScalars.map(\.value))")
            #expect(FavoriteName.sanitizedForEditing("a\(newline)b") == "ab", "\(newline.unicodeScalars.map(\.value))")
        }
    }

    @Test("sanitizedForEditing は前後の空白を残す")
    func sanitizedKeepsSurroundingSpaces() {
        #expect(FavoriteName.sanitizedForEditing(" a ") == " a ")
    }

    @Test("255 文字ちょうどはそのまま、超えた分は先頭 255 文字に切れる")
    func truncatesAtMaximumLength() {
        let exact = String(repeating: "a", count: 255)
        #expect(FavoriteName.sanitizedForEditing(exact) == exact)
        #expect(FavoriteName.normalized(exact) == exact)

        for count in [256, 300] {
            let long = String(repeating: "a", count: count)
            #expect(FavoriteName.sanitizedForEditing(long) == exact, "\(count)")
            #expect(FavoriteName.normalized(long) == exact, "\(count)")
        }
    }

    @Test("長さは書記素クラスタで数え、書記素の途中で切らない")
    func countsGraphemeClusters() {
        for unit in ["👨‍👩‍👧", "e\u{301}"] {
            let exact = String(repeating: unit, count: 255)
            #expect(FavoriteName.sanitizedForEditing(exact) == exact)

            let over = String(repeating: unit, count: 256)
            let truncated = FavoriteName.sanitizedForEditing(over)
            #expect(truncated == exact)
            #expect(truncated.count == 255)
            #expect(truncated.hasSuffix(unit))
        }
    }

    @Test("/ と : を含む名前をそのまま受け付ける")
    func acceptsSlashAndColon() {
        #expect(FavoriteName.normalized("a/b:c") == "a/b:c")
        #expect(FavoriteName.sanitizedForEditing("a/b:c") == "a/b:c")
    }
}
