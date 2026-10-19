import Testing
@testable import MediaViewerCore

@Suite("ThumbnailGridLayout")
struct ThumbnailGridLayoutTests {
    @Test("どの幅・サイズ・間隔でも横スクロールしない")
    func fitsWithinAvailableWidth() {
        let tolerance = 0.0001
        var firstFailure: String?

        for width in 0...2000 where firstFailure == nil {
            for thumbnailSize in 48...512 where firstFailure == nil {
                for spacing in [0.0, 8.0, 20.0] where firstFailure == nil {
                    let availableWidth = Double(width)
                    let size = Double(thumbnailSize)
                    let layout = ThumbnailGridLayout.columns(
                        availableWidth: availableWidth,
                        thumbnailSize: size,
                        spacing: spacing
                    )
                    let usedWidth = Double(layout.count) * layout.cellWidth
                        + Double(layout.count - 1) * spacing

                    if layout.count < 1
                        || layout.cellWidth < 0
                        || layout.cellWidth > availableWidth + tolerance
                        || usedWidth > availableWidth + tolerance {
                        firstFailure = """
                            width=\(width), thumbnailSize=\(thumbnailSize), spacing=\(spacing), \
                            count=\(layout.count), cellWidth=\(layout.cellWidth), used=\(usedWidth)
                            """
                    }
                }
            }
        }

        #expect(firstFailure == nil, Comment(rawValue: firstFailure ?? ""))
    }

    @Test("狭い幅では1列にしてセル幅を縮める")
    func shrinksSingleCellToFitNarrowWidth() {
        let layout = ThumbnailGridLayout.columns(availableWidth: 10, thumbnailSize: 100, spacing: 20)
        #expect(layout.count == 1)
        #expect(layout.cellWidth == 10)
    }

    @Test("間隔が幅より大きくても収まる")
    func handlesSpacingWiderThanAvailableWidth() {
        let layout = ThumbnailGridLayout.columns(availableWidth: 10, thumbnailSize: 10, spacing: 50)
        #expect(layout.count == 1)
        #expect(layout.cellWidth == 10)
        #expect(Double(layout.count) * layout.cellWidth <= 10)
    }

    @Test("幅が0以下ならセル幅0")
    func returnsZeroCellWidthForNonPositiveWidth() {
        let zero = ThumbnailGridLayout.columns(availableWidth: 0, thumbnailSize: 100, spacing: 8)
        #expect(zero.count == 1)
        #expect(zero.cellWidth == 0)

        let negative = ThumbnailGridLayout.columns(availableWidth: -50, thumbnailSize: 100, spacing: 8)
        #expect(negative.count == 1)
        #expect(negative.cellWidth == 0)
    }

    @Test("サムネイルサイズが0以下なら1列で幅いっぱい")
    func returnsFullWidthForNonPositiveThumbnailSize() {
        let zero = ThumbnailGridLayout.columns(availableWidth: 300, thumbnailSize: 0, spacing: 8)
        #expect(zero.count == 1)
        #expect(zero.cellWidth == 300)

        let negative = ThumbnailGridLayout.columns(availableWidth: 300, thumbnailSize: -10, spacing: 8)
        #expect(negative.count == 1)
        #expect(negative.cellWidth == 300)
    }

    @Test("負の間隔は0として扱う")
    func treatsNegativeSpacingAsZero() {
        let layout = ThumbnailGridLayout.columns(availableWidth: 1000, thumbnailSize: 200, spacing: -10)
        #expect(layout.count == 5)
        #expect(layout.cellWidth == 200)
    }

    @Test("間隔を含めた列数を計算する")
    func computesColumnCountWithSpacing() {
        let layout = ThumbnailGridLayout.columns(availableWidth: 1000, thumbnailSize: 200, spacing: 20)
        #expect(layout.count == 4)
        #expect(layout.cellWidth == 200)
        #expect(Double(layout.count) * layout.cellWidth + Double(layout.count - 1) * 20 <= 1000)
    }

    @Test("ちょうど収まる幅では列数が最大になる")
    func fitsExactColumns() {
        let layout = ThumbnailGridLayout.columns(availableWidth: 1000, thumbnailSize: 200, spacing: 0)
        #expect(layout.count == 5)
        #expect(layout.cellWidth == 200)
    }

    @Test("非有限値でも安全な値を返す")
    func handlesNonFiniteValues() {
        let infinity = ThumbnailGridLayout.columns(availableWidth: .infinity, thumbnailSize: 100, spacing: 8)
        #expect(infinity.count == 1)
        #expect(infinity.cellWidth == 0)

        let nan = ThumbnailGridLayout.columns(availableWidth: .nan, thumbnailSize: 100, spacing: 8)
        #expect(nan.count == 1)
        #expect(nan.cellWidth == 0)

        let nanSpacing = ThumbnailGridLayout.columns(availableWidth: 1000, thumbnailSize: 200, spacing: .nan)
        #expect(nanSpacing.count == 5)
        #expect(nanSpacing.cellWidth == 200)
    }
}
