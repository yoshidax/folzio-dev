import Foundation

/// 通常のフォルダの1つ上の階層を、ツリーのルートの一覧から決める純粋計算（FR-077、research.md R30）
public enum FolderNavigation {
    /// `folder` がルートと同じ、またはどのルートにも含まれなければ nil。
    /// 含むルートのうち最も深いもの（ホームと起動ボリュームの両方に含まれるときはホーム）の中での親を返す。
    /// 比較は `standardizedFileURL` のパスの要素で行う（`/Users/me2` を `/Users/me` の配下と誤らない）
    public static func enclosingFolder(of folder: URL, roots: [URL]) -> URL? {
        let target = folder.standardizedFileURL
        let components = target.pathComponents

        var deepest: [String]?
        for root in roots {
            let rootComponents = root.standardizedFileURL.pathComponents
            if rootComponents == components {
                return nil
            }
            guard components.count > rootComponents.count,
                  components.starts(with: rootComponents) else { continue }
            if rootComponents.count > (deepest?.count ?? -1) {
                deepest = rootComponents
            }
        }

        guard deepest != nil else { return nil }
        return target.deletingLastPathComponent()
    }
}
