import Foundation

/// zip の中の項目の URL（`mvzip:///<項目のパス>?archive=<zip の絶対パス>`）。生成と解析はここだけで行う
public enum ArchiveURL {
    public static let scheme = "mvzip"

    private static let archiveQueryName = "archive"
    private static let parentFragment = "parent"

    /// パスの要素に使える文字。`.urlPathAllowed` から `#`・`?`・`%`・`;` を除く
    private static let pathElementAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "#?%;/")
        return set
    }()

    /// クエリの値に使える文字。区切りになりうる記号は残さない
    private static let queryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~/")
        return set
    }()

    /// 項目の URL。ディレクトリはパスの末尾を `/` にする。最上位は空のパス
    public static func entry(archive: URL, path: String) -> URL {
        makeURL(archive: archive, path: path, fragment: nil)
    }

    /// `...` の行の URL。表示中の階層の URL に `#parent` を付けたもの
    public static func parentLink(of location: ArchiveLocation) -> URL {
        makeURL(archive: location.archive, path: location.directory, fragment: parentFragment)
    }

    /// `mvzip` 以外のスキーム、または zip の指定がない URL では nil
    public static func parse(_ url: URL) -> (archive: URL, path: String, isParentLink: Bool)? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let item = components.percentEncodedQueryItems?.first(where: { $0.name == archiveQueryName }),
              let encodedArchive = item.value,
              let archivePath = encodedArchive.removingPercentEncoding,
              !archivePath.isEmpty,
              let decodedPath = components.percentEncodedPath.removingPercentEncoding
        else { return nil }

        let path = decodedPath.hasPrefix("/") ? String(decodedPath.dropFirst()) : decodedPath
        return (
            archive: URL(fileURLWithPath: archivePath),
            path: path,
            isParentLink: components.fragment == parentFragment
        )
    }

    private static func makeURL(archive: URL, path: String, fragment: String?) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.percentEncodedHost = ""
        components.percentEncodedPath = "/" + encodePath(path)
        let archiveValue = archive.path.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) ?? ""
        components.percentEncodedQueryItems = [URLQueryItem(name: archiveQueryName, value: archiveValue)]
        components.fragment = fragment
        return components.url ?? URL(fileURLWithPath: "/")
    }

    private static func encodePath(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: pathElementAllowed) ?? "" }
            .joined(separator: "/")
    }
}
