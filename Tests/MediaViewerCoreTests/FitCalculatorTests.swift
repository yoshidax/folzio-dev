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
}
