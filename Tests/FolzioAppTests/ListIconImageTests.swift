import AppKit
import FolzioCore
import Testing
@testable import FolzioApp

@Suite("List icon image", .serialized)
@MainActor
struct ListIconImageTests {
    private func generatedImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        return try #require(context.makeImage())
    }

    @Test(
        "The leading icon keeps the aspect ratio of the generated image within 16 pt (FR-048)",
        arguments: [
            (64, 36, NSSize(width: 16, height: 9)),
            (36, 64, NSSize(width: 9, height: 16)),
            (64, 64, NSSize(width: 16, height: 16)),
            (16, 64, NSSize(width: 4, height: 16)),
            (8, 4, NSSize(width: 16, height: 8)),
        ]
    )
    func keepsAspectRatio(width: Int, height: Int, expected: NSSize) throws {
        let image = try generatedImage(width: width, height: height)
        let icon = ListModeView.listIconImage(from: image, pointSize: 16)
        #expect(icon.size == expected)
    }

    @Test("The badge of a 16:9 frame stays inside the drawn frame of the 16 pt icon (FR-418, EC-286)")
    func badgeStaysInsideWideFrame() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }

        // The same settings as the leading icon of the list mode.
        let imageView = VideoBadgeImageView(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        imageView.imageScaling = .scaleProportionallyDown
        imageView.badgeMetrics = VideoBadgeLayout.listIcon
        window.contentView?.addSubview(imageView)

        let image = try generatedImage(width: 64, height: 36)
        imageView.image = ListModeView.listIconImage(from: image, pointSize: 16)
        imageView.showsVideoBadge = true
        imageView.layoutSubtreeIfNeeded()

        let badge = imageView.videoBadgeView
        #expect(!badge.isHidden)
        let drawn = NSRect(x: 0, y: 3.5, width: 16, height: 9)
        // Pixel alignment may move each edge by up to half a point.
        let tolerance: CGFloat = 0.5
        #expect(badge.frame.minX >= drawn.minX - tolerance)
        #expect(badge.frame.maxX <= drawn.maxX + tolerance)
        #expect(badge.frame.minY >= drawn.minY - tolerance)
        #expect(badge.frame.maxY <= drawn.maxY + tolerance)
    }
}
