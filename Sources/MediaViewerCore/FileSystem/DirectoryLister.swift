import Foundation

public enum ListingError: Error, Sendable, Equatable {
    case accessDenied
    case notFound
    case other(String)
}

public protocol DirectoryListing: Sendable {
    func mediaFiles(in folder: URL) async throws(ListingError) -> [MediaFile]
    func subfolders(of folder: URL) async throws(ListingError) -> [URL]
    func hasSubfolders(in folder: URL) async throws(ListingError) -> Bool
}

extension DirectoryListing {
    public func hasSubfolders(in folder: URL) async throws(ListingError) -> Bool {
        try await !subfolders(of: folder).isEmpty
    }
}

public struct DirectoryLister: DirectoryListing {
    private static let fileKeys: Set<URLResourceKey> = [
        .creationDateKey,
        .isDirectoryKey,
        .contentTypeKey,
        .fileSizeKey,
        .localizedTypeDescriptionKey,
    ]

    private static let folderKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isPackageKey,
        .localizedNameKey,
    ]

    public init() {}

    public func mediaFiles(in folder: URL) async throws(ListingError) -> [MediaFile] {
        try await run {
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory) else {
                throw ListingError.notFound
            }
            guard isDirectory.boolValue else {
                throw ListingError.notFound
            }

            let urls: [URL]
            do {
                urls = try fileManager.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: Array(Self.fileKeys),
                    options: [.skipsHiddenFiles]
                )
            } catch {
                throw Self.listingError(from: error)
            }

            return urls.compactMap { url -> MediaFile? in
                let values = try? url.resourceValues(forKeys: Self.fileKeys)
                guard values?.isDirectory != true else { return nil }
                guard let kind = MediaKind(fileExtension: url.pathExtension) else { return nil }

                return MediaFile(
                    url: url,
                    name: url.lastPathComponent,
                    kind: .media(kind),
                    typeDescription: values?.localizedTypeDescription ?? kind.rawValue.uppercased(),
                    creationDate: values?.creationDate,
                    fileSize: Int64(values?.fileSize ?? 0)
                )
            }
        }
    }

    public func subfolders(of folder: URL) async throws(ListingError) -> [URL] {
        try await run {
            try Self.ensureDirectory(folder)

            let urls: [URL]
            do {
                urls = try FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: Array(Self.folderKeys),
                    options: [.skipsHiddenFiles]
                )
            } catch {
                throw Self.listingError(from: error)
            }

            return urls.filter(Self.isVisibleSubfolder).sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
        }
    }

    public func hasSubfolders(in folder: URL) async throws(ListingError) -> Bool {
        try await run {
            try Self.ensureDirectory(folder)

            // 10,000 件規模のフォルダでも速く終わるよう、readdir の d_type でディレクトリ以外を読み飛ばし、
            // 隠し属性とパッケージの判定はディレクトリだけに行う。条件は subfolders(of:) と同じ
            guard let directory = opendir(folder.path) else {
                throw Self.listingError(errno: errno)
            }
            defer { closedir(directory) }

            while true {
                errno = 0
                guard let entry = readdir(directory) else {
                    if errno != 0 {
                        throw Self.listingError(errno: errno)
                    }
                    return false
                }

                let type = entry.pointee.d_type
                guard type == DT_DIR || type == DT_UNKNOWN else { continue }

                let name = withUnsafePointer(to: entry.pointee.d_name) { pointer in
                    pointer.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) {
                        String(cString: $0)
                    }
                }
                guard !name.hasPrefix(".") else { continue }

                let url = folder.appendingPathComponent(name, isDirectory: true)
                if Self.isVisibleSubfolder(url), (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden != true {
                    return true
                }
            }
        }
    }

    private static func ensureDirectory(_ folder: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) else {
            throw ListingError.notFound
        }
        guard isDirectory.boolValue else {
            throw ListingError.notFound
        }
    }

    private static func isVisibleSubfolder(_ url: URL) -> Bool {
        // isPackage の判定は重いため、ディレクトリだけに問い合わせる
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return false }
        return (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws(ListingError) -> T {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try work()
            }.value
        } catch let error as ListingError {
            throw error
        } catch {
            throw ListingError.other(error.localizedDescription)
        }
    }

    private static func listingError(errno code: Int32) -> ListingError {
        switch code {
        case EACCES, EPERM:
            return .accessDenied
        case ENOENT, ENOTDIR:
            return .notFound
        default:
            return .other(String(cString: strerror(code)))
        }
    }

    private static func listingError(from error: Error) -> ListingError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError, NSFileReadUnknownError:
                return .accessDenied
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .notFound
            default:
                break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EACCES) {
            return .accessDenied
        }
        return .other(error.localizedDescription)
    }
}
