import Foundation

/// 翻訳の参照先のバンドルを決める（research.md R3）。
/// `.app` では本体の `Contents/Resources` の lproj を、`swift run` とテストではパッケージのリソースバンドルを使う
public enum LocalizationBundle {
    /// `.app`（本体に en.lproj の表がある）なら本体、なければパッケージのバンドル
    public static func resolve(main: Bundle = .main) -> Bundle {
        if containsTable(language: "en", in: main) {
            return main
        }
        return packageBundle
    }

    /// テストと `swift run` 用のパッケージのリソースバンドル
    public static var packageBundle: Bundle { Bundle.module }

    /// `bundle` の中の言語別の lproj。表がなければ nil
    public static func table(language: String, in bundle: Bundle) -> Bundle? {
        guard let url = bundle.url(forResource: language, withExtension: "lproj"),
              containsTable(language: language, in: bundle) else {
            return nil
        }
        return Bundle(url: url)
    }

    private static func containsTable(language: String, in bundle: Bundle) -> Bool {
        guard let url = bundle.url(forResource: language, withExtension: "lproj") else { return false }
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Localizable.strings").path
        ) || FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Localizable.stringsdict").path
        )
    }
}
