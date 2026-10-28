import CoreGraphics
import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SlideshowTransitionState")
struct SlideshowTransitionStateTests {
    let a = URL(fileURLWithPath: "/a.jpg")
    let b = URL(fileURLWithPath: "/b.mp4")
    let c = URL(fileURLWithPath: "/c.jpg")

    private func holding() -> SlideshowTransitionState {
        var state = SlideshowTransitionState()
        let action = state.reduce(.arm(target: b, current: a, effect: .slide))
        #expect(action == .hold(replacing: false))
        #expect(state.phase == .holding)
        #expect(state.targetURL == b)
        #expect(state.effect == .slide)
        #expect(state.generation == 1)
        return state
    }

    private func animating() -> SlideshowTransitionState {
        var state = holding()
        let action = state.reduce(.ready(url: b, generation: state.generation))
        #expect(action == .animate(effect: .slide, generation: state.generation))
        #expect(state.phase == .animating)
        return state
    }

    @Test("同じ対象と効果なしでは arm せず、動画を止める action も出さない")
    func ignoresUnneededArm() {
        var state = SlideshowTransitionState()
        let same = state.reduce(.arm(target: a, current: a, effect: .crossfade))
        #expect(same == .none)
        let none = state.reduce(.arm(target: b, current: a, effect: .none))
        #expect(none == .none)
        #expect(state.phase == .idle)
        #expect(state.targetURL == nil)
    }

    @Test("準備中の表示では待ち、対象の再表示で準備完了を判定し直す")
    func waitsForTarget() {
        var state = holding()
        for content: PreviewContent in [.loading(b), .animatedImage(b), .animatedImageData(b, Data()), .video(b)] {
            let action = state.reduce(.displayed(content: content, focused: b))
            #expect(action == .none)
            #expect(state.phase == .holding)
        }
        let action = state.reduce(.displayed(content: .unavailable(name: "b", reason: .unreadable), focused: b))
        #expect(action == .animate(effect: .slide, generation: state.generation))
        #expect(state.phase == .animating)
    }

    @Test("表示の URL を持たないケースはフォーカスを使い、別の対象なら打ち切る", arguments: [false, true])
    func otherContentCancels(animated: Bool) {
        for content: PreviewContent in [.loading(c), .video(c), .animatedImage(c), .animatedImageData(c, Data()), .empty] {
            var state = animated ? animating() : holding()
            let generation = state.generation
            let action = state.reduce(.displayed(content: content, focused: c))
            #expect(action == .remove(completed: false))
            #expect(state.phase == .idle)
            #expect(state.generation > generation)
        }
    }

    @Test("効果中の同じ対象の再表示と準備完了は無視し、現世代の完了でだけ外す")
    func completesOnce() {
        var state = animating()
        let generation = state.generation
        for content: PreviewContent in [.video(b), .empty, .unavailable(name: "b", reason: .unreadable)] {
            let repeated = state.reduce(.displayed(content: content, focused: b))
            #expect(repeated == .none)
            #expect(state.phase == .animating)
        }
        let ready = state.reduce(.ready(url: b, generation: generation))
        #expect(ready == .none)
        let stale = state.reduce(.completed(generation: generation - 1))
        #expect(stale == .none)
        let completed = state.reduce(.completed(generation: generation))
        #expect(completed == .remove(completed: true))
        #expect(state.phase == .idle)
        #expect(state.targetURL == nil)
        let repeated = state.reduce(.completed(generation: generation))
        #expect(repeated == .none)
    }

    @Test("新しい arm は古い効果を置き換え、古い通知を無視する", arguments: [false, true])
    func replaces(animated: Bool) {
        var state = animated ? animating() : holding()
        let old = state.generation
        let action = state.reduce(.arm(target: b, current: a, effect: .zoom))
        #expect(action == .hold(replacing: true))
        #expect(state.phase == .holding)
        #expect(state.generation > old)
        let staleReady = state.reduce(.ready(url: b, generation: old))
        #expect(staleReady == .none)
        let other = state.reduce(.ready(url: c, generation: state.generation))
        #expect(other == .none)
        let staleCompletion = state.reduce(.completed(generation: old))
        #expect(staleCompletion == .none)
        let ready = state.reduce(.ready(url: b, generation: state.generation))
        #expect(ready == .animate(effect: .zoom, generation: state.generation))
    }

    @Test("同じ対象・効果なしの arm、矢印や終了、リサイズは効果を打ち切る", arguments: [false, true])
    func cancels(animated: Bool) {
        let events: [SlideshowTransitionState.Event] = [
            .arm(target: b, current: b, effect: .slide),
            .arm(target: c, current: b, effect: .none), .cancel, .containerResized,
        ]
        for event in events {
            var state = animated ? animating() : holding()
            let old = state.generation
            let action = state.reduce(event)
            #expect(action == .remove(completed: false))
            #expect(state.phase == .idle)
            #expect(state.generation > old)
            let late = state.reduce(.ready(url: b, generation: old))
            #expect(late == .none)
        }
        var idle = SlideshowTransitionState()
        let cancel = idle.reduce(.cancel)
        let resize = idle.reduce(.containerResized)
        let ready = idle.reduce(.ready(url: b, generation: 0))
        #expect(cancel == .none)
        #expect(resize == .none)
        #expect(ready == .none)
    }

    @Test("すべての PreviewContent の準備完了判定")
    func readiness() throws {
        let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let decoded = DecodedImage(cgImage: image, pixelSize: CGSize(width: 1, height: 1),
            originalPixelSize: CGSize(width: 1, height: 1), byteCost: 4)
        for content: PreviewContent in [.image(decoded), .empty, .unavailable(name: "a", reason: .unreadable)] {
            #expect(SlideshowTransitionState.readiness(of: content) == .ready)
            var state = holding()
            let action = state.reduce(.displayed(content: content, focused: b))
            #expect(action == .animate(effect: .slide, generation: state.generation))
        }
        for content: PreviewContent in [.loading(b), .animatedImage(b), .animatedImageData(b, Data()), .video(b)] {
            #expect(SlideshowTransitionState.readiness(of: content) == .pending)
        }
    }
}
