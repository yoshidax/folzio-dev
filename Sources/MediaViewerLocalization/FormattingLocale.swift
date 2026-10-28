import Foundation

/// 日時・件数・割合の書式のロケールを決める（FR-151、research.md R7）。
/// 表示言語と地域を分け、並び・区切り・12／24時間表示は地域に、語は表示言語に従わせる
public enum FormattingLocale {
    /// 数値の記号や割合の配置は表示言語でなく地域の既定を使う。
    public static func numeric(current: Locale) -> Locale {
        guard let region = current.region?.identifier else { return current }
        let regionalLanguage = Locale.Language(identifier: "und_\(region)").maximalIdentifier
        guard let languageCode = Locale.Language(identifier: regionalLanguage).languageCode else { return current }
        var components = Locale.Components(locale: current)
        components.languageComponents.languageCode = languageCode
        if components.numberingSystem == nil {
            components.numberingSystem = current.numberingSystem
        }
        return Locale(components: components)
    }

    public static func resolve(current: Locale, displayLanguage: String) -> Locale {
        let currentLanguage = current.language.languageCode?.identifier
        if currentLanguage == displayLanguage {
            return current
        }

        var components = Locale.Components(locale: current)
        components.languageComponents.languageCode = Locale.LanguageCode(displayLanguage)
        components.hourCycle = current.hourCycle
        components.firstDayOfWeek = current.firstDayOfWeek
        if components.calendar == nil {
            components.calendar = current.calendar.identifier
        }
        if components.numberingSystem == nil {
            components.numberingSystem = current.numberingSystem
        }
        return Locale(components: components)
    }

    /// 桁区切りは地域に従う
    public static func count(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    /// 割合の記号の位置と間の空白は地域に従う
    public static func percent(_ percentage: Int, locale: Locale) -> String {
        (Double(percentage) / 100).formatted(.percent.locale(locale))
    }
}
