import Foundation
import Testing
@testable import MediaViewerCore

// #expect の中では mutating メソッドを呼べないため、結果を変数に受けてから確かめる。
@Suite("PreviewZoomTracker")
struct PreviewZoomTrackerTests {
    private let urlA = URL(fileURLWithPath: "/tmp/zoom/a.jpg")
    private let urlB = URL(fileURLWithPath: "/tmp/zoom/b.jpg")

    @Test("初期状態は100%で画像なし")
    func initialState() {
        let tracker = PreviewZoomTracker()
        #expect(tracker.level == .fit)
        #expect(tracker.imageIdentity == nil)
    }

    @Test("同じ画像の再提示は倍率を保ち、別の画像で100%に戻る")
    func presentKeepsOrResets() {
        var tracker = PreviewZoomTracker()
        let presentedA = tracker.present(urlA)
        #expect(presentedA)
        #expect(tracker.imageIdentity == urlA)
        let presentedAgain = tracker.present(urlA)
        #expect(presentedAgain == false)

        let zoomed = tracker.zoomIn()
        #expect(zoomed)
        let presentedSame = tracker.present(urlA)
        #expect(presentedSame == false)
        #expect(tracker.level.percentage == 125)

        let presentedB = tracker.present(urlB)
        #expect(presentedB)
        #expect(tracker.level == .fit)
        #expect(tracker.imageIdentity == urlB)
    }

    @Test("画像がない状態（空・動画・表示不能）は100%に戻る")
    func presentNilResets() {
        var tracker = PreviewZoomTracker()
        tracker.present(urlA)
        tracker.zoomIn()

        let cleared = tracker.present(nil)
        #expect(cleared)
        #expect(tracker.level == .fit)
        #expect(tracker.imageIdentity == nil)
        let clearedAgain = tracker.present(nil)
        #expect(clearedAgain == false)
    }

    @Test("reset は同じ画像のまま100%に戻す（履歴の移動用）")
    func resetKeepsIdentity() {
        var tracker = PreviewZoomTracker()
        tracker.present(urlA)
        tracker.zoomIn()

        let reset = tracker.reset()
        #expect(reset)
        #expect(tracker.level == .fit)
        #expect(tracker.imageIdentity == urlA)
        let resetAgain = tracker.reset()
        #expect(resetAgain == false)
        #expect(tracker.imageIdentity == urlA)
    }

    @Test("上限・下限での拡大・縮小は値を変えず false を返す")
    func clampsAtLimits() {
        var tracker = PreviewZoomTracker()
        tracker.present(urlA)
        var zoomInCount = 0
        while tracker.zoomIn() {
            zoomInCount += 1
        }
        #expect(zoomInCount == 28)
        #expect(tracker.level.percentage == 800)
        let zoomedPastMaximum = tracker.zoomIn()
        #expect(zoomedPastMaximum == false)
        #expect(tracker.level.percentage == 800)

        tracker.fit()
        var zoomOutCount = 0
        while tracker.zoomOut() {
            zoomOutCount += 1
        }
        #expect(zoomOutCount == 3)
        #expect(tracker.level.percentage == 25)
        let zoomedPastMinimum = tracker.zoomOut()
        #expect(zoomedPastMinimum == false)
        #expect(tracker.level.percentage == 25)
    }

    @Test("fit は100%以外から戻したときだけ true")
    func fitReportsChange() {
        var tracker = PreviewZoomTracker()
        tracker.present(urlA)
        tracker.zoomIn()
        let fitted = tracker.fit()
        #expect(fitted)
        #expect(tracker.level == .fit)
        let fittedAgain = tracker.fit()
        #expect(fittedAgain == false)
    }
}
