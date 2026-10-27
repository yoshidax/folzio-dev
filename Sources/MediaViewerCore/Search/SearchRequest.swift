import Foundation

/// 名前の検索の要求（FR-083・105、research.md R2・R3）
public struct SearchRequest: Sendable {
    /// 列挙を始めるフォルダ
    public var root: URL
    /// キーワード
    public var pattern: SearchPattern
    /// `root` そのものもフォルダとして照合するか。検索の開始・起点か祖先の名前の変更では false。
    /// 未照合のフォルダの名前を変えたときの追加の列挙だけ true（R3）
    public var matchesRoot: Bool
    /// 列挙がディレクトリを照合する直前に記録する先
    public var visits: SearchVisitLog

    public init(
        root: URL,
        pattern: SearchPattern,
        matchesRoot: Bool = false,
        visits: SearchVisitLog = SearchVisitLog()
    ) {
        self.root = root
        self.pattern = pattern
        self.matchesRoot = matchesRoot
        self.visits = visits
    }
}

/// 検索の記録と照合で使うパスの正規化（EC-94）
public enum SearchPath {
    /// `/` で終わる形を外し、`.`・`..` の要素を取り除く。`standardizedFileURL` は macOS で `/private` を外して
    /// `/var/...` にするため使わず、呼び出し元が渡した URL の形を保つ（履歴・監視・一覧の URL と同じ形で比べる）
    public static func normalized(_ url: URL) -> String {
        var path = url.path
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        guard path.contains("/.") else { return path }
        var parts: [Substring] = []
        for component in path.split(separator: "/") {
            switch component {
            case ".":
                continue
            case "..":
                if !parts.isEmpty { parts.removeLast() }
            default:
                parts.append(component)
            }
        }
        return "/" + parts.joined(separator: "/")
    }

    /// `path` が `base` 自身か配下か（区切りの `/` まで比べる）
    public static func isSameOrWithin(_ path: String, _ base: String) -> Bool {
        let target = normalized(URL(fileURLWithPath: path))
        let root = normalized(URL(fileURLWithPath: base))
        if target == root { return true }
        if root == "/" { return true }
        return target.hasPrefix(root + "/")
    }
}

/// 検索の列挙が照合したディレクトリの記録（EC-94、research.md R2）。
///
/// 列挙は別スレッドで進むため、列挙から `record`、メインアクターから `contains` を呼べるようにロックで保護する。
/// 記録するのはディレクトリだけ（起点の形に組み直した標準化したパス）で、ファイルは記録しない。
/// 記録は今の検索の間だけ持ち、検索を止めたら捨てる
public final class SearchVisitLog: @unchecked Sendable {
    private let lock = NSLock()
    private var paths: Set<String> = []

    public init() {}

    /// 照合する直前に、ディレクトリの標準化したパスを記録する。列挙のスレッドから呼ぶ
    public func record(_ path: String) {
        _ = lock.withLock { paths.insert(path) }
    }

    /// 記録があるか。メインアクターから呼ぶ
    public func contains(_ path: String) -> Bool {
        lock.withLock { paths.contains(path) }
    }
}
