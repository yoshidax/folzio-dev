import CoreGraphics
import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("ThumbnailProvider")
struct ThumbnailProviderTests {
    @Test("要求サイズを 64 / 128 / 256 / 512 の段階に切り上げる")
    func roundsPointSizeToPixelSteps() {
        #expect(ThumbnailProvider.pixelSize(forPointSize: 16, scale: 1) == 64)
        #expect(ThumbnailProvider.pixelSize(forPointSize: 16, scale: 2) == 64)
        #expect(ThumbnailProvider.pixelSize(forPointSize: 50, scale: 1) == 64)
        #expect(ThumbnailProvider.pixelSize(forPointSize: 64, scale: 1) == 64)
        #expect(ThumbnailProvider.pixelSize(forPointSize: 64.1, scale: 1) == 128)
        #expect(ThumbnailProvider.pixelSize(forPointSize: 100, scale: 2) == 256)
        #expect(ThumbnailProvider.pixelSize(forPointSize: 300, scale: 2) == 512)
        #expect(ThumbnailProvider.pixelSize(forPointSize: 1000, scale: 1) == 512)
        #expect(ThumbnailProvider.pixelSize(forPointSize: .nan, scale: 1) == 64)
        #expect(ThumbnailProvider.pixelSize(forPointSize: .infinity, scale: 1) == 64)
    }

    @Test("mixed の JPEG と mp4 でサムネイルが返る", .timeLimit(.minutes(1)))
    func generatesThumbnailsForMixedFixtures() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try FixtureSets.mixed(in: root)
        let folder = root.appendingPathComponent("mixed", isDirectory: true)
        let provider = ThumbnailProvider()

        let jpeg = await provider.thumbnail(
            for: folder.appendingPathComponent("01-photo.jpg"),
            pointSize: 100,
            scale: 2
        )
        #expect(jpeg != nil)
        if let jpeg {
            #expect(jpeg.width > 0)
            #expect(jpeg.height > 0)
        }

        let video = await provider.thumbnail(
            for: folder.appendingPathComponent("06-video.mp4"),
            pointSize: 100,
            scale: 2
        )
        #expect(video != nil)
        if let video {
            #expect(video.width > 0)
            #expect(video.height > 0)
        }
    }

    @Test("broken のファイルでは nil が返りクラッシュしない", .timeLimit(.minutes(1)))
    func returnsNilForBrokenFixtures() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try FixtureSets.broken(in: root)
        let folder = root.appendingPathComponent("broken", isDirectory: true)
        let provider = ThumbnailProvider()

        for name in ["truncated.jpg", "fake.jpg", "empty.mp4"] {
            let url = folder.appendingPathComponent(name)
            #expect(FileManager.default.fileExists(atPath: url.path))
            let image = await provider.thumbnail(for: url, pointSize: 100, scale: 2)
            #expect(image == nil)
        }
    }

    // MARK: - zip の中の画像

    @Test("zip の中の PNG は QuickLook を使わず縮小画像が返る", .timeLimit(.minutes(1)))
    func generatesThumbnailForImageInsideZip() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let zip = try makeZip(in: root, entries: [
            ZipFixtureEntry(name: "pics/big.png", content: .bytes(try pngData(in: root, width: 800, height: 400)), method: .deflated),
        ])
        let provider = ThumbnailProvider(archiveReader: ZipArchiveReader())
        let url = ArchiveURL.entry(archive: zip, path: "pics/big.png")

        let image = await provider.thumbnail(for: url, pointSize: 50, scale: 2)
        let thumbnail = try #require(image)
        #expect(max(thumbnail.width, thumbnail.height) == 128)
        #expect(thumbnail.width > thumbnail.height)

        // 2 回目はキャッシュから返る（同じ CGImage）
        let again = await provider.thumbnail(for: url, pointSize: 50, scale: 2)
        #expect(again === thumbnail)
    }

    @Test("zip の中の暗号化された項目・壊れた動画と画像では nil が返る", .timeLimit(.minutes(1)))
    func returnsNilForUnreadableEntriesInsideZip() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let png = try pngData(in: root, width: 64, height: 64)
        let zip = try makeZip(in: root, entries: [
            ZipFixtureEntry(name: "locked.png", content: .bytes(png), encryptedFlag: true),
            ZipFixtureEntry(name: "clip.mp4", content: .bytes(Data("x".utf8))),
            ZipFixtureEntry(name: "broken.png", content: .bytes(Data("not an image".utf8))),
            ZipFixtureEntry(name: "odd.png", content: .bytes(png), method: .raw(99)),
            ZipFixtureEntry(name: "notes.txt", content: .bytes(Data("x".utf8))),
        ])
        let provider = ThumbnailProvider(archiveReader: ZipArchiveReader())

        for name in ["locked.png", "clip.mp4", "broken.png", "odd.png", "notes.txt", "missing.png"] {
            let image = await provider.thumbnail(
                for: ArchiveURL.entry(archive: zip, path: name),
                pointSize: 50,
                scale: 2
            )
            #expect(image == nil, "\(name)")
        }
    }

    @Test("zip の中の mp4 は先頭フレームの縮小画像が返り、2 回目はキャッシュから返る", .timeLimit(.minutes(2)))
    func generatesThumbnailForVideoInsideZip() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // VideoFixtures は書き出しの間スレッドを塞ぐので、並列に走るテストと重ならないよう 1 本にまとめる
        let video = root.appendingPathComponent("clip.mp4")
        try VideoFixtures.mp4(at: video, fastStart: false)
        let zip = try makeZip(in: root, entries: [
            ZipFixtureEntry(name: "movies/clip.mp4", content: .bytes(try Data(contentsOf: video)), method: .deflated),
        ])
        let reader = ZipArchiveReader()
        _ = try await reader.open(zip)
        let provider = ThumbnailProvider(archiveReader: reader)
        let url = ArchiveURL.entry(archive: zip, path: "movies/clip.mp4")

        let image = await provider.thumbnail(for: url, pointSize: 50, scale: 2)
        let thumbnail = try #require(image)
        #expect(thumbnail.width > 0)
        #expect(max(thumbnail.width, thumbnail.height) <= 128)

        let again = await provider.thumbnail(for: url, pointSize: 50, scale: 2)
        #expect(again === thumbnail)
    }

    @Test("archiveReader がないと zip の中の URL は nil が返る")
    func returnsNilForArchiveURLWithoutReader() async {
        let url = ArchiveURL.entry(archive: URL(fileURLWithPath: "/tmp/none.zip"), path: "a.png")
        let image = await ThumbnailProvider().thumbnail(for: url, pointSize: 50, scale: 2)
        #expect(image == nil)
    }

    @Test("zip の中の取得は同時 4 件までに制限される", .timeLimit(.minutes(1)))
    func limitsConcurrentArchiveReads() async throws {
        let reader = SlowArchiveReader(delay: .milliseconds(50), data: try pngBytes(width: 32, height: 32))
        let provider = ThumbnailProvider(archiveReader: reader)
        let archive = URL(fileURLWithPath: "/tmp/none.zip")

        await withTaskGroup(of: CGImage?.self) { group in
            for index in 0..<12 {
                group.addTask {
                    await provider.thumbnail(
                        for: ArchiveURL.entry(archive: archive, path: "\(index).png"),
                        pointSize: 50,
                        scale: 2
                    )
                }
            }
            for await image in group {
                #expect(image != nil)
            }
        }

        let state = reader.snapshot()
        #expect(state.total == 12)
        #expect(state.maxRunning <= 4)
        #expect(state.maxRunning >= 2)
    }

    @Test("cancel(for:) は zip の中の要求を URL とピクセル数で取り消し、他のサイズは巻き込まない", .timeLimit(.minutes(1)))
    func cancelsArchiveRequestsByURLAndPixelSize() async throws {
        let reader = SlowArchiveReader(delay: .seconds(30), data: try pngBytes(width: 32, height: 32))
        let provider = ThumbnailProvider(archiveReader: reader)
        let url = ArchiveURL.entry(archive: URL(fileURLWithPath: "/tmp/none.zip"), path: "a.png")

        let small = Task { await provider.thumbnail(for: url, pointSize: 16, scale: 2) }
        let large = Task { await provider.thumbnail(for: url, pointSize: 100, scale: 2) }
        while reader.snapshot().running < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }

        provider.cancel(for: url, pointSize: 16, scale: 2)
        #expect(await small.value == nil)
        #expect(reader.snapshot().running == 1)

        provider.cancel(for: url, pointSize: 100, scale: 2)
        #expect(await large.value == nil)
        #expect(reader.snapshot().running == 0)
    }

    private func makeZip(in root: URL, entries: [ZipFixtureEntry]) throws -> URL {
        let zip = root.appendingPathComponent("sample-\(UUID().uuidString).zip")
        try ZipFixtureWriter.write(entries, to: zip)
        return zip
    }

    private func pngData(in root: URL, width: Int, height: Int) throws -> Data {
        let file = root.appendingPathComponent("src-\(UUID().uuidString).png")
        try ImageFixtures.png(at: file, width: width, height: height)
        return try Data(contentsOf: file)
    }

    private func pngBytes(width: Int, height: Int) throws -> Data {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        return try pngData(in: root, width: width, height: height)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbnailProviderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// `data(for:)` が一定時間かかり、同時実行数を記録する読み取り器
private final class SlowArchiveReader: ArchiveReading, @unchecked Sendable {
    struct Snapshot {
        var running = 0
        var maxRunning = 0
        var total = 0
    }

    private let delay: Duration
    private let payload: Data
    private let lock = NSLock()
    private var state = Snapshot()

    init(delay: Duration, data: Data) {
        self.delay = delay
        self.payload = data
    }

    func snapshot() -> Snapshot {
        lock.withLock { state }
    }

    func open(_ archive: URL) async throws(ArchiveError) -> ArchiveIndex {
        throw ArchiveError.notFound
    }

    func data(for entryURL: URL, limit: Int) async throws(ArchiveError) -> Data {
        lock.withLock {
            state.running += 1
            state.total += 1
            state.maxRunning = max(state.maxRunning, state.running)
        }
        defer { lock.withLock { state.running -= 1 } }
        do {
            try await Task.sleep(for: delay)
        } catch {
            throw ArchiveError.corrupted("cancelled")
        }
        return payload
    }

    func stream(for entryURL: URL) async throws(ArchiveError) -> ArchiveEntryStream {
        throw ArchiveError.notFound
    }

    func identity(of archive: URL) -> ArchiveIdentity? {
        nil
    }
}
