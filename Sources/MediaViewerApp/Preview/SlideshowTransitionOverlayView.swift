import AppKit
import QuartzCore

/// 前のメディア1枚の写し。入力とアクセシビリティは下の実物へ通す。
@MainActor
final class SlideshowTransitionOverlayView: NSView {
    private let snapshotLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(snapshotLayer)
        setAccessibilityElement(false)
        setAccessibilityChildren([])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show(image: CGImage?, frame: CGRect, gravity: CALayerContentsGravity) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.backgroundColor = NSColor.black.cgColor
        snapshotLayer.frame = frame
        snapshotLayer.contents = image
        snapshotLayer.contentsGravity = gravity
        snapshotLayer.contentsScale = window?.backingScaleFactor ?? 2
        isHidden = false
        CATransaction.commit()
    }

    func clear() {
        isHidden = true
        snapshotLayer.contents = nil
    }
}
