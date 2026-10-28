import Foundation
import MediaViewerLocalization
import Testing

@Suite("表示言語の決定")
struct DisplayLanguageTests {
    @Test("未保存または未知の言語は英語")
    func missingOrUnknownUsesEnglish() {
        for value in [nil, "", "fr", "ja-JP", "en-GB"] as [String?] {
            #expect(DisplayLanguage.resolve(saved: value, supported: ["ja", "en"]) == "en")
        }
    }

    @Test("保存された対応言語を使う")
    func supportedSettingIsRestored() {
        #expect(DisplayLanguage.resolve(saved: "ja", supported: ["ja", "en"]) == "ja")
        #expect(DisplayLanguage.resolve(saved: "en", supported: ["ja", "en"]) == "en")
    }

    @Test("切り替えたローカライザーは選択された言語の文言を返す")
    func selectedLocalizerUsesSelectedLanguage() {
        let japanese = Localizer.forLanguage("ja", currentLocale: Locale(identifier: "en_US"))
        let english = Localizer.forLanguage("en", currentLocale: Locale(identifier: "en_US"))
        #expect(japanese.text(.kindFolder) == "フォルダ")
        #expect(english.text(.kindFolder) == "Folder")
        #expect(japanese.language == "ja")
        #expect(english.language == "en")
    }
}
