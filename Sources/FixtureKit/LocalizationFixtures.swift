import Foundation
import MediaViewerCore

extension FixtureKit {
    /// Core へ注入する種類名の固定値。テストは日本語の文字列ではなくこれと比べる
    public static let kindNames = KindNames(folder: "Folder", zipArchive: "ZIP archive")
}

/// 翻訳の検証用に、一時ディレクトリへ言語別の lproj を持つバンドルを作る
public enum LocalizationFixtures {
    /// `tables` の言語ごとに `Localizable.strings` を書いたバンドルを作る。`plural` は `Localizable.stringsdict` に書く
    public static func makeBundle(
        tables: [String: [String: String]],
        plural: [String: [String: [String: String]]] = [:]
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaViewerLocalizationFixture-\(UUID().uuidString).bundle", isDirectory: true)
        let resources = root.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        for (language, strings) in tables {
            let lproj = resources.appendingPathComponent("\(language).lproj", isDirectory: true)
            try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
            let body = strings
                .sorted { $0.key < $1.key }
                .map { "\"\($0.key)\" = \"\(escape($0.value))\";" }
                .joined(separator: "\n")
            try (body + "\n").write(
                to: lproj.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )
            if let entries = plural[language] {
                try writeStringsdict(entries, to: lproj.appendingPathComponent("Localizable.stringsdict"))
            }
        }
        return root
    }

    public static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func writeStringsdict(
        _ entries: [String: [String: String]],
        to url: URL
    ) throws {
        var body = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>

        """
        for (key, forms) in entries.sorted(by: { $0.key < $1.key }) {
            body += "  <key>\(key)</key>\n  <dict>\n"
            body += "    <key>NSStringLocalizedFormatKey</key>\n    <string>%#@value@</string>\n"
            body += "    <key>value</key>\n    <dict>\n"
            body += "      <key>NSStringFormatSpecTypeKey</key>\n      <string>NSStringPluralRuleType</string>\n"
            body += "      <key>NSStringFormatValueTypeKey</key>\n      <string>lld</string>\n"
            for (form, value) in forms.sorted(by: { $0.key < $1.key }) {
                body += "      <key>\(form)</key>\n      <string>\(xmlEscape(value))</string>\n"
            }
            body += "    </dict>\n  </dict>\n"
        }
        body += "</dict>\n</plist>\n"
        try body.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func xmlEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
