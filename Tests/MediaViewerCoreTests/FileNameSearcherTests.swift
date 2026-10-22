import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("FileNameSearcher", .serialized)
struct FileNameSearcherTests {
    private struct Env {
        let base: URL
        let root: URL

        func cleanup() {
            try? FileManager.default.removeItem(at: base)
        }
    }

    private func makeEnv() throws -> Env {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileNameSearcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try FixtureSets.search(in: base)
        return Env(base: base, root: base.appendingPathComponent("search", isDirectory: true))
    }

    private func collect(
        _ searcher: FileNameSearcher = FileNameSearcher(),
        in root: URL,
        _ keyword: String
    ) async throws -> [[MediaFile]] {
        let pattern = try #require(SearchPattern(keyword: keyword))
        var batches: [[MediaFile]] = []
        for await batch in searcher.search(in: root, matching: pattern) {
            batches.append(batch)
        }
        return batches
    }

    /// 起点からの相対パス（NFC にそろえる）。結果の URL が起点と同じ形で始まることも確かめる
    private func relativePaths(_ files: [MediaFile], root: URL) -> Set<String> {
        Set(files.map { file in
            #expect(file.url.path.hasPrefix(root.path + "/"), "起点と違う形の URL: \(file.url.path)")
            return String(file.url.path.dropFirst(root.path.count + 1)).precomposedStringWithCanonicalMapping
        })
    }

    @Test("cat は対応メディアだけを返し、隠し・パッケージ・zip・フォルダ名・リンク経由を除く")
    func keywordCat() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let files = try await collect(in: env.root, "cat").flatMap { $0 }
        #expect(relativePaths(files, root: env.root) == ["Cat01.jpg", "a/my_cat.mov", "a/b/deep/cat-deep.png", "b/Cat01.jpg"])
        #expect(files.count == 4)
    }

    @Test("ワイルドカードと NFD の名前")
    func wildcardsAndNormalization() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let png = try await collect(in: env.root, "*.png").flatMap { $0 }
        #expect(relativePaths(png, root: env.root) == ["a/dog.png", "a/b/deep/cat-deep.png", "kana/が.png"])
        let img = try await collect(in: env.root, "IMG_????.jpg").flatMap { $0 }
        #expect(relativePaths(img, root: env.root) == ["numbers/IMG_0001.jpg"])
        let ga = try await collect(in: env.root, "が").flatMap { $0 }
        #expect(relativePaths(ga, root: env.root) == ["kana/が.png"])
    }

    @Test("ファイルへのリンクは通常のファイルとして返し、フォルダへのリンクは辿らない")
    func symbolicLinks() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let linked = try await collect(in: env.root, "linked").flatMap { $0 }
        #expect(relativePaths(linked, root: env.root) == ["linked.jpg"])
        let listed = try await DirectoryLister().mediaFiles(in: env.root)
        #expect(listed.contains { $0.name == "linked.jpg" })

        let link = try await collect(in: env.root, "link").flatMap { $0 }
        #expect(relativePaths(link, root: env.root) == ["linked.jpg"])
        let dog = try await collect(in: env.root, "dog").flatMap { $0 }
        #expect(relativePaths(dog, root: env.root) == ["a/dog.png"])
    }

    @Test("返す MediaFile の値は DirectoryLister と同じ")
    func mediaFileValuesMatchLister() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let files = try await collect(in: env.root, "cat").flatMap { $0 }
        let top = try #require(files.first { $0.url.path == env.root.appendingPathComponent("Cat01.jpg").path })
        let movie = try #require(files.first { $0.name == "my_cat.mov" })
        #expect(top.kind == .media(.jpeg))
        #expect(movie.kind == .media(.mov))
        #expect(top.name == "Cat01.jpg")

        let listedTop = try #require(try await DirectoryLister().mediaFiles(in: env.root).first { $0.name == "Cat01.jpg" })
        let listedMovie = try #require(
            try await DirectoryLister().mediaFiles(in: env.root.appendingPathComponent("a", isDirectory: true))
                .first { $0.name == "my_cat.mov" }
        )
        for (found, listed) in [(top, listedTop), (movie, listedMovie)] {
            #expect(found.fileSize == listed.fileSize)
            #expect(found.creationDate == listed.creationDate)
            #expect(found.typeDescription == listed.typeDescription)
            #expect(!found.typeDescription.isEmpty)
        }
    }

    @Test("権限のないサブフォルダを飛ばして終わる")
    func skipsUnreadableFolders() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let denied = env.root.appendingPathComponent("denied", isDirectory: true)
        try FileManager.default.createDirectory(at: denied, withIntermediateDirectories: true)
        try ImageFixtures.jpeg(at: denied.appendingPathComponent("cat-denied.jpg"), width: 8, height: 8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path) }

        let files = try await collect(in: env.root, "cat").flatMap { $0 }
        #expect(relativePaths(files, root: env.root) == ["Cat01.jpg", "a/my_cat.mov", "a/b/deep/cat-deep.png", "b/Cat01.jpg"])
    }

    @Test("存在しない起点と空のフォルダでは何も流さずに終わる")
    func emptyAndMissingRoots() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let empty = env.base.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(try await collect(in: empty, "*").isEmpty)
        #expect(try await collect(in: env.base.appendingPathComponent("missing", isDirectory: true), "*").isEmpty)
    }

    @Test("バッチは batchSize 件以下に分けて流す")
    func batches() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let batches = try await collect(FileNameSearcher(batchSize: 2, batchInterval: .seconds(10)), in: env.root, "cat")
        #expect(batches.allSatisfy { $0.count <= 2 && !$0.isEmpty })
        #expect(batches.map(\.count).reduce(0, +) == 4)
    }

    /// 受け取る側は BrowserModel と同じくメインアクターで動かす（協調スレッドが塞がっていても止まらない）
    @Test("ストリームを集める Task を取り消すと、列挙が止まる")
    @MainActor
    func cancellationStopsEnumeration() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileNameSearcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FixtureSets.huge(in: base)

        let counter = BatchCounter()
        let pattern = try #require(SearchPattern(keyword: "*"))
        let stream = FileNameSearcher().search(in: base.appendingPathComponent("huge", isDirectory: true), matching: pattern)
        // 最初のバッチを受け取った時点で、集めている Task 自身を取り消す
        let collector = Task { @MainActor in
            for await batch in stream {
                counter.add(batch.count)
                if counter.batches == 1 {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        await collector.value
        let countAtCancel = counter.total
        try await Task.sleep(for: .milliseconds(500))

        #expect(counter.batches >= 1)
        #expect(counter.total == countAtCancel)
        #expect(countAtCancel < 10_000)
    }
}

@MainActor
private final class BatchCounter {
    private(set) var batches = 0
    private(set) var total = 0

    func add(_ count: Int) {
        batches += 1
        total += count
    }
}
