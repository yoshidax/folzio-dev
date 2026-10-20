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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbnailProviderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
