import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("DirectoryLister")
struct DirectoryListerTests {
    @Test("mixed から対応メディアだけを返す")
    func listsOnlySupportedMedia() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try FixtureSets.mixed(in: root)
        let folder = root.appendingPathComponent("mixed", isDirectory: true)
        let lister = DirectoryLister()

        let files = try await lister.mediaFiles(in: folder)
        #expect(files.count == 7)
        #expect(Set(files.map(\.name)) == [
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
        #expect(!files.contains { $0.name == "sub" })

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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaViewerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
