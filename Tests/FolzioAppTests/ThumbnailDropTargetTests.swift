import AppKit
import FolzioCore
import Testing
@testable import FolzioApp

@Suite("Thumbnail drop target", .serialized)
@MainActor
struct ThumbnailDropTargetTests {
    @Test("The thumbnail image does not take drops meant for the collection view", arguments: [false, true])
    func thumbnailImageIgnoresDrops(isFolder: Bool) throws {
        _ = NSApplication.shared
        let file = MediaFile(
            url: URL(fileURLWithPath: isFolder ? "/tmp/Album" : "/tmp/original.jpg"),
            name: isFolder ? "Album" : "original.jpg",
            kind: isFolder ? .folder : .media(.jpeg),
            typeDescription: "",
            creationDate: nil,
            fileSize: 0
        )
        let item = ThumbnailItemView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = item.view
        defer { window.close() }

        item.configure(with: file, iconPointSize: 16)

        // Drops on the thumbnail must reach the collection view so that folder items can be drop targets
        // (FR-163, bug: tak-44).
        let imageView = try #require(item.imageView)
        #expect(imageView.registeredDraggedTypes.isEmpty)
    }
}
