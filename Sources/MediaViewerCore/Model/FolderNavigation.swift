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

    /// ツリーでフォルダをゴミ箱に入れたあとに表示するフォルダ（FR-079、research.md R33）。
    /// `showing`（表示中のフォルダ。zip の中なら zip を含むフォルダ）が `trashed` のどれか自身かその配下なら、
    /// 該当するもののうち最も浅いフォルダの `enclosingFolder` を返す。どれとも祖先・子孫の関係にない、
    /// 該当するフォルダがルート、`trashed` が空のときは nil。
    /// 比較は `standardizedFileURL` のパスの要素で行う（`/a/b2` を `/a/b` の配下と誤らない）
    public static func folderToShow(afterTrashing trashed: [URL], showing: URL, roots: [URL]) -> URL? {
        let showingComponents = showing.standardizedFileURL.pathComponents

        var shallowest: URL?
        var shallowestCount = Int.max
        for url in trashed {
            let standardized = url.standardizedFileURL
            let components = standardized.pathComponents
            guard showingComponents.starts(with: components),
                  components.count < shallowestCount else { continue }
            shallowest = standardized
            shallowestCount = components.count
        }

        guard let shallowest else { return nil }
        return enclosingFolder(of: shallowest, roots: roots)
    }
}
