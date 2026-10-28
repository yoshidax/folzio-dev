import Foundation
import FixtureKit
import MediaViewerLocalization
import Testing

@Suite("翻訳の参照先")
struct LocalizationBundleTests {
    @Test(".app の lproj があれば本体のバンドルを使う")
    func resolvesMainBundle() throws {
        let url = try LocalizationFixtures.makeBundle(tables: [
            "en": ["error.searchRoot.empty": "Enter a folder to search in"],
            "ja": ["error.searchRoot.empty": "検索起点ディレクトリを入力してください"],
        ])
        defer { LocalizationFixtures.remove(url) }
        let bundle = try #require(Bundle(url: url))
        #expect(LocalizationBundle.resolve(main: bundle) == bundle)
    }

    @Test("lproj が無ければパッケージのバンドルを使う")
    func resolvesPackageBundle() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaViewerEmptyBundle-\(UUID().uuidString).bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent("Contents/Resources", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer { LocalizationFixtures.remove(url) }
        let bundle = try #require(Bundle(url: url))
        #expect(LocalizationBundle.resolve(main: bundle) == LocalizationBundle.packageBundle)
    }

    @Test("パッケージのバンドルから作った Localizer は両言語で内部キーを返さない")
    func packageBundleLocalizer() {
        for language in LocalizationTestSupport.languages {
            let localizer = LocalizationTestSupport.localizer(language)
            for key in TextKey.allCases {
                let value = localizer.text(key, key.arguments.map { argument -> TextValue in
                    switch argument {
                    case .text: return .text("x")
                    case .count: return .count(1)
                    case .number: return .number(1)
                    }
                })
                #expect(!value.hasPrefix("\(key.rawValue)"), "\(language): \(key.rawValue)")
                #expect(!value.isEmpty)
            }
        }
    }
}
