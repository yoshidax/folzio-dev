import AVFoundation
import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

/// `VideoFixtures` は書き出しの間スレッドをブロックする。並列に走らせると協調スレッドを使い切って止まるため、直列にする
@Suite("ArchiveAssetLoader", .serialized)
struct ArchiveAssetLoaderTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let method: ZipFixtureEntry.Method
        let methodLabel: String
        var testDescription: String { "\(name) (\(methodLabel))" }
    }

    /// mp4 と mov（再生用の情報が末尾）を、無圧縮と deflate で格納する 4 通り
    private static let cases: [Case] = [
        Case(name: "clip.mp4", method: .stored, methodLabel: "stored"),
        Case(name: "clip.mp4", method: .deflated, methodLabel: "deflated"),
        Case(name: "clip.mov", method: .stored, methodLabel: "stored"),
        Case(name: "clip.mov", method: .deflated, methodLabel: "deflated"),
    ]

    private struct Prepared {
        let original: URL
        let zip: URL
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveAssetLoaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 動画を作って zip に格納する。mov・mp4 とも fastStart: false（再生用の情報が末尾）
    private func prepare(_ testCase: Case, in directory: URL) throws -> Prepared {
        let original = directory.appendingPathComponent(testCase.name)
        if testCase.name.hasSuffix(".mov") {
            try VideoFixtures.mov(at: original, fastStart: false)
        } else {
            try VideoFixtures.mp4(at: original, fastStart: false)
        }
        let zip = directory.appendingPathComponent("video.zip")
        try ZipFixtureWriter.write([
            ZipFixtureEntry(name: testCase.name, content: .bytes(try Data(contentsOf: original)), method: testCase.method),
            ZipFixtureEntry(
                name: "secret.mp4", content: .bytes(try Data(contentsOf: original)), encryptedFlag: true
            ),
        ], to: zip)
        return Prepared(original: original, zip: zip)
    }

    @Test("asset の duration が元のファイルと一致し、動画のトラックがある", arguments: cases)
    func durationAndTracks(testCase: Case) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let prepared = try prepare(testCase, in: directory)
        let reader = ZipArchiveReader()
        _ = try await reader.open(prepared.zip)

        let asset = ArchiveAssetFactory.makeAsset(
            for: ArchiveURL.entry(archive: prepared.zip, path: testCase.name), reader: reader
        )
        let duration = try await asset.load(.duration)
        let expected = try await AVURLAsset(url: prepared.original).load(.duration)
        #expect(duration == expected)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(!tracks.isEmpty)
    }

    @Test("AVAssetImageGenerator が先頭のフレームを返す", arguments: cases)
    func firstFrame(testCase: Case) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let prepared = try prepare(testCase, in: directory)
        let reader = ZipArchiveReader()
        _ = try await reader.open(prepared.zip)

        let asset = ArchiveAssetFactory.makeAsset(
            for: ArchiveURL.entry(archive: prepared.zip, path: testCase.name), reader: reader
        )
        let generator = AVAssetImageGenerator(asset: asset)
        let result = try await generator.image(at: .zero)
        #expect(result.image.width > 0)
    }

    @Test("asset を作った関数を抜けて、読み込み器を外から保持しなくても読み込みが完了する")
    func loaderIsRetainedByAsset() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let testCase = Self.cases[1]
        let prepared = try prepare(testCase, in: directory)
        let url = ArchiveURL.entry(archive: prepared.zip, path: testCase.name)

        // reader も読み込み器もこの関数の中で手放し、asset だけを返す
        let asset: AVURLAsset = try await {
            let reader = ZipArchiveReader()
            _ = try await reader.open(prepared.zip)
            return ArchiveAssetFactory.makeAsset(for: url, reader: reader)
        }()
        let duration = try await asset.load(.duration)
        #expect(duration.seconds > 0)
    }

    @Test("暗号化の項目の asset では load(.duration) が失敗する")
    func encryptedEntryFails() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let prepared = try prepare(Self.cases[0], in: directory)
        let reader = ZipArchiveReader()
        _ = try await reader.open(prepared.zip)

        let asset = ArchiveAssetFactory.makeAsset(
            for: ArchiveURL.entry(archive: prepared.zip, path: "secret.mp4"), reader: reader
        )
        await #expect(throws: (any Error).self) {
            _ = try await asset.load(.duration)
        }
    }
}
