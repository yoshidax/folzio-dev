import CoreGraphics
import Testing
@testable import MediaViewerCore

@Suite("PreviewZoom")
struct PreviewZoomTests {
    @Test("刻み・上下限・フィットの定数")
    func constants() {
        #expect(PreviewZoom.step == 25)
        #expect(PreviewZoom.minimum == 25)
        #expect(PreviewZoom.maximum == 800)
        #expect(PreviewZoom.fit.percentage == 100)
    }

    @Test("25〜800 の25の倍数だけを受け付ける", arguments: [25, 50, 100, 775, 800])
    func acceptsValidPercentages(percentage: Int) {
        #expect(PreviewZoom(percentage: percentage)?.percentage == percentage)
    }

    @Test("範囲外・25の倍数でない値は作れない", arguments: [0, -25, 30, 101, 799, 801])
    func rejectsInvalidPercentages(percentage: Int) {
        #expect(PreviewZoom(percentage: percentage) == nil)
    }

    @Test("scale は百分率を100で割った値")
    func scale() throws {
        #expect(try #require(PreviewZoom(percentage: 25)).scale == 0.25)
        #expect(PreviewZoom.fit.scale == 1.0)
        #expect(try #require(PreviewZoom(percentage: 800)).scale == 8.0)
    }

    @Test("拡大は25ポイントの加算で、800%で止まる")
    func zoomsIn() throws {
        let first = PreviewZoom.fit.zoomedIn()
        #expect(first.percentage == 125)
        #expect(first.zoomedIn().percentage == 150)

        let maximum = try #require(PreviewZoom(percentage: 800))
        #expect(maximum.zoomedIn() == maximum)
    }

    @Test("縮小は25ポイントの減算で、25%で止まる")
    func zoomsOut() throws {
        var zoom = try #require(PreviewZoom(percentage: 150))
        var steps: [Int] = []
        for _ in 0..<5 {
            zoom = zoom.zoomedOut()
            steps.append(zoom.percentage)
        }
        #expect(steps == [125, 100, 75, 50, 25])
        #expect(zoom.zoomedOut() == zoom)
    }

    @Test("100%から28回の拡大で800%になり、それ以上は変わらない")
    func reachesMaximumAfterTwentyEightSteps() {
        var zoom = PreviewZoom.fit
        for _ in 0..<28 {
            zoom = zoom.zoomedIn()
        }
        #expect(zoom.percentage == 800)
        #expect(zoom.zoomedIn().percentage == 800)
    }

    @Test("上限・下限での可否")
    func canZoom() throws {
        #expect(try #require(PreviewZoom(percentage: 800)).canZoomIn == false)
        #expect(try #require(PreviewZoom(percentage: 775)).canZoomIn)
        #expect(try #require(PreviewZoom(percentage: 25)).canZoomOut == false)
        #expect(try #require(PreviewZoom(percentage: 50)).canZoomOut)
    }

    @Test("百分率の順に比較できる")
    func comparable() throws {
        let small = try #require(PreviewZoom(percentage: 75))
        let large = try #require(PreviewZoom(percentage: 125))
        #expect(small < .fit)
        #expect(PreviewZoom.fit < large)
        #expect(!(large < small))
    }
}
