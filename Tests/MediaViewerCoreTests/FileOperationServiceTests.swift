import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("FileOperationService")
struct FileOperationServiceTests {
    private let service = FileOperationService()

    @Test("コピーすると元を残したまま操作先に複製される")
    func copiesFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let source = folder.appendingPathComponent("a.jpg")

        let result = await service.execute(
            FileOperation(kind: .copy, sources: [source], destination: destination),
            resolution: .replace
        )

        #expect(result.failed.isEmpty)
        #expect(result.succeeded == [destination.appendingPathComponent("a.jpg")])
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: destination.appendingPathComponent("a.jpg")) == Data(contentsOf: source))
    }

    @Test("移動すると元の場所から消える")
    func movesFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let source = folder.appendingPathComponent("a.jpg")

        let result = await service.execute(
            FileOperation(kind: .move, sources: [source], destination: destination),
            resolution: .replace
        )

        #expect(result.failed.isEmpty)
        #expect(result.succeeded == [destination.appendingPathComponent("a.jpg")])
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("a.jpg").path))
    }

    @Test("名前を変更すると新しい名前で同じフォルダに残る")
    func renamesFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let source = folder.appendingPathComponent("b.png")
        let renamed = folder.appendingPathComponent("renamed.png")

        let result = await service.execute(
            FileOperation(kind: .rename(newName: "renamed.png"), sources: [source]),
            resolution: .replace
        )

        #expect(result.failed.isEmpty)
        #expect(result.succeeded == [renamed])
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: renamed.path))
    }

    @Test("ゴミ箱へ移動するとゴミ箱内の URL を返し元の場所から消える")
    func trashesFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let source = folder.appendingPathComponent("a.jpg")
        var trashed: URL?
        defer {
            if let trashed {
                try? FileManager.default.removeItem(at: trashed)
            }
        }

        let result = await service.execute(
            FileOperation(kind: .trash, sources: [source]),
            resolution: .replace
        )

        #expect(result.failed.isEmpty)
        let trashedURL = try #require(result.succeeded.first)
        trashed = trashedURL
        #expect(FileManager.default.fileExists(atPath: trashedURL.path))
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }

    @Test("衝突を検出する")
    func detectsConflicts() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let source = folder.appendingPathComponent("a.jpg")
        try Data("existing".utf8).write(to: destination.appendingPathComponent("a.jpg"))

        let copy = FileOperation(kind: .copy, sources: [source], destination: destination)
        let move = FileOperation(kind: .move, sources: [source], destination: destination)
        #expect(service.conflicts(for: copy) == [source])
        #expect(service.conflicts(for: move) == [source])
        #expect(service.conflicts(for: FileOperation(kind: .rename(newName: "x.jpg"), sources: [source])) == [])
        #expect(service.conflicts(for: FileOperation(kind: .trash, sources: [source])) == [])
    }

    @Test("置き換えると既存の項目をゴミ箱へ入れてからコピーする")
    func replacesExistingItem() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let source = folder.appendingPathComponent("a.jpg")
        let existing = destination.appendingPathComponent("a.jpg")
        try Data("existing".utf8).write(to: existing)

        let result = await service.execute(
            FileOperation(kind: .copy, sources: [source], destination: destination),
            resolution: .replace
        )

        #expect(result.failed.isEmpty)
        #expect(result.succeeded == [existing])
        #expect(try Data(contentsOf: existing) == Data(contentsOf: source))
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test("両方残すと既存と衝突しない連番の名前でコピーする")
    func keepsBothOnConflict() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let a = folder.appendingPathComponent("a.jpg")
        let c = folder.appendingPathComponent("c 2.jpg")
        try Data("existing-a".utf8).write(to: destination.appendingPathComponent("a.jpg"))
        try Data("existing-c".utf8).write(to: destination.appendingPathComponent("c 2.jpg"))

        let result = await service.execute(
            FileOperation(kind: .copy, sources: [a, c], destination: destination),
            resolution: .keepBoth
        )

        #expect(result.failed.isEmpty)
        #expect(Set(result.succeeded.map(\.lastPathComponent)) == ["a 2.jpg", "c 3.jpg"])
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("a 2.jpg").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("c 3.jpg").path))
        #expect(try Data(contentsOf: destination.appendingPathComponent("a.jpg")) == Data("existing-a".utf8))
        #expect(try Data(contentsOf: destination.appendingPathComponent("c 2.jpg")) == Data("existing-c".utf8))
    }

    @Test("中止すると何も変更しない")
    func abortsWithoutChanges() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let source = folder.appendingPathComponent("a.jpg")
        let existing = destination.appendingPathComponent("a.jpg")
        try Data("existing".utf8).write(to: existing)

        let result = await service.execute(
            FileOperation(kind: .copy, sources: [source], destination: destination),
            resolution: .abort
        )

        #expect(result.succeeded.isEmpty)
        #expect(result.failed.isEmpty)
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: existing) == Data("existing".utf8))
    }

    @Test("書き込みできないフォルダでは失敗理由を返し元のファイルを変更しない")
    func failsInReadOnlyFolder() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let source = folder.appendingPathComponent("a.jpg")
        let originalContents = try Data(contentsOf: source)

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: destination.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        }

        let result = await service.execute(
            FileOperation(kind: .copy, sources: [source], destination: destination),
            resolution: .replace
        )

        #expect(result.succeeded.isEmpty)
        let failure = try #require(result.failed.first)
        #expect(failure.url == source)
        #expect(!failure.reason.isEmpty)
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: source) == originalContents)
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("a.jpg").path))
    }

    @Test("同じフォルダへの移動は何もしない")
    func movingToSameFolderIsNoOp() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let source = folder.appendingPathComponent("a.jpg")
        let originalContents = try Data(contentsOf: source)

        let result = await service.execute(
            FileOperation(kind: .move, sources: [source], destination: folder),
            resolution: .replace
        )

        #expect(result.failed.isEmpty)
        #expect(result.succeeded == [source])
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: source) == originalContents)
    }

    @Test("1件が失敗しても残りの処理を続ける")
    func continuesAfterFailure() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let destination = folder.appendingPathComponent("dest", isDirectory: true)
        let missing = folder.appendingPathComponent("missing.jpg")
        let a = folder.appendingPathComponent("a.jpg")
        let b = folder.appendingPathComponent("b.png")

        let result = await service.execute(
            FileOperation(kind: .copy, sources: [missing, a, b], destination: destination),
            resolution: .replace
        )

        #expect(result.succeeded.count == 2)
        #expect(result.failed.count == 1)
        #expect(result.failed.first?.url == missing)
        #expect(result.failed.first?.reason.isEmpty == false)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("a.jpg").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("b.png").path))
    }

    @Test("フォルダを自分自身へコピーしようとすると失敗する")
    func refusesCopyingFolderIntoItself() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try makeOps(in: root)
        let source = folder.appendingPathComponent("bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

        let result = await service.execute(
            FileOperation(kind: .copy, sources: [source], destination: source),
            resolution: .replace
        )

        #expect(result.succeeded.isEmpty)
        let failure = try #require(result.failed.first)
        #expect(failure.url == source)
        #expect(!failure.reason.isEmpty)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaViewerOpsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeOps(in root: URL) throws -> URL {
        try FixtureSets.ops(in: root)
        return root.appendingPathComponent("ops", isDirectory: true)
    }
}
