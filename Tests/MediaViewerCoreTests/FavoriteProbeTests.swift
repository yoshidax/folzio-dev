import Foundation
import Testing
@testable import MediaViewerCore

@Suite("FavoriteProbe")
struct FavoriteProbeTests {
    private func makeURLs(_ count: Int) -> [URL] {
        (0..<count).map { URL(fileURLWithPath: "/tmp/favorite-probe/\($0)", isDirectory: true) }
    }

    private func collect(_ stream: AsyncStream<FavoriteProbeResult>) async -> [FavoriteProbeResult] {
        var results: [FavoriteProbeResult] = []
        for await result in stream {
            results.append(result)
        }
        return results
    }

    @Test("存在するフォルダは true")
    func existingFolderExists() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(FavoriteProbe.folderExists(root))
    }

    @Test("存在しないパスは false")
    func missingPathDoesNotExist() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = root.appendingPathComponent("missing", isDirectory: true)
        #expect(!FavoriteProbe.folderExists(missing))
    }

    @Test("通常のファイルは false")
    func regularFileIsNotFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("a.txt")
        try Data("a".utf8).write(to: file)
        #expect(!FavoriteProbe.folderExists(file))
    }

    @Test("権限のないフォルダも存在するので true")
    func accessDeniedFolderExists() throws {
        let root = try makeTemporaryDirectory()
        let locked = root.appendingPathComponent("locked", isDirectory: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)

        #expect(FavoriteProbe.folderExists(locked))
    }

    @Test("全 URL の結果を1回ずつ流し、同時実行数は上限を超えない")
    func yieldsEveryURLOnceWithinLimit() async {
        let urls = makeURLs(6)
        let checker = FakeExistenceChecker()

        let results = await collect(FavoriteProbe.results(for: urls, maxConcurrent: 2) { await checker.exists($0) })

        #expect(results.count == 6)
        #expect(Set(results.map(\.url)) == Set(urls))
        #expect(await checker.started == 6)
        #expect(await checker.maxInFlight <= 2)
    }

    @Test("exists の結果がそのまま FavoriteProbeResult.exists になる")
    func passesThroughExistence() async {
        let urls = makeURLs(4)
        let missing: Set<URL> = [urls[1], urls[3]]
        let checker = FakeExistenceChecker(missing: missing)

        let results = await collect(FavoriteProbe.results(for: urls, maxConcurrent: 2) { await checker.exists($0) })

        #expect(results.count == 4)
        for result in results {
            #expect(result.exists == !missing.contains(result.url))
        }
    }

    @Test("空の入力ではすぐに終わる")
    func finishesForEmptyInput() async {
        let checker = FakeExistenceChecker()
        let results = await collect(FavoriteProbe.results(for: []) { await checker.exists($0) })
        #expect(results.isEmpty)
        #expect(await checker.started == 0)
    }

    @Test("上限が 0 以下なら 1 として扱う")
    func treatsNonPositiveLimitAsOne() async {
        let urls = makeURLs(6)
        let checker = FakeExistenceChecker()

        let results = await collect(FavoriteProbe.results(for: urls, maxConcurrent: 0) { await checker.exists($0) })

        #expect(results.count == 6)
        #expect(await checker.maxInFlight == 1)
    }

    @Test("ストリームを抜けたら未実行の確認を始めない")
    func stopsAfterTermination() async throws {
        let urls = makeURLs(20)
        let checker = FakeExistenceChecker()

        for await _ in FavoriteProbe.results(for: urls, maxConcurrent: 2, exists: { await checker.exists($0) }) {
            break
        }
        try await Task.sleep(for: .milliseconds(100))

        #expect(await checker.started < 20)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaViewerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private actor FakeExistenceChecker {
    private let missing: Set<URL>
    private(set) var started = 0
    private(set) var maxInFlight = 0
    private var inFlight = 0

    init(missing: Set<URL> = []) {
        self.missing = missing
    }

    func exists(_ url: URL) async -> Bool {
        started += 1
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        defer { inFlight -= 1 }

        try? await Task.sleep(for: .milliseconds(20))
        return !missing.contains(url)
    }
}
