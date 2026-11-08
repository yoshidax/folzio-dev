import CoreGraphics
import Testing
@testable import FolzioCore

@Suite("Swipe navigation")
struct SwipeNavigationTests {
    private static let available = SwipeAvailability(isSwipeTrackingEnabled: true, canGoBack: true, canGoForward: true)
    private static let wideRoom = HorizontalScrollRoom(canRevealLeft: true, canRevealRight: true)
    private static let leftEdgeRoom = HorizontalScrollRoom(canRevealLeft: false, canRevealRight: true)

    private static func sample(
        _ phase: ScrollSample.Phase,
        dx: CGFloat = 0,
        dy: CGFloat = 0,
        momentum: Bool = false,
        at timestamp: Double = 0
    ) -> ScrollSample {
        ScrollSample(phase: phase, isMomentum: momentum, deltaX: dx, deltaY: dy, timestamp: timestamp)
    }

    private static func target(_ pane: Pane = .fileList, _ room: HorizontalScrollRoom = .none) -> SwipeTarget {
        SwipeTarget(pane: pane, room: room)
    }

    // MARK: - HorizontalScrollRoom

    @Test("Room from visible and content ranges, with the 0.5pt edge tolerance (FR-351, EC-243)")
    func roomFromRanges() {
        let middle = HorizontalScrollRoom(visibleMinX: 100, visibleMaxX: 300, contentMinX: 0, contentMaxX: 400)
        #expect(middle.canRevealLeft && middle.canRevealRight)

        let left = HorizontalScrollRoom(visibleMinX: 0, visibleMaxX: 200, contentMinX: 0, contentMaxX: 400)
        #expect(!left.canRevealLeft && left.canRevealRight)

        let right = HorizontalScrollRoom(visibleMinX: 200, visibleMaxX: 400, contentMinX: 0, contentMaxX: 400)
        #expect(right.canRevealLeft && !right.canRevealRight)

        let nearEdges = HorizontalScrollRoom(visibleMinX: 0.5, visibleMaxX: 399.5, contentMinX: 0, contentMaxX: 400)
        #expect(nearEdges == .none)

        let justPastTolerance = HorizontalScrollRoom(visibleMinX: 0.6, visibleMaxX: 399.4, contentMinX: 0, contentMaxX: 400)
        #expect(justPastTolerance.canRevealLeft && justPastTolerance.canRevealRight)

        let narrow = HorizontalScrollRoom(visibleMinX: 0, visibleMaxX: 400, contentMinX: 0, contentMaxX: 300)
        #expect(narrow == .none)
        #expect(narrow.isNone)

        let invalid = HorizontalScrollRoom(visibleMinX: .nan, visibleMaxX: .nan, contentMinX: 0, contentMaxX: 400)
        #expect(invalid == .none)
    }

    @Test("Room allows only the reveal directions that still have hidden content")
    func roomAllows() {
        #expect(Self.leftEdgeRoom.allows(.revealsRight))
        #expect(!Self.leftEdgeRoom.allows(.revealsLeft))
        #expect(!HorizontalScrollRoom.none.allows(.revealsLeft))
        #expect(!HorizontalScrollRoom.none.allows(.revealsRight))
    }

    // MARK: - Direction mapping

    @Test("Each direction comes from a single source")
    func directionMapping() {
        #expect(ScrollReveal(scrollingDeltaX: 3) == .revealsLeft)
        #expect(ScrollReveal(scrollingDeltaX: -3) == .revealsRight)
        #expect(ScrollReveal(scrollingDeltaX: 0) == nil)

        #expect(HistoryDirection(swipeGestureAmount: 0.4) == .back)
        #expect(HistoryDirection(swipeGestureAmount: -0.4) == .forward)
        #expect(HistoryDirection(swipeGestureAmount: 0) == nil)

        #expect(HistoryDirection(swipeEventDeltaX: 1) == .back)
        #expect(HistoryDirection(swipeEventDeltaX: -1) == .forward)
        #expect(HistoryDirection(swipeEventDeltaX: 0) == nil)
    }

    @Test("Maps the raw NSEvent phase bits; stationary is changed and mayBegin is ignored")
    func phaseMapping() {
        #expect(ScrollSample.Phase(eventPhaseRawValue: 0) == ScrollSample.Phase.none)
        #expect(ScrollSample.Phase(eventPhaseRawValue: 0x1) == .began)
        #expect(ScrollSample.Phase(eventPhaseRawValue: 0x2) == .changed)
        #expect(ScrollSample.Phase(eventPhaseRawValue: 0x4) == .changed)
        #expect(ScrollSample.Phase(eventPhaseRawValue: 0x8) == .ended)
        #expect(ScrollSample.Phase(eventPhaseRawValue: 0x10) == .cancelled)
        #expect(ScrollSample.Phase(eventPhaseRawValue: 0x20) == .ignored)
    }

    @Test("Dampen thresholds keep unavailable directions at zero (FR-352, US7-AS21)")
    func dampenThresholds() {
        #expect(Self.available.dampenThresholdMin == -1 && Self.available.dampenThresholdMax == 1)
        let backOnly = SwipeAvailability(isSwipeTrackingEnabled: true, canGoBack: true, canGoForward: false)
        #expect(backOnly.dampenThresholdMin == 0 && backOnly.dampenThresholdMax == 1)
        let forwardOnly = SwipeAvailability(isSwipeTrackingEnabled: true, canGoBack: false, canGoForward: true)
        #expect(forwardOnly.dampenThresholdMin == -1 && forwardOnly.dampenThresholdMax == 0)
    }

    // MARK: - Starting a swipe

    @Test("Starts once on the first horizontal movement at an edge, then consumes the gesture")
    func startsOnceAtEdge() {
        var tracker = SwipeGestureTracker()
        #expect(tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target()) == .passThrough)
        #expect(tracker.handle(Self.sample(.changed, dx: 5, dy: 1), availability: Self.available, target: nil) == .startSwipe)
        #expect(tracker.handle(Self.sample(.changed, dx: 8), availability: Self.available, target: nil) == .consume)
        #expect(tracker.handle(Self.sample(.changed, dx: -8), availability: Self.available, target: nil) == .consume)
    }

    @Test("Decides on the began event when it already carries horizontal movement")
    func decidesOnBegan() {
        var atEdge = SwipeGestureTracker()
        #expect(atEdge.handle(Self.sample(.began, dx: 4), availability: Self.available, target: Self.target()) == .startSwipe)

        var withRoom = SwipeGestureTracker()
        let decision = withRoom.handle(Self.sample(.began, dx: 4), availability: Self.available, target: Self.target(.preview, Self.wideRoom))
        #expect(decision == .passThrough)
        #expect(withRoom.handle(Self.sample(.changed, dx: 4), availability: Self.available, target: nil) == .passThrough)
    }

    @Test("Room recorded at began keeps the whole scroll a scroll, even after reaching the edge (US7-AS18, US7-AS19)")
    func roomKeepsScrolling() {
        var tracker = SwipeGestureTracker()
        let middle = Self.target(.preview, Self.wideRoom)
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: middle)
        #expect(tracker.handle(Self.sample(.changed, dx: 6), availability: Self.available, target: nil) == .passThrough)
        // Later events carry no target; the room observed at began still decides.
        #expect(tracker.handle(Self.sample(.changed, dx: 6), availability: Self.available, target: Self.target()) == .passThrough)
        #expect(tracker.handle(Self.sample(.ended), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.none, dx: 6, momentum: true, at: 1.0), availability: Self.available, target: nil) == .passThrough)
    }

    @Test("A new began at the reached edge starts a swipe; the direction with room still scrolls (US7-AS20)")
    func newBeganAtEdge() {
        var tracker = SwipeGestureTracker()
        let leftEdge = Self.target(.preview, Self.leftEdgeRoom)
        _ = tracker.handle(Self.sample(.began, at: 5), availability: Self.available, target: leftEdge)
        #expect(tracker.handle(Self.sample(.changed, dx: 4, at: 5), availability: Self.available, target: nil) == .startSwipe)

        var opposite = SwipeGestureTracker()
        _ = opposite.handle(Self.sample(.began, at: 5), availability: Self.available, target: leftEdge)
        #expect(opposite.handle(Self.sample(.changed, dx: -4, at: 5), availability: Self.available, target: nil) == .passThrough)
    }

    @Test("Vertical-dominant movement keeps the scroll a scroll; zero movement does not decide (EC-239)")
    func verticalDominant() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        #expect(tracker.handle(Self.sample(.changed), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.changed, dx: 3, dy: 3), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.changed, dx: 9, dy: 0), availability: Self.available, target: nil) == .passThrough)

        var zeroFirst = SwipeGestureTracker()
        _ = zeroFirst.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        #expect(zeroFirst.handle(Self.sample(.changed), availability: Self.available, target: nil) == .passThrough)
        #expect(zeroFirst.handle(Self.sample(.changed, dx: 5, dy: 1), availability: Self.available, target: nil) == .startSwipe)
    }

    @Test("Events outside a gesture pass through")
    func outsideGesture() {
        var tracker = SwipeGestureTracker()
        #expect(tracker.handle(Self.sample(.none, dx: 9), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.changed, dx: 9), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.none, dx: 9, momentum: true), availability: Self.available, target: nil) == .passThrough)
    }

    @Test("The system setting and history availability gate the swipe (FR-350, US7-AS21)")
    func availabilityGates() {
        let disabled = SwipeAvailability(isSwipeTrackingEnabled: false, canGoBack: true, canGoForward: true)
        var off = SwipeGestureTracker()
        _ = off.handle(Self.sample(.began), availability: disabled, target: Self.target())
        #expect(off.handle(Self.sample(.changed, dx: 5), availability: disabled, target: nil) == .passThrough)

        let neither = SwipeAvailability(isSwipeTrackingEnabled: true, canGoBack: false, canGoForward: false)
        var none = SwipeGestureTracker()
        _ = none.handle(Self.sample(.began), availability: neither, target: Self.target())
        #expect(none.handle(Self.sample(.changed, dx: 5), availability: neither, target: nil) == .passThrough)

        let forwardOnly = SwipeAvailability(isSwipeTrackingEnabled: true, canGoBack: false, canGoForward: true)
        var one = SwipeGestureTracker()
        _ = one.handle(Self.sample(.began), availability: forwardOnly, target: Self.target())
        #expect(one.handle(Self.sample(.changed, dx: 5), availability: forwardOnly, target: nil) == .startSwipe)
    }

    @Test("A began outside the target keeps the whole scroll a scroll")
    func outsideTarget() {
        var tracker = SwipeGestureTracker()
        #expect(tracker.handle(Self.sample(.began), availability: Self.available, target: nil) == .passThrough)
        // A target passed with a later event is not used.
        #expect(tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: Self.target()) == .passThrough)
    }

    @Test("Pending without movement returns to idle on ended; wheel events never start a swipe")
    func pendingEnds() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        #expect(tracker.handle(Self.sample(.none, dx: 9), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.ended), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.changed, dx: 9), availability: Self.available, target: nil) == .passThrough)

        var cancelled = SwipeGestureTracker()
        _ = cancelled.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        #expect(cancelled.handle(Self.sample(.cancelled), availability: Self.available, target: nil) == .passThrough)
        #expect(cancelled.handle(Self.sample(.changed, dx: 9), availability: Self.available, target: nil) == .passThrough)
    }

    @Test("mayBegin leaves the state unchanged")
    func ignoredPhase() {
        var tracker = SwipeGestureTracker()
        #expect(tracker.handle(Self.sample(.ignored), availability: Self.available, target: Self.target()) == .passThrough)
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        #expect(tracker.handle(Self.sample(.ignored), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil) == .startSwipe)
    }

    @Test("Wheel events after a scroll pass through")
    func wheelAfterScroll() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        _ = tracker.handle(Self.sample(.changed, dy: 5), availability: Self.available, target: nil)
        _ = tracker.handle(Self.sample(.ended), availability: Self.available, target: nil)
        #expect(tracker.handle(Self.sample(.none, dx: 9), availability: Self.available, target: nil) == .passThrough)
    }

    // MARK: - During and after a swipe

    @Test("While swiping, only the gesture's own ended and cancelled reach the view")
    func swipingPassesEnd() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        _ = tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil)
        #expect(tracker.handle(Self.sample(.none, dx: 5), availability: Self.available, target: nil) == .consume)
        #expect(tracker.handle(Self.sample(.ended), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.none, dx: 5, momentum: true), availability: Self.available, target: nil) == .consume)
        #expect(tracker.handle(Self.sample(.cancelled), availability: Self.available, target: nil) == .passThrough)
    }

    @Test("After finishSwipe, momentum is consumed and the next non-momentum event returns to idle")
    func afterSwipe() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        _ = tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil)
        _ = tracker.handle(Self.sample(.ended), availability: Self.available, target: nil)
        tracker.finishSwipe()
        #expect(tracker.handle(Self.sample(.none, dx: 5, momentum: true), availability: Self.available, target: nil) == .consume)
        #expect(tracker.handle(Self.sample(.none, dy: 5), availability: Self.available, target: nil) == .passThrough)
        #expect(tracker.handle(Self.sample(.none, dx: 5, momentum: true), availability: Self.available, target: nil) == .passThrough)
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        #expect(tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil) == .startSwipe)
    }

    @Test("A began while still swiping re-decides, so an unfinished tracking cannot stick (EC-241)")
    func beganWhileSwiping() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        _ = tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil)
        // finishSwipe() never arrives.
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target(.fileList, Self.wideRoom))
        #expect(tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil) == .passThrough)
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target())
        #expect(tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil) == .startSwipe)
    }

    @Test("finishSwipe outside a swipe does nothing")
    func finishSwipeOutsideSwipe() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began), availability: Self.available, target: Self.target(.preview, Self.wideRoom))
        _ = tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil)
        tracker.finishSwipe()
        #expect(tracker.handle(Self.sample(.changed, dx: 5), availability: Self.available, target: nil) == .passThrough)
    }

    // MARK: - Momentum continuation (FR-351)

    private static func scrollWithMomentum(
        _ tracker: inout SwipeGestureTracker,
        pane: Pane,
        room: HorizontalScrollRoom,
        vertical: Bool = false,
        lastMomentumAt: Double
    ) {
        _ = tracker.handle(sample(.began, at: lastMomentumAt - 1), availability: available, target: target(pane, room))
        let move = vertical ? sample(.changed, dy: 6, at: lastMomentumAt - 1) : sample(.changed, dx: 6, at: lastMomentumAt - 1)
        #expect(tracker.handle(move, availability: available, target: nil) == .passThrough)
        _ = tracker.handle(sample(.ended, at: lastMomentumAt - 0.9), availability: available, target: nil)
        _ = tracker.handle(sample(.none, dx: 4, momentum: true, at: lastMomentumAt), availability: available, target: nil)
    }

    @Test("A scroll begun in the same pane during its momentum stays a scroll, even at the edge")
    func momentumContinuation() {
        var tracker = SwipeGestureTracker()
        Self.scrollWithMomentum(&tracker, pane: .preview, room: Self.wideRoom, lastMomentumAt: 10)
        _ = tracker.handle(Self.sample(.began, at: 10.1), availability: Self.available, target: Self.target(.preview, Self.leftEdgeRoom))
        #expect(tracker.handle(Self.sample(.changed, dx: 5, at: 10.1), availability: Self.available, target: nil) == .passThrough)

        var later = SwipeGestureTracker()
        Self.scrollWithMomentum(&later, pane: .preview, room: Self.wideRoom, lastMomentumAt: 10)
        _ = later.handle(Self.sample(.began, at: 10.2), availability: Self.available, target: Self.target(.preview, Self.leftEdgeRoom))
        #expect(later.handle(Self.sample(.changed, dx: 5, at: 10.2), availability: Self.available, target: nil) == .startSwipe)
    }

    @Test("Momentum of another pane, a vertical-only pane, or a scroll outside the target is not remembered")
    func momentumNotRemembered() {
        var otherPane = SwipeGestureTracker()
        Self.scrollWithMomentum(&otherPane, pane: .preview, room: Self.wideRoom, lastMomentumAt: 10)
        _ = otherPane.handle(Self.sample(.began, at: 10.05), availability: Self.available, target: Self.target(.fileList))
        #expect(otherPane.handle(Self.sample(.changed, dx: 5, at: 10.05), availability: Self.available, target: nil) == .startSwipe)

        var verticalOnly = SwipeGestureTracker()
        Self.scrollWithMomentum(&verticalOnly, pane: .fileList, room: .none, vertical: true, lastMomentumAt: 10)
        _ = verticalOnly.handle(Self.sample(.began, at: 10.05), availability: Self.available, target: Self.target(.fileList))
        #expect(verticalOnly.handle(Self.sample(.changed, dx: 5, at: 10.05), availability: Self.available, target: nil) == .startSwipe)

        var outside = SwipeGestureTracker()
        _ = outside.handle(Self.sample(.began, at: 9), availability: Self.available, target: nil)
        _ = outside.handle(Self.sample(.none, dx: 4, momentum: true, at: 10), availability: Self.available, target: nil)
        _ = outside.handle(Self.sample(.began, at: 10.05), availability: Self.available, target: Self.target(.preview))
        #expect(outside.handle(Self.sample(.changed, dx: 5, at: 10.05), availability: Self.available, target: nil) == .startSwipe)
    }

    @Test("Momentum consumed after a swipe does not block the next swipe (EC-241)")
    func consecutiveSwipes() {
        var tracker = SwipeGestureTracker()
        _ = tracker.handle(Self.sample(.began, at: 9), availability: Self.available, target: Self.target(.preview, Self.leftEdgeRoom))
        _ = tracker.handle(Self.sample(.changed, dx: 5, at: 9), availability: Self.available, target: nil)
        _ = tracker.handle(Self.sample(.ended, at: 9.2), availability: Self.available, target: nil)
        _ = tracker.handle(Self.sample(.none, dx: 4, momentum: true, at: 9.9), availability: Self.available, target: nil)
        tracker.finishSwipe()
        _ = tracker.handle(Self.sample(.none, dx: 3, momentum: true, at: 10), availability: Self.available, target: nil)
        _ = tracker.handle(Self.sample(.began, at: 10.02), availability: Self.available, target: Self.target(.preview, Self.leftEdgeRoom))
        #expect(tracker.handle(Self.sample(.changed, dx: 5, at: 10.02), availability: Self.available, target: nil) == .startSwipe)
    }

    // MARK: - Arrow

    @Test("Arrow state follows the gesture amount (FR-352)")
    func arrowState() {
        let back = SwipeArrowState(gestureAmount: 0.4)
        #expect(back.direction == .back && back.progress == 0.4 && back.isVisible)

        let forward = SwipeArrowState(gestureAmount: -1.7)
        #expect(forward.direction == .forward && forward.progress == 1 && forward.isVisible)

        let zero = SwipeArrowState(gestureAmount: 0)
        #expect(!zero.isVisible && zero.progress == 0)

        let invalid = SwipeArrowState(gestureAmount: .nan)
        #expect(!invalid.isVisible && invalid.progress == 0)

        let discrete = SwipeArrowState.discrete(.forward)
        #expect(discrete.direction == .forward && discrete.progress == 1 && discrete.isVisible)
    }
}
