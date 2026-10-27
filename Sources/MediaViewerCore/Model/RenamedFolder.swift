import Foundation

/// 名前を変えたフォルダの元の場所と新しい場所。配下を指す URL を新しい場所の URL に付け替える（research.md R61）
public struct RenamedFolder: Sendable, Equatable {
    public let from: URL
    public let to: URL
    /// 比べるたびに標準化しないよう、パスを先に作っておく（10,000 件の付け替え。R67）。`standardizedFileURL` は
    /// 場所が存在するかで `/private` を外すかが変わり、元の場所（もうない）と新しい場所で表記がずれるため使わない
    private let fromBytes: [UInt8]
    private let toPath: String

    public init(from: URL, to: URL) {
        self.from = from
        self.to = to
        self.fromBytes = Array(Self.normalized(from.path).utf8)
        self.toPath = Self.normalized(to.path)
    }

    /// `from` 自身か配下を指す URL（`file`・zip の中の項目）を新しい場所の URL にする。関係がなければ nil。
    /// 通常のフォルダの `..`（`mvparent`）は表示中のフォルダから作り直すため付け替えない
    public func rebase(_ url: URL) -> URL? {
        if url.isFileURL {
            return rebaseFileURL(url)
        }
        guard let parsed = ArchiveURL.parse(url),
              let archive = rebaseFileURL(parsed.archive) else {
            return nil
        }
        if parsed.isParentLink {
            return ArchiveURL.parentLink(of: ArchiveLocation(archive: archive, directory: parsed.path))
        }
        return ArchiveURL.entry(archive: archive, path: parsed.path)
    }

    public func rebaseOrSelf(_ url: URL) -> URL {
        rebase(url) ?? url
    }

    /// 逆向きの付け替え（新しい場所から元の場所へ）。検索の記録を、名前の変更の前の時点の場所に戻すのに使う（R2）
    public var reversed: RenamedFolder {
        RenamedFolder(from: to, to: from)
    }

    /// 区切りの `/` まで比べ、名前の前方が同じ兄弟（`Photo` と `Photos`）を取り違えない。
    /// 区切りは ASCII の `/` のため、UTF-8 のバイトで比べても文字の途中で切れない（10,000 件の付け替え。R67）
    private func rebaseFileURL(_ url: URL) -> URL? {
        // URL.path はブリッジされた文字列で UTF-8 の連続した記憶域を持たないことがあるため、先に連続にする
        var path = Self.normalized(url.path)
        path.makeContiguousUTF8()
        let rest = path.withUTF8 { bytes in
            fromBytes.withUnsafeBufferPointer { prefix in
                Self.remainder(of: bytes, after: prefix)
            }
        }
        guard let remainder = rest else { return nil }
        let newPath = remainder.isEmpty ? toPath : (toPath == "/" ? "" : toPath) + "/" + remainder
        return URL(fileURLWithPath: newPath, isDirectory: url.hasDirectoryPath)
    }

    /// `path` が `prefix` 自身なら空、配下なら区切りの後の残り、どちらでもなければ nil
    private static func remainder(of path: UnsafeBufferPointer<UInt8>, after prefix: UnsafeBufferPointer<UInt8>) -> String? {
        guard let pathBase = path.baseAddress, let prefixBase = prefix.baseAddress,
              path.count >= prefix.count,
              memcmp(pathBase, prefixBase, prefix.count) == 0 else { return nil }
        if path.count == prefix.count { return "" }
        let isRoot = prefix.count == 1 && prefixBase.pointee == UInt8(ascii: "/")
        let start = isRoot ? prefix.count : prefix.count + 1
        guard isRoot || pathBase[prefix.count] == UInt8(ascii: "/") else { return nil }
        return String(decoding: UnsafeBufferPointer(rebasing: path[start...]), as: UTF8.self)
    }

    /// `.`・`..` の要素を取り除く。含まないパス（ほとんどの場合）はそのまま返す
    private static func normalized(_ path: String) -> String {
        var contiguous = path
        contiguous.makeContiguousUTF8()
        let hasDotComponent = contiguous.withUTF8 { bytes -> Bool in
            guard let base = bytes.baseAddress else { return false }
            return memmem(base, bytes.count, "/.", 2) != nil
        }
        guard hasDotComponent else { return contiguous }
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
}
