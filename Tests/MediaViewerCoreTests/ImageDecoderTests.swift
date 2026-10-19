import CoreGraphics
import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("ImageDecoder")
struct ImageDecoderTests {
    @Test("長辺を maxPixelSize 以下にダウンサンプリングする")
    func downsamplesLargeImage() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("large.jpg")
        try ImageFixtures.jpeg(at: url, width: 4000, height: 3000)

        let decoder = ImageDecoder()
        let image = try await decoder.decode(url, maxPixelSize: 1000)

        #expect(max(image.pixelSize.width, image.pixelSize.height) <= 1000)
        #expect(image.originalPixelSize == CGSize(width: 4000, height: 3000))
        #expect(image.byteCost > 0)
    }

    @Test("アニメーション GIF だけを animated と判定する")
    func detectsAnimation() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let gif = root.appendingPathComponent("animation.gif")
        let png = root.appendingPathComponent("still.png")
        try ImageFixtures.animatedGIF(at: gif, frames: 4)
        try ImageFixtures.png(at: png, width: 32, height: 32)

        let decoder = ImageDecoder()
        #expect(decoder.isAnimated(gif))
        #expect(!decoder.isAnimated(png))
    }

    @Test("破損ファイルでもクラッシュせずエラーか正常な画像を返す")
    func handlesBrokenFiles() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try FixtureSets.broken(in: root)
        let folder = root.appendingPathComponent("broken", isDirectory: true)
        let decoder = ImageDecoder()

        for name in ["truncated.jpg", "fake.jpg", "empty.mp4"] {
            let url = folder.appendingPathComponent(name)
            do {
                let image = try await decoder.decode(url, maxPixelSize: 512)
                #expect(image.pixelSize.width > 0)
                #expect(image.pixelSize.height > 0)
            } catch {
                continue
            }
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaViewerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
