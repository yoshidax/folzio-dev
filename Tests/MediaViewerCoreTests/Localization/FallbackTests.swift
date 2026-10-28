import Foundation
import FixtureKit
import MediaViewerLocalization
import Testing

@Suite("訳が欠けたときのフォールバック")
struct FallbackTests {
    @Test("表示言語の訳が無ければ英語（開発言語）の訳を使い、キーや空欄を出さない")
    func fallsBackToEnglish() throws {
        let url = try LocalizationFixtures.makeBundle(tables: [
            "en": ["error.searchRoot.empty": "Enter a folder to search in"],
            "ja": [:],
        ])
        defer { LocalizationFixtures.remove(url) }
        let bundle = try #require(Bundle(url: url))
        let localizer = Localizer(
            bundle: bundle,
            language: "ja",
            development: "en",
            locale: Locale(identifier: "ja_JP")
        )

        #expect(localizer.text(.errorSearchRootEmpty) == "Enter a folder to search in")
        #expect(localizer.text(.errorSearchRootEmpty) != "error.searchRoot.empty")
        #expect(!localizer.text(.errorSearchRootEmpty).isEmpty)
    }

    @Test("表示言語の訳があればそれを優先する")
    func prefersDisplayLanguage() throws {
        let url = try LocalizationFixtures.makeBundle(tables: [
            "en": ["error.searchRoot.empty": "Enter a folder to search in"],
            "ja": ["error.searchRoot.empty": "検索起点ディレクトリを入力してください"],
        ])
        defer { LocalizationFixtures.remove(url) }
        let bundle = try #require(Bundle(url: url))
        let localizer = Localizer(
            bundle: bundle,
            language: "ja",
            development: "en",
            locale: Locale(identifier: "ja_JP")
        )
        #expect(localizer.text(.errorSearchRootEmpty) == "検索起点ディレクトリを入力してください")
    }
}
