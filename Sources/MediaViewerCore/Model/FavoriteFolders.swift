import Foundation

/// ツリー最上部の「お気に入り」に並べるフォルダ。登録順で、同じ場所を重複して持たない（FR-061〜067）
public struct FavoriteFolders: Sendable, Equatable {
    public private(set) var urls: [URL]

    /// 重複は先勝ちで除き、順序を保つ
    public init(urls: [URL] = []) {
        var seen = Set<String>()
        self.urls = urls.filter { seen.insert(Self.key($0)).inserted }
    }

    public func contains(_ url: URL) -> Bool {
        let key = Self.key(url)
        return urls.contains { Self.key($0) == key }
    }

    /// 未登録なら末尾に追加して true。登録済みなら変更せず false（FR-062）
    @discardableResult
    public mutating func add(_ url: URL) -> Bool {
        guard !contains(url) else { return false }
        urls.append(url)
        return true
    }

    /// 登録だけを取り除く。実際のフォルダには触れない（FR-064）
    @discardableResult
    public mutating func remove(_ url: URL) -> Bool {
        let key = Self.key(url)
        guard let index = urls.firstIndex(where: { Self.key($0) == key }) else { return false }
        urls.remove(at: index)
        return true
    }

    /// 同一性のキー。URL 同士の == は末尾の `/` の有無で一致しないため使わない
    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}

/// お気に入りの項目が登録時の場所にフォルダとしてあるか。保存しない（FR-067）
public enum FavoriteAvailability: Sendable, Equatable {
    case unknown, available, missing
}
