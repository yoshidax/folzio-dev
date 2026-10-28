import Foundation

/// 保存された値を対応言語に照合し、未設定・未知の値には開発言語を使う。
public enum DisplayLanguage {
    public static func resolve(saved: String?, supported: [String], development: String = "en") -> String {
        guard let saved, supported.contains(saved) else { return development }
        return saved
    }
}
