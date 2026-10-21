import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("DirectoryLister")
struct DirectoryListerTests {
    @Test("mixed から対応メディアとサブフォルダだけを返す")
    func listsOnlySupportedMedia() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try FixtureSets.mixed(in: root)
        let folder = root.appendingPathComponent("mixed", isDirectory: true)
        let lister = DirectoryLister()

        let files = try await lister.mediaFiles(in: folder)
        #expect(files.count == 8)
        #expect(Set(files.map(\.name)) == [
            "sub",
            "01-photo.jpg",
            "02-image.png",
            "03-animation.gif",
            "04-static.webp",
            "05-animation.webp",
            "06-video.mp4",
            "07-movie.mov",
        ])
        #expect(!files.contains { $0.name == "notes.txt" })
        #expect(!files.contains { $0.name == "document.pdf" })
        #expect(!files.contains { $0.name == ".hidden.jpg" })
        #expect(files.first { $0.name == "sub" }?.kind == .folder)

        let subfolders = try await lister.subfolders(of: folder)
        #expect(subfolders.map(\.lastPathComponent) == ["sub"])
    }

    @Test("権限のないフォルダは accessDenied を返す")
    func reportsAccessDenied() async throws {
        let root = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: root.path)

        let lister = DirectoryLister()
        do {
            _ = try await lister.mediaFiles(in: root)
            Issue.record("accessDenied was not thrown")
        } catch {
            #expect(error == .accessDenied)
        }
    }

    @Test("存在しないパスは notFound を返す")
    func reportsNotFound() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)", isDirectory: true)

        let lister = DirectoryLister()
        do {
            _ = try await lister.mediaFiles(in: missing)
            Issue.record("notFound was not thrown")
        } catch {
            #expect(error == .notFound)
        }
    }

    @Test("hasSubfolders は subfolders と同じ条件でサブフォルダの有無を返す", arguments: [
        SubfolderFixture.empty,
        .filesOnly,
        .hiddenFolderOnly,
        .hiddenFlagFolderOnly,
        .packageOnly,
        .oneSubfolder,
        .mixed,
    ])
    func hasSubfoldersMatchesSubfolders(fixture: SubfolderFixture) async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try fixture.populate(root)

        let lister = DirectoryLister()
        let has = try await lister.hasSubfolders(in: root)
        let subfolders = try await lister.subfolders(of: root)
        #expect(has == fixture.expected)
        #expect(has == !subfolders.isEmpty)
    }

    @Test("権限のないフォルダの hasSubfolders は accessDenied を返す")
    func hasSubfoldersReportsAccessDenied() async throws {
        let root = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("sub", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: root.path)

        let lister = DirectoryLister()
        await expectListingError(.accessDenied) { try await lister.hasSubfolders(in: root) }
        await expectListingError(.accessDenied) { try await lister.subfolders(of: root) }
    }

    @Test("存在しないパスとファイルのパスの hasSubfolders は notFound を返す")
    func hasSubfoldersReportsNotFound() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = root.appendingPathComponent("missing", isDirectory: true)
        let file = root.appendingPathComponent("a.jpg")
        FileManager.default.createFile(atPath: file.path, contents: Data())

        let lister = DirectoryLister()
        for url in [missing, file] {
            await expectListingError(.notFound) { try await lister.hasSubfolders(in: url) }
            await expectListingError(.notFound) { try await lister.subfolders(of: url) }
        }
    }

    @Test("zip ファイルを kind == .archive で返し、zip という名前のディレクトリはフォルダとして返し、隠し zip は返さない")
    func listsZipFilesAsArchives() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let fileManager = FileManager.default
        fileManager.createFile(atPath: root.appendingPathComponent("a.zip").path, contents: Data([0x50, 0x4B]))
        fileManager.createFile(atPath: root.appendingPathComponent("B.ZIP").path, contents: Data([0x50, 0x4B]))
        fileManager.createFile(atPath: root.appendingPathComponent(".hidden.zip").path, contents: Data([0x50, 0x4B]))
        fileManager.createFile(atPath: root.appendingPathComponent("c.jpg").path, contents: Data())
        try fileManager.createDirectory(
            at: root.appendingPathComponent("x.zip", isDirectory: true),
            withIntermediateDirectories: true
        )

        let files = try await DirectoryLister().mediaFiles(in: root)

        #expect(Set(files.map(\.name)) == ["a.zip", "B.ZIP", "c.jpg", "x.zip"])
        #expect(files.first { $0.name == "x.zip" }?.kind == .folder)
        for name in ["a.zip", "B.ZIP"] {
            let file = try #require(files.first { $0.name == name })
            #expect(file.kind == .archive)
            #expect(!file.typeDescription.isEmpty)
        }
        #expect(files.first { $0.name == "c.jpg" }?.kind == .media(.jpeg))
    }

    @Test("サブフォルダを kind == .folder で返し、隠しフォルダとパッケージは返さない。subfolders と同じフォルダになる")
    func listsSubfoldersAsFolders() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let fileManager = FileManager.default
        for path in ["sub", ".hidden-dir", "Pkg.app/Contents", "dir.zip"] {
            try fileManager.createDirectory(
                at: root.appendingPathComponent(path, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        try ImageFixtures.jpeg(at: root.appendingPathComponent("a.jpg"), width: 8, height: 8)
        fileManager.createFile(atPath: root.appendingPathComponent("z.zip").path, contents: Data([0x50, 0x4B]))
        fileManager.createFile(atPath: root.appendingPathComponent("notes.txt").path, contents: Data("x".utf8))

        let lister = DirectoryLister()
        let files = try await lister.mediaFiles(in: root)

        #expect(Set(files.map(\.name)) == ["sub", "dir.zip", "z.zip", "a.jpg"])
        let sub = try #require(files.first { $0.name == "sub" })
        #expect(sub.kind == .folder)
        #expect(sub.typeDescription == "フォルダ")
        #expect(sub.fileSize == 0)
        #expect(sub.creationDate != nil)
        #expect(files.first { $0.name == "dir.zip" }?.kind == .folder)
        #expect(files.first { $0.name == "z.zip" }?.kind == .archive)
        #expect(files.first { $0.name == "a.jpg" }?.kind == .media(.jpeg))

        let folderURLs = Set(files.filter { $0.kind == .folder }.map(\.url.standardizedFileURL))
        let subfolders = Set(try await lister.subfolders(of: root).map(\.standardizedFileURL))
        #expect(folderURLs == subfolders)
    }

    @Test("subfolders と hasSubfolders は zip ファイルを数えない")
    func subfolderQueriesIgnoreZipFiles() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        FileManager.default.createFile(atPath: root.appendingPathComponent("a.zip").path, contents: Data([0x50, 0x4B]))
        FileManager.default.createFile(atPath: root.appendingPathComponent("B.ZIP").path, contents: Data([0x50, 0x4B]))

        let lister = DirectoryLister()
        #expect(try await lister.subfolders(of: root).isEmpty)
        #expect(try await lister.hasSubfolders(in: root) == false)
    }

    private func expectListingError<T>(
        _ expected: ListingError,
        _ body: () async throws -> T
    ) async {
        do {
            _ = try await body()
            Issue.record("\(expected) was not thrown")
        } catch {
            #expect(error as? ListingError == expected)
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaViewerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

enum SubfolderFixture: String, CaseIterable, Sendable {
    case empty
    case filesOnly
    case hiddenFolderOnly
    case hiddenFlagFolderOnly
    case packageOnly
    case oneSubfolder
    case mixed

    var expected: Bool {
        switch self {
        case .oneSubfolder, .mixed:
            return true
        case .empty, .filesOnly, .hiddenFolderOnly, .hiddenFlagFolderOnly, .packageOnly:
            return false
        }
    }

    func populate(_ root: URL) throws {
        let fileManager = FileManager.default
        func makeFolder(_ name: String) throws -> URL {
            let url = root.appendingPathComponent(name, isDirectory: true)
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        func makeFile(_ name: String) {
            fileManager.createFile(atPath: root.appendingPathComponent(name).path, contents: Data())
        }

        switch self {
        case .empty:
            break
        case .filesOnly:
            makeFile("a.jpg")
            makeFile("b.txt")
        case .hiddenFolderOnly:
            _ = try makeFolder(".secret")
        case .hiddenFlagFolderOnly:
            var folder = try makeFolder("flagged")
            var values = URLResourceValues()
            values.isHidden = true
            try folder.setResourceValues(values)
        case .packageOnly:
            _ = try makeFolder("Sample.app")
        case .oneSubfolder:
            _ = try makeFolder("sub")
        case .mixed:
            for index in 0..<50 {
                makeFile(String(format: "%02d.jpg", index))
            }
            _ = try makeFolder("sub")
        }
    }
}
