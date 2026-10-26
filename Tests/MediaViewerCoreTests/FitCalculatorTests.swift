import CoreGraphics
import Testing
@testable import MediaViewerCore

@Suite("FitCalculator")
struct FitCalculatorTests {
    @Test("横長の画像をコンテナに収める")
    func fitsLandscapeImage() {
        let rect = FitCalculator.fit(
            imageSize: CGSize(width: 2000, height: 1000),
            in: CGSize(width: 500, height: 500)
        )
        #expect(rect == CGRect(x: 0, y: 125, width: 500, height: 250))
    }

    @Test("縦長の画像をコンテナに収める")
    func fitsPortraitImage() {
        let rect = FitCalculator.fit(
            imageSize: CGSize(width: 1000, height: 2000),
            in: CGSize(width: 500, height: 500)
        )
        #expect(rect == CGRect(x: 125, y: 0, width: 250, height: 500))
    }

    @Test("コンテナより小さい横長画像を拡大して中央に置く")
    func enlargesSmallLandscapeImage() {
        let rect = FitCalculator.fit(
            imageSize: CGSize(width: 200, height: 80),
            in: CGSize(width: 500, height: 500)
        )
        #expect(rect == CGRect(x: 0, y: 150, width: 500, height: 200))
    }

    @Test("コンテナより小さい縦長画像を拡大して中央に置く")
    func enlargesSmallPortraitImage() {
        let rect = FitCalculator.fit(
            imageSize: CGSize(width: 80, height: 200),
            in: CGSize(width: 500, height: 500)
        )
        #expect(rect == CGRect(x: 150, y: 0, width: 200, height: 500))
    }

    @Test("1×1 の画像でもコンテナいっぱいまで拡大する")
    func enlargesSinglePixelImage() {
        let rect = FitCalculator.fit(
            imageSize: CGSize(width: 1, height: 1),
            in: CGSize(width: 500, height: 500)
        )
        #expect(rect == CGRect(x: 0, y: 0, width: 500, height: 500))
    }

    @Test("ちょうど収まる画像は同じ大きさで中央に置く")
    func keepsExactFitImageUnchanged() {
        let rect = FitCalculator.fit(
            imageSize: CGSize(width: 500, height: 250),
            in: CGSize(width: 500, height: 500)
        )
        #expect(rect == CGRect(x: 0, y: 125, width: 500, height: 250))
    }

    @Test("0 以下のサイズでは空の矩形を返す", arguments: [
        (CGSize(width: 0, height: 100), CGSize(width: 500, height: 500)),
        (CGSize(width: 100, height: 100), CGSize(width: 0, height: 0)),
        (CGSize(width: -1, height: 100), CGSize(width: 500, height: 500)),
    ])
    func returnsZeroForInvalidSizes(imageSize: CGSize, container: CGSize) {
        #expect(FitCalculator.fit(imageSize: imageSize, in: container) == .zero)
    }

    // MARK: - 倍率の適用（frame(imageSize:in:zoom:)）

    @Test("100%は fit と同じ矩形", arguments: [
        (CGSize(width: 2000, height: 1000), CGSize(width: 500, height: 500)),
        (CGSize(width: 1000, height: 2000), CGSize(width: 500, height: 500)),
        (CGSize(width: 200, height: 80), CGSize(width: 500, height: 500)),
        (CGSize(width: 1, height: 1), CGSize(width: 500, height: 500)),
        (CGSize(width: 500, height: 250), CGSize(width: 500, height: 500)),
    ])
    func fitZoomMatchesFit(imageSize: CGSize, container: CGSize) {
        #expect(
            FitCalculator.frame(imageSize: imageSize, in: container, zoom: .fit)
                == FitCalculator.fit(imageSize: imageSize, in: container)
        )
    }

    @Test("125%はフィットの中心を保ったまま1.25倍にし、はみ出すと原点が負になる")
    func zoomsInAroundCenter() throws {
        let rect = FitCalculator.frame(
            imageSize: CGSize(width: 2000, height: 1000),
            in: CGSize(width: 500, height: 500),
            zoom: try #require(PreviewZoom(percentage: 125))
        )
        #expect(rect == CGRect(x: -62.5, y: 93.75, width: 625, height: 312.5))
    }

    @Test("50%はフィットの半分の大きさで中央に置く")
    func zoomsOutAroundCenter() throws {
        let rect = FitCalculator.frame(
            imageSize: CGSize(width: 2000, height: 1000),
            in: CGSize(width: 500, height: 500),
            zoom: try #require(PreviewZoom(percentage: 50))
        )
        #expect(rect == CGRect(x: 125, y: 187.5, width: 250, height: 125))
    }

    @Test("800%は幅・高さが8倍で、原点が負になる")
    func zoomsToMaximum() throws {
        let rect = FitCalculator.frame(
            imageSize: CGSize(width: 2000, height: 1000),
            in: CGSize(width: 500, height: 500),
            zoom: try #require(PreviewZoom(percentage: 800))
        )
        #expect(rect.width == 4000)
        #expect(rect.height == 2000)
        #expect(rect.minX < 0)
        #expect(rect.minY < 0)
        #expect(rect.midX == 250)
        #expect(rect.midY == 250)
    }

    @Test("1×1 の画像も800%で中央を基準に拡大する")
    func zoomsSinglePixelImage() throws {
        let rect = FitCalculator.frame(
            imageSize: CGSize(width: 1, height: 1),
            in: CGSize(width: 500, height: 500),
            zoom: try #require(PreviewZoom(percentage: 800))
        )
        #expect(rect == CGRect(x: -1750, y: -1750, width: 4000, height: 4000))
    }

    @Test("倍率を付けても0以下のサイズでは空の矩形を返す", arguments: [
        (CGSize(width: 0, height: 100), CGSize(width: 500, height: 500)),
        (CGSize(width: 100, height: 100), CGSize(width: 0, height: 0)),
        (CGSize(width: -1, height: 100), CGSize(width: 500, height: 500)),
    ])
    func zoomedFrameIsZeroForInvalidSizes(imageSize: CGSize, container: CGSize) throws {
        let zoom = try #require(PreviewZoom(percentage: 200))
        #expect(FitCalculator.frame(imageSize: imageSize, in: container, zoom: zoom) == .zero)
    }
}
