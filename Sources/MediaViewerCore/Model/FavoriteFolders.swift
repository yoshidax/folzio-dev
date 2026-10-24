import Foundation

/// ツリー最上部の「お気に入り」に並べるフォルダ。登録順で、同じ場所を重複して持たない（FR-061〜067）
public struct FavoriteFolders: Sendable, Equatable {
    public private(set) var urls: [URL]

    /// ユーザーが付けた表示名。キーは `key(_:)`（`standardizedFileURL.path`）。表示名を付けていない登録は載せない（R48）
    /// 不変条件:
    /// - キーは、すべて `urls` に登録されている場所のキー
    /// - 値は `FavoriteName.normalized(_:)` を通した値で、1〜255 文字・改行なし・前後に空白なし
    private var customNames: [String: String]

    /// 重複は先勝ちで除き、順序を保つ。
    /// `customNames` はキーを `key(_:)` に揃え、未登録のキーと、正規化して空になる値を捨てる（R48、R49）
    public init(urls: [URL] = [], customNames: [String: String] = [:]) {
        var seen = Set<String>()
        self.urls = urls.filter { seen.insert(Self.key($0)).inserted }

        var names: [String: String] = [:]
        for (path, name) in customNames {
            let key = Self.key(URL(fileURLWithPath: path))
            guard seen.contains(key), let normalized = FavoriteName.normalized(name) else { continue }
            names[key] = normalized
        }
        self.customNames = names
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

    /// 登録だけを取り除く。実際のフォルダには触れない（FR-064）。表示名も一緒に破棄する（EC-44）
    @discardableResult
    public mutating func remove(_ url: URL) -> Bool {
        let key = Self.key(url)
        guard let index = urls.firstIndex(where: { Self.key($0) == key }) else { return false }
        urls.remove(at: index)
        customNames.removeValue(forKey: key)
        return true
    }

    /// 付けた表示名。未登録・表示名なしは nil（FR-101）
    public func customName(for url: URL) -> String? {
        customNames[Self.key(url)]
    }

    /// 表示名があればそれ、なければ `defaultName`（FR-101）
    public func displayName(for url: URL, defaultName: String) -> String {
        customName(for: url) ?? defaultName
    }

    /// 編集で確定した入力を反映する（FR-099、R50）。未登録の場所なら false。
    /// 正規化した結果が現在の表示名と同じなら何もせず false（表示名なしの項目で `defaultName` と同じ名前を
    /// 確定しても表示名は付かない）。nil なら表示名を解除、それ以外は表示名にして true。
    /// 表示名ありの項目では `defaultName` と同じ名前も表示名として残す（EC-41）
    @discardableResult
    public mutating func commitDisplayName(_ input: String, for url: URL, defaultName: String) -> Bool {
        let key = Self.key(url)
        guard contains(url) else { return false }
        let normalized = FavoriteName.normalized(input)
        let current = displayName(for: url, defaultName: defaultName)
        if normalized == current { return false }
        if let normalized {
            customNames[key] = normalized
        } else {
            // 空で確定。解除する表示名がなければ変化なし
            guard customNames.removeValue(forKey: key) != nil else { return false }
        }
        return true
    }

    /// 保存用。標準化した絶対パス → 表示名（R49）
    public var customNamesByPath: [String: String] { customNames }

    /// 同一性のキー。URL 同士の == は末尾の `/` の有無で一致しないため使わない
    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}

/// お気に入りの項目が登録時の場所にフォルダとしてあるか。保存しない（FR-067）
public enum FavoriteAvailability: Sendable, Equatable {
    case unknown, available, missing
}
