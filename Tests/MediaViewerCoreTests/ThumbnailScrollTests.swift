import Testing
@testable import MediaViewerCore

@Suite("ThumbnailScroll")
struct ThumbnailScrollTests {
    @Test("ビューポートの下にある項目は最小限スクロールする")
    func scrollsDownToItemBelowViewport() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 120,
            itemMaxY: 220,
            visibleMinY: 0,
            visibleHeight: 100,
            contentHeight: 500
        )
        #expect(offset == 120)
        #expect(offset != 0)
    }

    @Test("ビューポートの上にある項目は上端に合わせる")
    func scrollsUpToItemAboveViewport() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 30,
            itemMaxY: 80,
            visibleMinY: 40,
            visibleHeight: 100,
            contentHeight: 500
        )
        #expect(offset == 30)
    }

    @Test("下側が部分的に見えている項目は項目全体が見える位置までスクロールする")
    func scrollsDownForPartiallyVisibleItem() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 80,
            itemMaxY: 130,
            visibleMinY: 0,
            visibleHeight: 100,
            contentHeight: 500
        )
        #expect(offset == 30)
    }

    @Test("上側が部分的に見えている項目は項目全体が見える位置までスクロールする")
    func scrollsUpForPartiallyVisibleItem() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 20,
            itemMaxY: 60,
            visibleMinY: 40,
            visibleHeight: 100,
            contentHeight: 500
        )
        #expect(offset == 20)
    }

    @Test("既に全体が見えている項目ではスクロールしない")
    func keepsOffsetForVisibleItem() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 30,
            itemMaxY: 80,
            visibleMinY: 0,
            visibleHeight: 100,
            contentHeight: 500
        )
        #expect(offset == 0)
    }

    @Test("末尾では最大スクロール位置にクランプする")
    func clampsAtBottom() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 190,
            itemMaxY: 220,
            visibleMinY: 0,
            visibleHeight: 100,
            contentHeight: 200
        )
        #expect(offset == 100)
    }

    @Test("先頭では 0 にクランプする")
    func clampsAtTop() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 0,
            itemMaxY: 40,
            visibleMinY: 70,
            visibleHeight: 100,
            contentHeight: 200
        )
        #expect(offset == 0)
    }

    @Test("ビューポートより高い項目は上端を合わせる")
    func alignsTopForTallerItem() {
        let offset = ThumbnailScroll.offsetY(
            itemMinY: 10,
            itemMaxY: 310,
            visibleMinY: 0,
            visibleHeight: 100,
            contentHeight: 400
        )
        #expect(offset == 10)
    }

    @Test("不正な寸法では現在の原点を返す")
    func returnsCurrentOriginForInvalidValues() {
        #expect(ThumbnailScroll.offsetY(
            itemMinY: 10,
            itemMaxY: 20,
            visibleMinY: 5,
            visibleHeight: 0,
            contentHeight: 100
        ) == 5)
        #expect(ThumbnailScroll.offsetY(
            itemMinY: 10,
            itemMaxY: 20,
            visibleMinY: 5,
            visibleHeight: -1,
            contentHeight: 100
        ) == 5)
        #expect(ThumbnailScroll.offsetY(
            itemMinY: 10,
            itemMaxY: 20,
            visibleMinY: 5,
            visibleHeight: Double.nan,
            contentHeight: 100
        ) == 5)
        #expect(ThumbnailScroll.offsetY(
            itemMinY: 10,
            itemMaxY: 20,
            visibleMinY: 5,
            visibleHeight: 100,
            contentHeight: .infinity
        ) == 5)
        #expect(ThumbnailScroll.offsetY(
            itemMinY: 10,
            itemMaxY: 20,
            visibleMinY: 5,
            visibleHeight: 100,
            contentHeight: -1
        ) == 5)
    }
}
