import AppKit
import FolzioCore
import Testing

@Suite("Swipe event mapping")
struct SwipeEventMappingTests {
    @Test("The core phase mapping matches the raw values of NSEvent.Phase")
    func phaseRawValues() {
        #expect(ScrollSample.Phase(eventPhaseRawValue: NSEvent.Phase.began.rawValue) == .began)
        #expect(ScrollSample.Phase(eventPhaseRawValue: NSEvent.Phase.stationary.rawValue) == .changed)
        #expect(ScrollSample.Phase(eventPhaseRawValue: NSEvent.Phase.changed.rawValue) == .changed)
        #expect(ScrollSample.Phase(eventPhaseRawValue: NSEvent.Phase.ended.rawValue) == .ended)
        #expect(ScrollSample.Phase(eventPhaseRawValue: NSEvent.Phase.cancelled.rawValue) == .cancelled)
        #expect(ScrollSample.Phase(eventPhaseRawValue: NSEvent.Phase.mayBegin.rawValue) == .ignored)
        #expect(ScrollSample.Phase(eventPhaseRawValue: NSEvent.Phase().rawValue) == ScrollSample.Phase.none)
    }
}
