import Foundation

/// 通常のフォルダの `..` の行の URL（`mvparent:///<フォルダの絶対パス>`）。生成と判定はここだけで行う。
/// `FileManager`・`NSWorkspace`・ペーストボードに渡さない（research.md R30）
public enum ParentLink {
    public static let scheme = "mvparent"

    /// パスの要素に使える文字。`.urlPathAllowed` から `#`・`?`・`%`・`;` を除く（`ArchiveURL` と同じ）
    private static let pathElementAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "#?%;/")
        return set
    }()

    /// 同じフォルダ（末尾の `/` や `.` の違いを含む）には同じ URL を返す
    public static func url(for folder: URL) -> URL {
        let path = folder.standardizedFileURL.path
        var components = URLComponents()
        components.scheme = scheme
        components.percentEncodedHost = ""
        components.percentEncodedPath = path.split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: pathElementAllowed) ?? "" }
            .joined(separator: "/")
        return components.url ?? URL(fileURLWithPath: "/")
    }

    public static func isParentLink(_ url: URL) -> Bool {
        url.scheme == scheme
    }
}
