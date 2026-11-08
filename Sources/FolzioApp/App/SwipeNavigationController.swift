import AppKit
import FolzioCore

/// Runs Back and Forward from the system "Swipe between pages" gestures over the three panes (FR-350 to FR-352).
///
/// Two-finger and Magic Mouse swipes arrive as scroll events and are handed to AppKit's swipe tracking when
/// `SwipeGestureTracker` decides so. Three-finger swipes arrive as one swipe event. Whether Back or Forward may run
/// when a swipe ends is left to the guards of `goBack(_:)` and `goForward(_:)` (EC-240).
@MainActor
final class SwipeNavigationController {
    struct Hooks {
        /// The main window. Events of other windows are left alone.
        var window: @MainActor () -> NSWindow?
        /// The root views of the three panes, which are the targets of swiping (EC-245).
        var paneViews: @MainActor () -> [(pane: Pane, view: NSView)]
        /// Whether Back and Forward are available now, as for ⌘[ and ⌘] (FR-112, FR-113).
        var availability: @MainActor () -> (canGoBack: Bool, canGoForward: Bool)
        var goBack: @MainActor () -> Void
        var goForward: @MainActor () -> Void
    }

    private let hooks: Hooks
    private var monitor: Any?
    private var tracker = SwipeGestureTracker()
    /// Identifies the current swipe tracking. Handler calls of an older tracking are ignored.
    private var trackingGeneration = 0
    /// The last nonzero gesture amount of the current tracking. Its sign decides Back or Forward.
    private var lastGestureAmount: CGFloat = 0

    init(hooks: Hooks) {
        self.hooks = hooks
    }

    /// Starts watching scroll and swipe events. The monitor lives as long as the main window's controller,
    /// like the other event monitors of `MainSplitViewController`.
    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                self?.consumes(event) ?? false
            }
            return consumed ? nil : event
        }
    }

    /// Returns whether the event is kept from the views.
    private func consumes(_ event: NSEvent) -> Bool {
        guard let window = hooks.window(), event.window === window else { return false }
        switch event.type {
        case .scrollWheel:
            return handleScroll(event, in: window)
        case .swipe:
            return handleThreeFingerSwipe(event, in: window)
        default:
            return false
        }
    }

    // MARK: - Two-finger and Magic Mouse swipes

    private func handleScroll(_ event: NSEvent, in window: NSWindow) -> Bool {
        let sample = ScrollSample(
            phase: ScrollSample.Phase(eventPhaseRawValue: event.phase.rawValue),
            isMomentum: !event.momentumPhase.isEmpty,
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            timestamp: event.timestamp
        )
        var target: SwipeTarget?
        if sample.phase == .began {
            // A new gesture: handler calls of an earlier tracking no longer apply.
            trackingGeneration += 1
            target = swipeTarget(for: event, in: window)
        }
        let availability = currentAvailability()
        let decision = tracker.handle(sample, availability: availability, target: target)
        // Temporary log for the on-device checks Q1 to Q4 (tasks.md T009). Removed in T012.
        if decision != .passThrough || sample.phase == .began || sample.phase == .ended {
            NSLog(
                "[TAK-85] scroll phase=%@ momentum=%@ dx=%.2f dy=%.2f decision=%@",
                String(describing: sample.phase), String(sample.isMomentum), sample.deltaX, sample.deltaY,
                String(describing: decision)
            )
        }
        switch decision {
        case .passThrough:
            return false
        case .consume:
            return true
        case .startSwipe:
            startTracking(event, availability: availability)
            return true
        }
    }

    private func startTracking(_ event: NSEvent, availability: SwipeAvailability) {
        trackingGeneration += 1
        let generation = trackingGeneration
        lastGestureAmount = 0
        event.trackSwipeEvent(
            options: [.lockDirection, .clampGestureAmount],
            dampenAmountThresholdMin: availability.dampenThresholdMin,
            max: availability.dampenThresholdMax
        ) { [weak self] gestureAmount, phase, isComplete, stop in
            // AppKit calls this on the main thread during event handling, but the closure is not isolated.
            let shouldStop = MainActor.assumeIsolated { () -> Bool in
                guard let self, generation == self.trackingGeneration else { return true }
                self.trackingDidUpdate(gestureAmount: gestureAmount, phase: phase, isComplete: isComplete)
                return false
            }
            if shouldStop {
                stop.pointee = true
            }
        }
    }

    private func trackingDidUpdate(gestureAmount: CGFloat, phase: NSEvent.Phase, isComplete: Bool) {
        if gestureAmount != 0 {
            lastGestureAmount = gestureAmount
        }
        NSLog(
            "[TAK-85] tracking amount=%.3f phase=%lu complete=%@",
            gestureAmount, phase.rawValue, String(isComplete)
        )
        if phase == .ended, let direction = HistoryDirection(swipeGestureAmount: lastGestureAmount) {
            // The guards of Back and Forward decide whether it still runs (EC-240).
            navigate(direction)
        }
        if isComplete {
            tracker.finishSwipe()
        }
    }

    // MARK: - Three-finger swipes

    private func handleThreeFingerSwipe(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard swipeTarget(for: event, in: window) != nil,
              let direction = HistoryDirection(swipeEventDeltaX: event.deltaX) else {
            return false
        }
        let available = hooks.availability()
        let canRun = direction == .back ? available.canGoBack : available.canGoForward
        NSLog("[TAK-85] swipe event dx=%.2f direction=%@ run=%@", event.deltaX, String(describing: direction), String(canRun))
        guard canRun else { return false }
        navigate(direction)
        return true
    }

    // MARK: - Shared

    private func navigate(_ direction: HistoryDirection) {
        switch direction {
        case .back: hooks.goBack()
        case .forward: hooks.goForward()
        }
    }

    private func currentAvailability() -> SwipeAvailability {
        let available = hooks.availability()
        return SwipeAvailability(
            isSwipeTrackingEnabled: NSEvent.isSwipeTrackingFromScrollEventsEnabled,
            canGoBack: available.canGoBack,
            canGoForward: available.canGoForward
        )
    }

    /// The pane under the pointer when a gesture begins, or `nil` while swiping is not accepted there
    /// (EC-244, EC-245).
    private func swipeTarget(for event: NSEvent, in window: NSWindow) -> SwipeTarget? {
        guard window.isKeyWindow,
              window.attachedSheet == nil,
              NSApp.modalWindow == nil,
              NSEvent.pressedMouseButtons == 0,
              let contentView = window.contentView,
              let frameView = contentView.superview else {
            return nil
        }
        // `hitTest(_:)` takes a point in the superview's coordinate system.
        let point = frameView.convert(event.locationInWindow, from: nil)
        guard let hitView = contentView.hitTest(point) else { return nil }
        guard let match = hooks.paneViews().first(where: { hitView.isDescendant(of: $0.view) }) else { return nil }
        return SwipeTarget(pane: match.pane, room: .none)
    }
}
