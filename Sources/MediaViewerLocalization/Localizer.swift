import Foundation
import MediaViewerCore

/// 翻訳単位に入れる値
public enum TextValue: Sendable, Equatable {
    case text(String)
    case count(Int)
    case number(Int)
}

/// 文言と書式の窓口（data-model.md）。起動時に1つ作り、起動中は変えない
public struct Localizer: @unchecked Sendable {
    public let language: String
    public let locale: Locale
    private let numericLocale: Locale

    private let table: Bundle
    private let fallbackTable: Bundle
    private let formatters = FormatterCache()

    /// 保存した表示言語から文言と書式を準備する。
    public static func forLanguage(_ language: String, currentLocale: Locale = .current) -> Localizer {
        let bundle = LocalizationBundle.resolve()
        let resolved = DisplayLanguage.resolve(
            saved: language,
            supported: bundle.localizations.filter { $0 != "Base" },
            development: "en"
        )
        return Localizer(
            bundle: bundle,
            language: resolved,
            development: bundle.developmentLocalization ?? "en",
            locale: FormattingLocale.resolve(current: currentLocale, displayLanguage: resolved),
            numericLocale: FormattingLocale.numeric(current: currentLocale)
        )
    }

    /// テスト用にバンドル・表示言語・開発言語・書式のロケールを明示して作る
    public init(bundle: Bundle, language: String, development: String, locale: Locale, numericLocale: Locale? = nil) {
        self.language = language
        self.locale = locale
        self.numericLocale = numericLocale ?? locale
        self.table = LocalizationBundle.table(language: language, in: bundle) ?? bundle
        self.fallbackTable = LocalizationBundle.table(language: development, in: bundle) ?? bundle
    }

    // MARK: - 文言

    public func text(_ key: TextKey) -> String {
        text(key, [])
    }

    public func text(_ key: TextKey, _ value: TextValue) -> String {
        text(key, [value])
    }

    public func text(_ key: TextKey, _ first: TextValue, _ second: TextValue) -> String {
        text(key, [first, second])
    }

    public func text(_ key: TextKey, _ first: TextValue, _ second: TextValue, _ third: TextValue) -> String {
        text(key, [first, second, third])
    }

    /// 翻訳単位を引き、引数を位置指定の書式で入れる。表示言語に無ければ開発言語（英語）の訳を使う（EC-110）
    public func text(_ key: TextKey, _ values: [TextValue]) -> String {
        assert(argumentKindsMatch(values, key.arguments), "引数が TextKey.\(key) と一致しません")
        let format = formatString(for: key)
        guard format != Self.missing else { return format }

        var arguments: [CVarArg] = []
        for value in values {
            switch value {
            case let .text(string):
                arguments.append(string)
            case let .count(value):
                arguments.append(Int64(value))
                arguments.append(self.count(value))
            case let .number(value):
                arguments.append(self.count(value))
            }
        }
        return String(format: format, locale: locale, arguments: arguments)
    }

    // MARK: - 書式

    public func count(_ value: Int) -> String {
        FormattingLocale.count(value, locale: numericLocale)
    }

    public func percent(_ percentage: Int) -> String {
        FormattingLocale.percent(percentage, locale: numericLocale)
    }

    public func dateTime(_ date: Date?) -> String {
        formatters.dateTime(date, locale: locale)
    }

    /// 複数のラベルを、地域の区切りで並べる（アクセシビリティのラベル用）
    public func list(_ items: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: items) ?? items.joined(separator: ", ")
    }

    /// Core へ渡す種類名
    public var kindNames: KindNames {
        KindNames(folder: text(.kindFolder), zipArchive: text(.kindZipArchive))
    }

    // MARK: - 内部

    private static let missing = "\u{2026}"

    private func formatString(for key: TextKey) -> String {
        let localized = table.localizedString(forKey: key.rawValue, value: nil, table: nil)
        if localized != key.rawValue { return localized }
        let fallback = fallbackTable.localizedString(forKey: key.rawValue, value: nil, table: nil)
        if fallback != key.rawValue { return fallback }
        return Self.missing
    }

    private func argumentKindsMatch(_ values: [TextValue], _ expected: [TextArgument]) -> Bool {
        guard values.count == expected.count else { return false }
        for (value, expected) in zip(values, expected) {
            switch (value, expected) {
            case (.text, .text), (.count, .count), (.number, .number):
                continue
            default:
                return false
            }
        }
        return true
    }
}

/// `DateFormatter` を使い回す。呼び出しは `NSLock` で直列化する
private final class FormatterCache: @unchecked Sendable {
    private let lock = NSLock()
    private var formatters: [String: DateFormatter] = [:]

    func dateTime(_ date: Date?, locale: Locale) -> String {
        guard let date else { return "--" }
        lock.lock()
        defer { lock.unlock() }
        let key = locale.identifier
        let formatter: DateFormatter
        if let cached = formatters[key] {
            formatter = cached
        } else {
            let created = DateFormatter()
            created.dateStyle = .medium
            created.timeStyle = .short
            created.locale = locale
            formatters[key] = created
            formatter = created
        }
        return formatter.string(from: date)
    }
}
