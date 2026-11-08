import CoreGraphics

// Decisions for Back and Forward by swiping (FR-350 to FR-352). The app layer turns `NSEvent` values into
// `ScrollSample` and hands the decisions to AppKit's swipe tracking; nothing here depends on AppKit.
//
// Each direction comes from a single source:
// - Horizontal scroll room (FR-351): the sign of `scrollingDeltaX`, which follows the system scroll direction
//   setting just like the views' own scrolling.
// - Back and Forward and the arrow (FR-350, FR-352): the sign of the swipe tracking's `gestureAmount`.
// - Three-finger swipes (EC-242): the sign of the swipe event's `deltaX`.

/// The side a horizontal scroll reveals.
public enum ScrollReveal: Sendable, Equatable {
    /// The content moves right and its left part comes into view.
    case revealsLeft
    /// The content moves left and its right part comes into view.
    case revealsRight

    /// Returns `nil` when there is no horizontal movement.
    public init?(scrollingDeltaX: CGFloat) {
        if scrollingDeltaX > 0 {
            self = .revealsLeft
        } else if scrollingDeltaX < 0 {
            self = .revealsRight
        } else {
            return nil
        }
    }
}

/// How far the pane under the pointer can still scroll horizontally (FR-351, EC-243, A-208).
public struct HorizontalScrollRoom: Sendable, Equatable {
    /// Differences up to this many points count as being at the edge.
    public static let edgeTolerance: CGFloat = 0.5

    /// No room in either direction.
    public static let none = HorizontalScrollRoom(canRevealLeft: false, canRevealRight: false)

    /// Whether hidden content remains on the left.
    public let canRevealLeft: Bool
    /// Whether hidden content remains on the right.
    public let canRevealRight: Bool

    public init(canRevealLeft: Bool, canRevealRight: Bool) {
        self.canRevealLeft = canRevealLeft
        self.canRevealRight = canRevealRight
    }

    /// Computes the room from the visible range and the content range. Non-finite values give no room.
    public init(visibleMinX: CGFloat, visibleMaxX: CGFloat, contentMinX: CGFloat, contentMaxX: CGFloat) {
        canRevealLeft = visibleMinX - contentMinX > Self.edgeTolerance
        canRevealRight = contentMaxX - visibleMaxX > Self.edgeTolerance
    }

    /// Whether neither direction can scroll.
    public var isNone: Bool {
        !canRevealLeft && !canRevealRight
    }

    /// Whether the pane can still scroll in the direction.
    public func allows(_ reveal: ScrollReveal) -> Bool {
        switch reveal {
        case .revealsLeft: canRevealLeft
        case .revealsRight: canRevealRight
        }
    }
}

extension HistoryDirection {
    /// Maps the sign of the swipe tracking's `gestureAmount`: positive is Back (research.md R4, checked on a Mac).
    /// Returns `nil` for zero.
    public init?(swipeGestureAmount amount: CGFloat) {
        if amount > 0 {
            self = .back
        } else if amount < 0 {
            self = .forward
        } else {
            return nil
        }
    }

    /// Maps the sign of a three-finger swipe event's `deltaX`: positive is Back (research.md R2, checked on a Mac).
    /// Returns `nil` for zero.
    public init?(swipeEventDeltaX deltaX: CGFloat) {
        if deltaX > 0 {
            self = .back
        } else if deltaX < 0 {
            self = .forward
        } else {
            return nil
        }
    }
}

/// One scroll event, as values the core can decide on.
public struct ScrollSample: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case began
        case changed
        case ended
        case cancelled
        /// Fingers resting before a scroll (`mayBegin`). Leaves the state unchanged.
        case ignored
        /// No gesture phase: mouse wheels and momentum events.
        case none

        /// Maps the raw value of `NSEvent.Phase`. `stationary` counts as `changed` with no movement.
        public init(eventPhaseRawValue raw: UInt) {
            if raw & 0x1 != 0 {
                self = .began
            } else if raw & 0x8 != 0 {
                self = .ended
            } else if raw & 0x10 != 0 {
                self = .cancelled
            } else if raw & (0x4 | 0x2) != 0 {
                self = .changed
            } else if raw & 0x20 != 0 {
                self = .ignored
            } else {
                self = .none
            }
        }
    }

    public var phase: Phase
    /// Whether the event belongs to momentum scrolling.
    public var isMomentum: Bool
    public var deltaX: CGFloat
    public var deltaY: CGFloat
    /// Seconds, comparable between events (`NSEvent.timestamp`).
    public var timestamp: Double

    public init(phase: Phase, isMomentum: Bool, deltaX: CGFloat, deltaY: CGFloat, timestamp: Double) {
        self.phase = phase
        self.isMomentum = isMomentum
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.timestamp = timestamp
    }
}

/// Whether a swipe may start. Whether it may run when it ends is left to the existing guards of Back and Forward
/// (EC-240).
public struct SwipeAvailability: Sendable, Equatable {
    /// Whether the system setting allows swiping between pages with scroll gestures.
    public let isSwipeTrackingEnabled: Bool
    public let canGoBack: Bool
    public let canGoForward: Bool

    public init(isSwipeTrackingEnabled: Bool, canGoBack: Bool, canGoForward: Bool) {
        self.isSwipeTrackingEnabled = isSwipeTrackingEnabled
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }

    /// Lower bound for the swipe tracking. Keeps Forward at zero when it is unavailable (FR-352, US7-AS21).
    public var dampenThresholdMin: CGFloat {
        canGoForward ? -1 : 0
    }

    /// Upper bound for the swipe tracking. Keeps Back at zero when it is unavailable (FR-352, US7-AS21).
    public var dampenThresholdMax: CGFloat {
        canGoBack ? 1 : 0
    }
}

/// The pane under the pointer when a scroll begins, and its horizontal room.
public struct SwipeTarget: Sendable, Equatable {
    public let pane: Pane
    public let room: HorizontalScrollRoom

    public init(pane: Pane, room: HorizontalScrollRoom) {
        self.pane = pane
        self.room = room
    }
}

public enum SwipeDecision: Sendable, Equatable {
    /// Hands the event to the view as usual.
    case passThrough
    /// Starts the swipe tracking with this event and keeps it from the view.
    case startSwipe
    /// Keeps the event from the view.
    case consume
}

/// Decides, per scroll gesture, whether it is a horizontal scroll or a swipe for Back and Forward (FR-351).
///
/// The pane and its room are taken only from the `began` event. A scroll that starts while the same pane is still
/// moving with the momentum of a previous horizontal scroll stays a scroll, so the behavior does not change at
/// the moment the content reaches the edge.
public struct SwipeGestureTracker: Sendable, Equatable {
    /// A `began` this soon after the last passed-through momentum event counts as started during that momentum.
    public static let momentumContinuationInterval: Double = 0.1

    private enum State: Sendable, Equatable {
        case idle
        case pending(SwipeTarget)
        case scrolling(SwipeTarget?)
        case swiping
        case afterSwipe
    }

    private struct MomentumMark: Sendable, Equatable {
        let pane: Pane
        let timestamp: Double
    }

    private var state: State = .idle
    private var lastMomentum: MomentumMark?

    public init() {}

    /// Decides what to do with one scroll event. `target` is read only for `began`; pass `nil` there when the
    /// gesture starts outside the three panes or while swiping is not accepted (EC-244, EC-245).
    public mutating func handle(
        _ sample: ScrollSample,
        availability: SwipeAvailability,
        target: SwipeTarget?
    ) -> SwipeDecision {
        switch sample.phase {
        case .ignored:
            return .passThrough
        case .began:
            return begin(sample, availability: availability, target: target)
        default:
            break
        }

        switch state {
        case .idle:
            return .passThrough
        case .pending(let target):
            switch sample.phase {
            case .ended, .cancelled:
                state = .idle
                return .passThrough
            case .changed where !sample.isMomentum:
                return decide(sample, availability: availability, target: target)
            default:
                // Wheel events never start the swipe tracking.
                return .passThrough
            }
        case .scrolling(let target):
            if sample.isMomentum, let target, !target.room.isNone {
                lastMomentum = MomentumMark(pane: target.pane, timestamp: sample.timestamp)
            }
            return .passThrough
        case .swiping:
            // The view received `began`, so it also gets the end of the gesture.
            if !sample.isMomentum, sample.phase == .ended || sample.phase == .cancelled {
                return .passThrough
            }
            return .consume
        case .afterSwipe:
            // Keeps the remaining momentum from scrolling the new location, but never blocks a mouse wheel.
            if sample.isMomentum {
                return .consume
            }
            state = .idle
            return .passThrough
        }
    }

    /// Called when the swipe tracking reports completion. Does nothing unless a swipe is in progress.
    public mutating func finishSwipe() {
        if state == .swiping {
            state = .afterSwipe
        }
    }

    private mutating func begin(
        _ sample: ScrollSample,
        availability: SwipeAvailability,
        target: SwipeTarget?
    ) -> SwipeDecision {
        guard let target else {
            state = .scrolling(nil)
            return .passThrough
        }
        if let mark = lastMomentum, mark.pane == target.pane {
            let elapsed = sample.timestamp - mark.timestamp
            if elapsed >= 0, elapsed <= Self.momentumContinuationInterval {
                state = .scrolling(target)
                return .passThrough
            }
        }
        state = .pending(target)
        return decide(sample, availability: availability, target: target)
    }

    private mutating func decide(
        _ sample: ScrollSample,
        availability: SwipeAvailability,
        target: SwipeTarget
    ) -> SwipeDecision {
        guard !sample.isMomentum else {
            return .passThrough
        }
        let horizontal = abs(sample.deltaX)
        let vertical = abs(sample.deltaY)
        if horizontal == 0, vertical == 0 {
            return .passThrough
        }
        guard horizontal > vertical, let reveal = ScrollReveal(scrollingDeltaX: sample.deltaX) else {
            state = .scrolling(target)
            return .passThrough
        }
        guard availability.isSwipeTrackingEnabled,
              availability.canGoBack || availability.canGoForward,
              !target.room.allows(reveal) else {
            state = .scrolling(target)
            return .passThrough
        }
        state = .swiping
        return .startSwipe
    }
}

/// The arrow shown while swiping (FR-352). Back is drawn at the left edge pointing left, and Forward at the right
/// edge pointing right, whatever the finger direction or the scroll direction setting.
public struct SwipeArrowState: Sendable, Equatable {
    public let direction: HistoryDirection?
    /// The gesture amount clamped to 0...1. Drives the size and opacity.
    public let progress: CGFloat

    public init(gestureAmount: CGFloat) {
        let direction = HistoryDirection(swipeGestureAmount: gestureAmount)
        self.direction = direction
        progress = direction == nil ? 0 : min(1, abs(gestureAmount))
    }

    private init(direction: HistoryDirection, progress: CGFloat) {
        self.direction = direction
        self.progress = progress
    }

    /// Full arrow for a three-finger swipe, which reports no progress (EC-242).
    public static func discrete(_ direction: HistoryDirection) -> SwipeArrowState {
        SwipeArrowState(direction: direction, progress: 1)
    }

    /// Whether the arrow is shown. Unavailable directions stay at zero and show nothing.
    public var isVisible: Bool {
        direction != nil && progress > 0
    }
}
