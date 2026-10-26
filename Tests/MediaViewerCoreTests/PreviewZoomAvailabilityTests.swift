import Testing
@testable import MediaViewerCore

@Suite("PreviewZoomAvailability")
struct PreviewZoomAvailabilityTests {
    @Test("画像を表示しプレビューが見えていれば、100%で3操作とも使える")
    func availableAtFit() {
        let availability = PreviewZoomAvailability(isImageDisplayed: true, isPreviewVisible: true, level: .fit)
        #expect(availability.isAvailable)
        #expect(availability.canZoomIn)
        #expect(availability.canZoomOut)
        #expect(availability.canFit)
    }

    @Test("800%では拡大だけ、25%では縮小だけが無効")
    func limits() throws {
        let maximum = PreviewZoomAvailability(
            isImageDisplayed: true,
            isPreviewVisible: true,
            level: try #require(PreviewZoom(percentage: 800))
        )
        #expect(maximum.canZoomIn == false)
        #expect(maximum.canZoomOut)
        #expect(maximum.canFit)

        let minimum = PreviewZoomAvailability(
            isImageDisplayed: true,
            isPreviewVisible: true,
            level: try #require(PreviewZoom(percentage: 25))
        )
        #expect(minimum.canZoomOut == false)
        #expect(minimum.canZoomIn)
        #expect(minimum.canFit)
    }

    @Test("画像がない・プレビューが見えないときは倍率にかかわらず3操作とも無効", arguments: [
        (false, true, 100),
        (true, false, 100),
        (false, false, 100),
        (false, true, 800),
        (true, false, 25),
        (false, true, 250),
    ])
    func unavailable(isImageDisplayed: Bool, isPreviewVisible: Bool, percentage: Int) throws {
        let availability = PreviewZoomAvailability(
            isImageDisplayed: isImageDisplayed,
            isPreviewVisible: isPreviewVisible,
            level: try #require(PreviewZoom(percentage: percentage))
        )
        #expect(availability.isAvailable == false)
        #expect(availability.canZoomIn == false)
        #expect(availability.canZoomOut == false)
        #expect(availability.canFit == false)
    }
}
