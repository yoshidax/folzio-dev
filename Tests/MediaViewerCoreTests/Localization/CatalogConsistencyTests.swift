import Foundation
import MediaViewerLocalization
import Testing

@Suite("翻訳の管理元の突き合わせ")
struct CatalogConsistencyTests {
    @Test("管理元は TextKey の全ケースを両言語で過不足なく持つ")
    func keysMatch() throws {
        for language in LocalizationTestSupport.languages {
            let strings = try LocalizationTestSupport.strings(language)
            let dict = try LocalizationTestSupport.stringsdict(language)
            let all = Set(strings.keys).union(dict.keys)
            let expected = Set(TextKey.allCases.map(\.rawValue))

            let missing = expected.subtracting(all).sorted()
            let unused = all.subtracting(expected).sorted()
            #expect(missing.isEmpty, "\(language): 訳が無いキー \(missing)")
            #expect(unused.isEmpty, "\(language): TextKey に無いキー \(unused)")

            for key in TextKey.allCases {
                let inStrings = strings[key.rawValue] != nil
                let inDict = dict[key.rawValue] != nil
                #expect(inStrings != inDict, "\(language): \(key.rawValue) は strings と stringsdict のどちらか一方にだけ置く")
                let usesPlural = key.arguments.contains(.count)
                #expect(inDict == usesPlural, "\(language): 複数形のキーは stringsdict に置く (\(key.rawValue))")
            }
        }
    }

    @Test("複数形の表は英語に one と other、日本語に other を持つ")
    func pluralForms() throws {
        for language in LocalizationTestSupport.languages {
            let dict = try LocalizationTestSupport.stringsdict(language)
            for key in TextKey.allCases where key.arguments.contains(.count) {
                let entry = try #require(dict[key.rawValue], "\(language): \(key.rawValue)")
                #expect(entry["NSStringLocalizedFormatKey"] as? String == "%#@value@")
                let value = try #require(entry["value"] as? [String: Any], "\(language): \(key.rawValue)")
                #expect(value["NSStringFormatSpecTypeKey"] as? String == "NSStringPluralRuleType")
                #expect(value["NSStringFormatValueTypeKey"] as? String == "lld")
                #expect(value["other"] != nil, "\(language): \(key.rawValue) に other が無い")
                if language == "en" {
                    #expect(value["one"] != nil, "\(key.rawValue) に one が無い")
                }
            }
        }
    }

    @Test("すべての訳の書式指定が TextKey の引数と一致する")
    func argumentsMatch() throws {
        for language in LocalizationTestSupport.languages {
            let strings = try LocalizationTestSupport.strings(language)
            let dict = try LocalizationTestSupport.stringsdict(language)

            for key in TextKey.allCases {
                let expected = LocalizationTestSupport.expectedSpecifiers(for: key)
                if let value = strings[key.rawValue] {
                    let actual = try #require(LocalizationTestSupport.specifiers(value), "\(language): \(key.rawValue) の書式が不正")
                    #expect(Set(actual.map { $0.0 }) == Set(expected.map { $0.0 }), "\(language): \(key.rawValue) の位置")
                    #expect(actual.map(\.1).sorted() == expected.map(\.1).sorted(), "\(language): \(key.rawValue) の種類")
                } else if let entry = dict[key.rawValue],
                          let value = entry["value"] as? [String: String] {
                    for (form, translation) in value where form != "NSStringFormatSpecTypeKey" && form != "NSStringFormatValueTypeKey" {
                        let actual = try #require(LocalizationTestSupport.specifiers(translation), "\(language): \(key.rawValue).\(form) の書式が不正")
                        #expect(Set(actual.map { $0.0 }) == Set(expected.map { $0.0 }), "\(language): \(key.rawValue).\(form) の位置")
                        #expect(actual.map(\.1).sorted() == expected.map(\.1).sorted(), "\(language): \(key.rawValue).\(form) の種類")
                    }
                }
            }
        }
    }

    @Test("各ケースは TextKey の定義以外から参照されている")
    func casesAreReferenced() throws {
        let sources = ["Sources/MediaViewerApp", "Sources/MediaViewerLocalization"]
        var text = ""
        for directory in sources {
            let base = LocalizationTestSupport.repositoryRoot.appendingPathComponent(directory)
            let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "TextKey.swift" } ?? []
            for file in files {
                text += (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            }
        }
        for key in TextKey.allCases {
            let name = String(describing: key)
            #expect(text.contains(".\(name)"), "\(name) が参照されていない")
        }
    }

    @Test("すべての翻訳単位に翻訳者向けの説明がある")
    func commentsExist() {
        for key in TextKey.allCases {
            #expect(!key.comment.isEmpty, "\(key.rawValue) の説明が空")
        }
    }
}
