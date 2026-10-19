import Foundation

public enum ListingError: Error, Sendable, Equatable {
    case accessDenied
    case notFound
    case other(String)
}

public protocol DirectoryListing: Sendable {
    func mediaFiles(in folder: URL) async throws(ListingError) -> [MediaFile]
    func subfolders(of folder: URL) async throws(ListingError) -> [URL]
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
                    kind: kind,
                    typeDescription: values?.localizedTypeDescription ?? kind.rawValue.uppercased(),
                    creationDate: values?.creationDate,
                    fileSize: Int64(values?.fileSize ?? 0)
                )
            }
        }
    }

    public func subfolders(of folder: URL) async throws(ListingError) -> [URL] {
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
                    includingPropertiesForKeys: Array(Self.folderKeys),
                    options: [.skipsHiddenFiles]
                )
            } catch {
                throw Self.listingError(from: error)
            }

            return urls.filter { url in
                guard let values = try? url.resourceValues(forKeys: Self.folderKeys) else { return false }
                return values.isDirectory == true && values.isPackage != true
            }.sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
        }
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
