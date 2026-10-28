import Foundation
import CoreGraphics
import AVFoundation
import FixtureKit
import Testing
@testable import MediaViewerCore

// Add to the existing PerformanceBaseline suite (.serialized).
// A separate suite would make Swift Testing run it in parallel with the existing performance tests, and temporary CPU
// contention could exceed the 100,000–200,000-item thresholds.
extension PerformanceBaselineTests {
    @Test("video output 付きのプレーヤーが1秒以内に最初のフレームを返す")
    @MainActor
    func slideshowVideoOutputFirstFrameWithinBudget() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SlideshowVideoPerformance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("clip.mp4")
        try await Task.detached {
            try VideoFixtures.mp4(at: url, seconds: 1, fastStart: true)
        }.value
        let playback = VideoPlayback()
        defer { playback.unload() }
        let start = ContinuousClock.now
        playback.load(asset: AVURLAsset(url: url), loop: false)
        playback.player.play()
        var firstFrame: CGImage?
        while ContinuousClock.now - start < .seconds(2) {
            firstFrame = playback.currentFrame()
            if firstFrame != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let elapsed = ContinuousClock.now - start
        #expect(firstFrame != nil)
        #expect(elapsed < .seconds(1), "First frame of video output (measured: \(elapsed))")
        print("[perf] slideshow video output first frame: \(elapsed)")
    }

    @Test("10,000 件の通常／検索相当一覧で対象抽出と次位置探索が 50ms 未満")
    func slideshowTenThousandWithinBudget() {
        let files = slideshowSyntheticResults(count: 10_000, folders: 100)
        let focused = files[7_777].url

        let start = ContinuousClock.now
        let candidates = SlideshowSequence.candidates(in: files)
        let startTarget = SlideshowSequence.startTarget(
            in: files,
            selected: [focused],
            focused: focused
        )
        let nextTarget = SlideshowSequence.nextTarget(in: files, focused: focused)
        let elapsed = ContinuousClock.now - start

        #expect(candidates.count == 10_000)
        #expect(startTarget == focused)
        #expect(nextTarget == files[7_778].url)
        #expect(elapsed < .milliseconds(50), "Candidate extraction and next-position lookup take less than 50 ms (measured: \(elapsed))")
        print("[perf] slideshow sequence 10,000: \(elapsed)")
    }

    @Test("50,000 件の一覧からスライドショーの対象抽出が 100ms 未満")
    func slideshowFiftyThousandWithinBudget() {
        let files = slideshowSyntheticResults(count: 50_000, folders: 500)
        let index = 25_000
        let selected = Set([files[index].url])

        let start = ContinuousClock.now
        let candidates = SlideshowSequence.candidates(in: files)
        let startTarget = SlideshowSequence.startTarget(
            in: files,
            selected: selected,
            focused: files[index].url
        )
        let nextTarget = SlideshowSequence.nextTarget(in: files, focused: files[index].url)
        let elapsed = ContinuousClock.now - start

        #expect(candidates.count == 50_000)
        #expect(startTarget == files[index].url)
        #expect(nextTarget == files[index + 1].url)
        #expect(elapsed < .milliseconds(100), "Candidate extraction takes less than 100 ms (measured: \(elapsed))")
        print("[perf] slideshow sequence 50,000: \(elapsed)")
    }

    @Test("200,000 件の zip 一覧相当からスライドショーの対象抽出が 200ms 未満")
    func slideshowTwoHundredThousandWithinBudget() {
        let files = slideshowSyntheticResults(count: 200_000, folders: 2_000)
        let focused = files[123_456].url

        let start = ContinuousClock.now
        let candidates = SlideshowSequence.candidates(in: files)
        let nextTarget = SlideshowSequence.nextTarget(in: files, focused: focused)
        let elapsed = ContinuousClock.now - start

        #expect(candidates.count == 200_000)
        #expect(nextTarget == files[123_457].url)
        #expect(elapsed < .milliseconds(200), "Candidate extraction takes less than 200 ms (measured: \(elapsed))")
        print("[perf] slideshow sequence 200,000: \(elapsed)")
    }

    @Test("任意 now の20周期で期限のずれが蓄積しない")
    func slideshowTwentyCyclesDoNotDrift() {
        let interval = Duration.seconds(3)
        var session = SlideshowSession()
        var now = ContinuousClock.now
        session.start(now: now, interval: interval)
        let started = now

        for _ in 0..<20 {
            now = now.advanced(by: interval)
            let due = session.timeout(now: now)
            #expect(due)
            let committed = session.commit(now: now, interval: interval)
            #expect(committed)
        }

        let expectedDeadline = started.advanced(by: interval * 21)
        #expect(session.deadline == expectedDeadline)
    }

    private func slideshowSyntheticResults(count: Int, folders: Int) -> [MediaFile] {
        (0..<count).map { index in
            let folder = "/r/folder-\(index % folders)"
            let name = String(format: "photo_%06d.jpg", index)
            return MediaFile(
                url: URL(fileURLWithPath: "\(folder)/\(name)"),
                name: name,
                kind: .media(.jpeg),
                typeDescription: "JPEG イメージ",
                creationDate: nil,
                fileSize: 0
            )
        }
    }
}
