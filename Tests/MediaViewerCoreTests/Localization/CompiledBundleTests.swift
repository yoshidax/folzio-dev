import Foundation
import MediaViewerLocalization
import Testing

@Suite("コンパイル済みの翻訳")
struct CompiledBundleTests {
    @Test("両言語の lproj から全キーを引ける（キー・空文字・番兵を返さない）")
    func lookups() throws {
        for language in LocalizationTestSupport.languages {
            let table = try #require(
                LocalizationBundle.table(language: language, in: LocalizationTestSupport.packageBundle)
            )
            for key in TextKey.allCases {
                let sentinel = "__MISSING_\(key.rawValue)__"
                let value = table.localizedString(forKey: key.rawValue, value: sentinel, table: nil)
                #expect(value != key.rawValue, "\(language): \(key.rawValue) is still the key")
                #expect(value != sentinel, "\(language): \(key.rawValue) is missing")
                #expect(!value.isEmpty, "\(language): \(key.rawValue) is empty")
            }
        }
    }

    @Test("整形した後に置換されていない % が残らない")
    func formattedValuesHaveNoPlaceholders() {
        for language in LocalizationTestSupport.languages {
            let localizer = LocalizationTestSupport.localizer(language)
            for key in TextKey.allCases {
                let value = sampleValue(for: key, localizer: localizer)
                #expect(!value.contains("%"), "\(language): \(key.rawValue) -> \(value)")
            }
        }
    }

    private func sampleValue(for key: TextKey, localizer: Localizer) -> String {
        let values: [TextValue] = key.arguments.map { argument in
            switch argument {
            case .text: return .text("sample")
            case .count: return .count(2)
            case .number: return .number(2)
            }
        }
        return localizer.text(key, values)
    }
}
