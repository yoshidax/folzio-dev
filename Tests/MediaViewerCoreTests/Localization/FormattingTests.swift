import Foundation
import MediaViewerLocalization
import Testing

@Suite("地域の書式")
struct FormattingTests {
    @Test("表示言語を切り替えても地域の数値と時刻の設定を保つ")
    func languageChangeKeepsRegionalFormatting() {
        for current in [Locale(identifier: "de_DE"), Locale(identifier: "ja_DE")] {
            let english = Localizer.forLanguage("en", currentLocale: current)
            let japanese = Localizer.forLanguage("ja", currentLocale: current)
            for localizer in [english, japanese] {
                #expect(localizer.locale.region?.identifier == "DE")
                #expect(localizer.locale.hourCycle == current.hourCycle)
                #expect(localizer.locale.firstDayOfWeek == current.firstDayOfWeek)
                #expect(localizer.count(1234) == "1.234")
                #expect(localizer.percent(125).replacingOccurrences(of: "\u{00a0}", with: " ") == "125 %")
                #expect(localizer.dateTime(nil) == "--")
            }
            #expect(english.locale.language.languageCode?.identifier == "en")
            #expect(japanese.locale.language.languageCode?.identifier == "ja")
        }
    }

    @Test("表示言語が同じなら現在のロケールをそのまま使う")
    func keepsCurrentLocale() {
        let current = Locale(identifier: "en_JP")
        #expect(FormattingLocale.resolve(current: current, displayLanguage: "en") == current)
        let withKeyword = Locale(identifier: "ja_US@hours=h23")
        #expect(FormattingLocale.resolve(current: withKeyword, displayLanguage: "ja") == withKeyword)
    }

    @Test("言語だけを置き換え、地域・24時間表示・暦・数字の体系を引き継ぐ")
    func replacesOnlyLanguage() {
        let japan = Locale(identifier: "ja_JP")
        let englishInJapan = FormattingLocale.resolve(current: japan, displayLanguage: "en")
        #expect(englishInJapan.language.languageCode?.identifier == "en")
        #expect(englishInJapan.region?.identifier == "JP")
        #expect(englishInJapan.hourCycle == japan.hourCycle)
        #expect(englishInJapan.calendar.identifier == japan.calendar.identifier)
        #expect(englishInJapan.numberingSystem == japan.numberingSystem)

        let unitedStates = Locale(identifier: "en_US")
        let japaneseInUS = FormattingLocale.resolve(current: unitedStates, displayLanguage: "ja")
        #expect(japaneseInUS.language.languageCode?.identifier == "ja")
        #expect(japaneseInUS.region?.identifier == "US")
        #expect(japaneseInUS.hourCycle == unitedStates.hourCycle)

        let france = Locale(identifier: "fr_FR")
        let japaneseInFrance = FormattingLocale.resolve(current: france, displayLanguage: "ja")
        #expect(japaneseInFrance.region?.identifier == "FR")
        #expect(japaneseInFrance.hourCycle == france.hourCycle)

        let forced24 = Locale(identifier: "ja_US@hours=h23")
        let japaneseForced24 = FormattingLocale.resolve(current: forced24, displayLanguage: "ja")
        #expect(japaneseForced24 == forced24)
    }

    @Test("件数は地域の桁区切りで整形する")
    func counts() {
        #expect(FormattingLocale.count(1234, locale: Locale(identifier: "en_US")) == "1,234")
        #expect(FormattingLocale.count(1234, locale: Locale(identifier: "ja_JP")) == "1,234")
        #expect(FormattingLocale.count(1234, locale: Locale(identifier: "de_DE")) == "1.234")
    }

    @Test("日時は地域の並びと12／24時間表示、語は表示言語に従う")
    func dateTime() throws {
        let date = try #require(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 2026, month: 10, day: 28, hour: 15, minute: 4)
            )
        )

        let englishInJapan = Localizer(
            bundle: LocalizationTestSupport.packageBundle,
            language: "en",
            development: "en",
            locale: FormattingLocale.resolve(current: Locale(identifier: "ja_JP"), displayLanguage: "en")
        )
        #expect(englishInJapan.locale.hourCycle == .zeroToTwentyThree)
        let japaneseOrder = englishInJapan.dateTime(date)
        #expect(japaneseOrder.contains("15:04") || japaneseOrder.contains("15:4"))
        #expect(!japaneseOrder.contains("AM"))
        #expect(!japaneseOrder.contains("PM"))
        #expect(!japaneseOrder.contains("午前"))
        #expect(!japaneseOrder.contains("午後"))
        #expect(englishInJapan.dateTime(nil) == "--")

        let japaneseInUS = Localizer(
            bundle: LocalizationTestSupport.packageBundle,
            language: "ja",
            development: "en",
            locale: FormattingLocale.resolve(current: Locale(identifier: "en_US"), displayLanguage: "ja")
        )
        #expect(japaneseInUS.locale.hourCycle == .oneToTwelve)
        let usOrder = japaneseInUS.dateTime(date)
        #expect(usOrder.contains("午後"))
        #expect(usOrder.contains("/"))

        let englishInGermany = Localizer(
            bundle: LocalizationTestSupport.packageBundle,
            language: "en",
            development: "en",
            locale: FormattingLocale.resolve(current: Locale(identifier: "de_DE"), displayLanguage: "en")
        )
        let germanOrder = englishInGermany.dateTime(date)
        #expect(germanOrder.contains("Oct"))
        #expect(!germanOrder.contains("Okt"))
        #expect(germanOrder.contains("15:04") || germanOrder.contains("15:4"))

        let forced24 = Localizer(
            bundle: LocalizationTestSupport.packageBundle,
            language: "ja",
            development: "en",
            locale: FormattingLocale.resolve(
                current: Locale(identifier: "ja_US@hours=h23"),
                displayLanguage: "ja"
            )
        )
        #expect(forced24.locale.hourCycle == .zeroToTwentyThree)
    }

    @Test("倍率は地域の割合の書式で整形する")
    func percentages() {
        #expect(FormattingLocale.percent(125, locale: Locale(identifier: "en_US")) == "125%")
        #expect(FormattingLocale.percent(125, locale: Locale(identifier: "ja_JP")) == "125%")
        let german = FormattingLocale.percent(125, locale: Locale(identifier: "de_DE"))
        #expect(german.replacingOccurrences(of: "\u{00a0}", with: " ") == "125 %")
    }
}
