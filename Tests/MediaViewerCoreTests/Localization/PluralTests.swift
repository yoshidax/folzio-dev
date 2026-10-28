import Foundation
import MediaViewerLocalization
import Testing

@Suite("複数形と件数の書式")
struct PluralTests {
    private let en = LocalizationTestSupport.localizer("en", localeIdentifier: "en_US")
    private let ja = LocalizationTestSupport.localizer("ja", localeIdentifier: "ja_JP")

    @Test("英語は1件と2件以上（0件を含む）で語形が変わり、日本語は変わらない")
    func pluralRules() {
        for key in TextKey.allCases where key.arguments.contains(.count) {
            let oneEN = normalized(en, key, 1)
            let twoEN = normalized(en, key, 2)
            #expect(oneEN != twoEN, "\(key.rawValue): 英語の単数と複数が同じ")
            #expect(normalized(en, key, 0) == twoEN, "\(key.rawValue): 0件は複数形")
            #expect(normalized(en, key, 1000) == twoEN, "\(key.rawValue): 1000件は複数形")

            #expect(normalized(ja, key, 1) == normalized(ja, key, 2), "\(key.rawValue): 日本語の語形が変わる")
            #expect(normalized(ja, key, 0) == normalized(ja, key, 2), "\(key.rawValue): 日本語の語形が変わる")
        }

        for key in [TextKey.contextCopyMultiple, .searchBarCount, .searchBarCountLimited] {
            #expect(value(en, key, 1000).contains("1,000"), "\(key.rawValue): 桁区切り")
            #expect(value(ja, key, 1000).contains("1,000"), "\(key.rawValue): 桁区切り")
        }
    }

    /// Wording with numeric differences removed.
    private func normalized(_ localizer: Localizer, _ key: TextKey, _ count: Int) -> String {
        value(localizer, key, count)
            .replacingOccurrences(of: localizer.count(count), with: "<n>")
    }

    private func value(_ localizer: Localizer, _ key: TextKey, _ count: Int) -> String {
        let values = key.arguments.map { argument -> TextValue in
            switch argument {
            case .text: return .text("3")
            case .count: return .count(count)
            case .number: return .number(count)
            }
        }
        return localizer.text(key, values)
    }

    @Test("英語の件数の文")
    func englishForms() {
        #expect(en.text(.contextCopyMultiple, .count(1)) == "Copy 1 Item")
        #expect(en.text(.contextCopyMultiple, .count(3)) == "Copy 3 Items")
        #expect(en.text(.searchBarCount, .count(1)) == "1 item")
        #expect(en.text(.searchBarCount, .count(0)) == "0 items")
        #expect(en.text(.searchBarCount, .count(1000)) == "1,000 items")
        #expect(en.text(.searchBarCountLimited, .count(1000), .text("2")) == "Showing 2 of 1,000 items")
        #expect(en.text(.searchBarCountLimited, .count(1), .text("1")) == "Showing 1 of 1 item")
        #expect(en.text(.dialogConfirmCopy, .count(1)) == "Copy this item?")
        #expect(en.text(.dialogConfirmCopy, .count(3)) == "Copy these items?")
        #expect(en.text(.dialogConfirmMove, .count(1)) == "Move this item?")
        #expect(en.text(.dialogConfirmMove, .count(3)) == "Move these items?")
    }

    @Test("日本語の件数の文")
    func japaneseForms() {
        #expect(ja.text(.contextCopyMultiple, .count(3)) == "3 項目をコピー")
        #expect(ja.text(.searchBarCount, .count(1000)) == "1,000 件")
        #expect(ja.text(.searchBarCountLimited, .count(1000), .text("2")) == "1,000 件中 2 件を表示")
        #expect(ja.text(.dialogConfirmCopy, .count(1)) == "コピーしますか？")
        #expect(ja.text(.dialogConfirmCopy, .count(3)) == "コピーしますか？")
        #expect(ja.text(.dialogConfirmMove, .count(3)) == "移動しますか？")
    }

    @Test("語形が変わらない件数は整形済みの値を入れる")
    func numberArguments() {
        let keys: [TextKey] = [
            .dialogConfirmItems, .dialogConfirmMore, .dialogConflictItems, .dialogOperationMore,
        ]
        for key in keys {
            for count in [0, 1, 2, 1000] {
                let value = LocalizationTestSupport.localizer("en").text(key, .number(count))
                #expect(!value.contains("%"), "\(key.rawValue)")
                #expect(value.contains(LocalizationTestSupport.localizer("en", localeIdentifier: "en_US").count(count)))
            }
        }
        #expect(en.text(.dialogOperationSummary, .number(3), .number(1000))
            == "Succeeded: 3 / Failed: 1,000")
        #expect(ja.text(.dialogOperationSummary, .number(3), .number(1000))
            == "成功 3 件 / 失敗 1,000 件")
        #expect(en.text(.dialogConfirmMore, .number(1000)) == "and 1,000 more")
        #expect(ja.text(.dialogConfirmMore, .number(1000)) == "ほか 1,000 件")
    }
}
