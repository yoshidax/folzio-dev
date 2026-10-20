import Foundation
import UniformTypeIdentifiers

/// zip ファイルの同一性（開いたときの値。FSEvents の後に比べて、zip が変わったかを判定する）
public struct ArchiveIdentity: Sendable, Hashable {
    public var fileSize: UInt64
    public var modificationDate: Date
    public var inode: UInt64

    public init(fileSize: UInt64, modificationDate: Date, inode: UInt64) {
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.inode = inode
    }
}

/// zip の中の項目（ディレクトリを含む）。data-model.md の ArchiveEntry
public struct ArchiveEntry: Sendable, Equatable {
    public enum Readability: Sendable, Equatable {
        case readable
        case encrypted
        case unsupportedMethod
    }

    /// FR-074 で判定した名前による、zip の中のパス。ディレクトリは末尾が `/`
    public var path: String
    /// パスの最後の要素
    public var name: String
    public var isDirectory: Bool
    /// 格納方式（0 = 無圧縮、8 = deflate、それ以外は非対応）
    public var method: UInt16
    /// 汎用フラグのビット 0
    public var isEncrypted: Bool
    public var compressedSize: UInt64
    public var uncompressedSize: UInt64
    /// ローカルヘッダの位置。データの開始位置は初めて読むときに求める
    public var localHeaderOffset: UInt64
    public var modificationDate: Date?

    public var readability: Readability {
        if isEncrypted { return .encrypted }
        if method != 0 && method != 8 { return .unsupportedMethod }
        return .readable
    }
}

/// 開いている zip の索引（中央ディレクトリを1回読んで作る。research.md R22・R23）
public struct ArchiveIndex: Sendable {
    public let archive: URL
    public let identity: ArchiveIdentity
    /// 項目のパス → 項目（途中のディレクトリを補ったものを含む）
    public private(set) var entries: [String: ArchiveEntry]
    /// ディレクトリのパス（最上位は ""）→ 直下の項目とディレクトリのパス（中央ディレクトリでの出現順）
    public private(set) var children: [String: [String]]

    private static let utf8Flag: UInt16 = 0x0800
    private static let encryptedFlag: UInt16 = 0x0001

    private struct Candidate {
        var elements: [String]
        var path: String
        var isDirectory: Bool
        var isMedia: Bool
        var central: ZipStructure.CentralEntry
    }

    init(archive: URL, identity: ArchiveIdentity, centralEntries: [ZipStructure.CentralEntry]) {
        self.archive = archive
        self.identity = identity

        // 1回目: 名前の判定と正規化。出さない項目を落とし、重複は先のものを使う
        var candidates: [Candidate] = []
        candidates.reserveCapacity(centralEntries.count)
        var seen = Set<String>()
        var directoryPaths = Set<String>()
        for central in centralEntries {
            let name = ArchiveNameDecoder.decode(central.nameBytes, utf8Flag: central.flags & Self.utf8Flag != 0)
            let elements = name.split(separator: "/", omittingEmptySubsequences: true)
                .filter { $0 != "." }
                .map(String.init)
            guard let last = elements.last,
                  !elements.contains(where: { $0.hasPrefix(".") }),
                  elements[0] != "__MACOSX" else { continue }
            let isDirectory = name.hasSuffix("/")
            let path = elements.joined(separator: "/") + (isDirectory ? "/" : "")
            guard seen.insert(path).inserted else { continue }

            if elements.count > 1 {
                var prefix = ""
                for element in elements.dropLast() {
                    prefix += element + "/"
                    directoryPaths.insert(prefix)
                }
            }
            if isDirectory { directoryPaths.insert(path) }
            candidates.append(Candidate(
                elements: elements,
                path: path,
                isDirectory: isDirectory,
                isMedia: !isDirectory && Self.mediaKind(ofName: last) != nil,
                central: central
            ))
        }

        // 2回目: 項目と階層を組み立てる
        var entries: [String: ArchiveEntry] = [:]
        var children: [String: [String]] = [:]
        entries.reserveCapacity(candidates.count)
        var dateCache: [UInt32: Date?] = [:]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        for candidate in candidates {
            // 途中のディレクトリを補う
            var parentPath = ""
            for element in candidate.elements.dropLast() {
                let directoryPath = parentPath + element + "/"
                if entries[directoryPath] == nil {
                    entries[directoryPath] = ArchiveEntry(
                        path: directoryPath, name: element, isDirectory: true, method: 0,
                        isEncrypted: false, compressedSize: 0, uncompressedSize: 0,
                        localHeaderOffset: 0, modificationDate: nil
                    )
                    children[parentPath, default: []].append(directoryPath)
                }
                parentPath = directoryPath
            }

            if candidate.isDirectory {
                let isNew = entries[candidate.path] == nil
                entries[candidate.path] = Self.makeEntry(candidate, calendar: calendar, cache: &dateCache)
                if isNew { children[parentPath, default: []].append(candidate.path) }
            } else if candidate.isMedia, !directoryPaths.contains(candidate.path + "/") {
                entries[candidate.path] = Self.makeEntry(candidate, calendar: calendar, cache: &dateCache)
                children[parentPath, default: []].append(candidate.path)
            }
        }
        self.entries = entries
        self.children = children
    }

    public func entry(at path: String) -> ArchiveEntry? {
        entries[path]
    }

    /// 階層の直下の行（ディレクトリ `.directory` と対応メディア `.media`）。並べ替え前。`...` は含めない
    public func items(in directory: String) -> [MediaFile] {
        guard let paths = children[directory] else { return [] }
        var descriptions: [String: String] = [:]
        var result: [MediaFile] = []
        result.reserveCapacity(paths.count)
        for path in paths {
            guard let entry = entries[path] else { continue }
            let url = ArchiveURL.entry(archive: archive, path: path)
            if entry.isDirectory {
                result.append(MediaFile(
                    url: url, name: entry.name, kind: .directory, typeDescription: "フォルダ",
                    creationDate: entry.modificationDate, fileSize: 0
                ))
            } else if let kind = Self.mediaKind(ofName: entry.name) {
                let fileExtension = Self.fileExtension(ofName: entry.name)
                let description: String
                if let cached = descriptions[fileExtension] {
                    description = cached
                } else {
                    description = UTType(filenameExtension: fileExtension)?.localizedDescription
                        ?? fileExtension.uppercased()
                    descriptions[fileExtension] = description
                }
                result.append(MediaFile(
                    url: url, name: entry.name, kind: .media(kind), typeDescription: description,
                    creationDate: entry.modificationDate,
                    fileSize: Int64(clamping: entry.uncompressedSize)
                ))
            }
        }
        return result
    }

    // MARK: - 補助

    private static func makeEntry(
        _ candidate: Candidate,
        calendar: Calendar,
        cache: inout [UInt32: Date?]
    ) -> ArchiveEntry {
        let central = candidate.central
        return ArchiveEntry(
            path: candidate.path,
            name: candidate.elements[candidate.elements.count - 1],
            isDirectory: candidate.isDirectory,
            method: central.method,
            isEncrypted: central.flags & encryptedFlag != 0,
            compressedSize: central.compressedSize,
            uncompressedSize: candidate.isDirectory ? 0 : central.uncompressedSize,
            localHeaderOffset: central.localHeaderOffset,
            modificationDate: modificationDate(of: central, calendar: calendar, cache: &cache)
        )
    }

    /// DOS 日時の変換は同じ値が多いため、値ごとに1回だけ行う
    private static func modificationDate(
        of central: ZipStructure.CentralEntry,
        calendar: Calendar,
        cache: inout [UInt32: Date?]
    ) -> Date? {
        if !central.extraField.isEmpty,
           let unix = ZipStructure.unixModificationTime(in: central.extraField) {
            return Date(timeIntervalSince1970: TimeInterval(unix))
        }
        let key = UInt32(central.dosDate) << 16 | UInt32(central.dosTime)
        if let cached = cache[key] { return cached }
        let date = ZipStructure.dosDateTime(dosDate: central.dosDate, dosTime: central.dosTime, calendar: calendar)
        cache[key] = .some(date)
        return date
    }

    private static func fileExtension(ofName name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...])
    }

    private static func mediaKind(ofName name: String) -> MediaKind? {
        let fileExtension = fileExtension(ofName: name)
        return fileExtension.isEmpty ? nil : MediaKind(fileExtension: fileExtension)
    }
}
