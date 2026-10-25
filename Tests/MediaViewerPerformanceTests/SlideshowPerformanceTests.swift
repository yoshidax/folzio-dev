import Foundation
import Testing
@testable import MediaViewerCore

// 既存の PerformanceBaseline スイート（.serialized）へ追加する。
// 別スイートにすると Swift Testing が既存の性能試験と並列実行し、
// 一時的な CPU 競合で 10〜20 万件の閾値を超えることがあるため。
extension PerformanceBaselineTests {
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
        #expect(elapsed < .milliseconds(50), "対象抽出と次位置探索は 50ms 未満 (実測: \(elapsed))")
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
        #expect(elapsed < .milliseconds(100), "対象抽出は 100ms 未満 (実測: \(elapsed))")
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
        #expect(elapsed < .milliseconds(200), "対象抽出は 200ms 未満 (実測: \(elapsed))")
        print("[perf] slideshow sequence 200,000: \(elapsed)")
    }

    @Test("任意 now の20周期で期限のずれが蓄積しない")
    func slideshowTwentyCyclesDoNotDrift() {
        let interval = Duration.seconds(3)
        var session = SlideshowSession(interval: interval)
        var now = ContinuousClock.now
        session.start(now: now)
        let started = now

        for _ in 0..<20 {
            now = now.advanced(by: interval)
            let due = session.timeout(now: now)
            #expect(due)
            let committed = session.commit(now: now)
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
