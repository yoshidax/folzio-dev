import AppKit
import FolzioCore
import Testing
@testable import FolzioApp

@Suite("Image preview interaction", .serialized)
@MainActor
struct ImagePreviewInteractionTests {
    @Test("Option-arrow chords move diagonally and stop tracking after release", arguments: PreviewInteractionMode.allCases)
    func keyboardDiagonal(mode: PreviewInteractionMode) throws {
        let context = try #require(CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let decoded = DecodedImage(cgImage: image, pixelSize: CGSize(width: 200, height: 200),
                                   originalPixelSize: CGSize(width: 200, height: 200), byteCost: 160_000)
        let view = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        view.interactionMode = mode
        view.showImage(decoded, fileName: "test.png")
        view.applyZoom(try #require(PreviewZoom(percentage: 200)), announce: false)

        func key(_ type: NSEvent.EventType, code: UInt16, character: String,
                 flags: NSEvent.ModifierFlags = .option, isRepeat: Bool = false) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                                         windowNumber: 0, context: nil, characters: character,
                                         charactersIgnoringModifiers: character, isARepeat: isRepeat, keyCode: code))
        }
        let right = "\u{F703}"
        let up = "\u{F700}"
        view.keyDown(with: try key(.keyDown, code: 124, character: right))
        let first = view.transitionSnapshot().frame
        view.keyDown(with: try key(.keyDown, code: 126, character: up))
        let diagonal = view.transitionSnapshot().frame
        #expect(abs(diagonal.minX - first.minX + 40 / sqrt(2)) < 0.001)
        #expect(abs(diagonal.minY - first.minY + 40 / sqrt(2)) < 0.001)
        view.keyDown(with: try key(.keyDown, code: 126, character: up, isRepeat: true))
        #expect(view.transitionSnapshot().frame == diagonal)
        view.keyUp(with: try key(.keyUp, code: 124, character: right))
        view.repeatKeyboardScroll()
        let remaining = view.transitionSnapshot().frame
        #expect(abs(remaining.minX - diagonal.minX) < 0.001)
        #expect(abs(remaining.minY - diagonal.minY + 40) < 0.001)
        view.flagsChanged(with: try key(.flagsChanged, code: 58, character: "", flags: []))
        view.repeatKeyboardScroll()
        #expect(view.transitionSnapshot().frame == remaining)
        view.keyUp(with: try key(.keyUp, code: 126, character: up))
        view.keyDown(with: try key(.keyDown, code: 124, character: right))
        let beforeFocusLoss = view.transitionSnapshot().frame
        #expect(abs(beforeFocusLoss.minX + 200) < 0.001)
        view.repeatKeyboardScroll()
        #expect(view.transitionSnapshot().frame == beforeFocusLoss)
        #expect(view.resignFirstResponder())
        view.repeatKeyboardScroll()
        #expect(view.transitionSnapshot().frame == beforeFocusLoss)
        view.keyDown(with: try key(.keyDown, code: 124, character: right, flags: []))
        #expect(view.transitionSnapshot().frame == beforeFocusLoss)
        view.showEmpty()
    }

    @Test("Wheel zoom animates geometry and direct input cancels the animation")
    func wheelZoomAnimation() throws {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let context = try #require(CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let decoded = DecodedImage(cgImage: image, pixelSize: CGSize(width: 200, height: 200),
                                   originalPixelSize: CGSize(width: 200, height: 200), byteCost: 160_000)
        let view = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        view.showImage(decoded, fileName: "test.png")
        let imageLayer = try #require(view.layer?.sublayers?.first { $0.contents != nil })
        view.applyZoom(try #require(PreviewZoom(percentage: 110)), announce: false,
                       anchor: CGPoint(x: 100, y: 100), animateWheel: true)
        let animation = try #require(imageLayer.animation(forKey: "wheelZoom") as? CAAnimationGroup)
        #expect(animation.duration == 0.12)
        #expect(Set((animation.animations ?? []).compactMap { ($0 as? CABasicAnimation)?.keyPath }) == ["position", "bounds"])
        view.applyZoom(try #require(PreviewZoom(percentage: 120)), announce: false,
                       anchor: CGPoint(x: 100, y: 100))
        #expect(imageLayer.animation(forKey: "wheelZoom") == nil)
    }

    @Test("Dragging pans an image in the pointer direction")
    func dragPans() throws {
        let context = try #require(CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let decoded = DecodedImage(cgImage: image, pixelSize: CGSize(width: 200, height: 200),
                                   originalPixelSize: CGSize(width: 200, height: 200), byteCost: 160_000)
        let view = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        view.showImage(decoded, fileName: "test.png")
        view.applyZoom(try #require(PreviewZoom(percentage: 200)), announce: false)
        let before = view.transitionSnapshot().frame
        func event(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                                             windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try event(.leftMouseDown, CGPoint(x: 100, y: 100)))
        view.mouseDragged(with: try event(.leftMouseDragged, CGPoint(x: 120, y: 110)))
        view.mouseUp(with: try event(.leftMouseUp, CGPoint(x: 120, y: 110)))
        let after = view.transitionSnapshot().frame
        #expect(abs(after.minX - before.minX - 20) < 0.001)
        #expect(abs(after.minY - before.minY - 10) < 0.001)
        let imageLayer = try #require(view.layer?.sublayers?.first { $0.contents != nil })
        #expect(imageLayer.animationKeys()?.isEmpty ?? true)
    }

    @Test("Switching interaction modes changes scrollers without moving the image")
    func switchingMode() throws {
        let context = try #require(CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let decoded = DecodedImage(cgImage: image, pixelSize: CGSize(width: 200, height: 200),
                                   originalPixelSize: CGSize(width: 200, height: 200), byteCost: 160_000)
        let view = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        view.showImage(decoded, fileName: "test.png")
        view.applyZoom(try #require(PreviewZoom(percentage: 200)), announce: false)
        view.layoutSubtreeIfNeeded()
        let before = view.transitionSnapshot().frame
        let scrollers = view.subviews.compactMap { $0 as? NSScroller }
        #expect(scrollers.count == 2)
        #expect(scrollers.allSatisfy { $0.isHidden })
        view.interactionMode = .scroll
        view.layoutSubtreeIfNeeded()
        #expect(scrollers.allSatisfy { !$0.isHidden })
        #expect(view.transitionSnapshot().frame == before)
        view.interactionMode = .wheelZoomPan
        view.layoutSubtreeIfNeeded()
        #expect(scrollers.allSatisfy { $0.isHidden })
        #expect(view.transitionSnapshot().frame == before)
    }
}
