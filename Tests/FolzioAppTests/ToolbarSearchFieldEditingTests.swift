import AppKit
import Testing
@testable import FolzioApp

/// Typing in the toolbar name filter field is not renaming (FR-388, TAK-86). Treating it as renaming disabled the
/// field while the user typed in it, which moved the focus to the file list and blocked input methods.
@Suite("Toolbar search field editing", .serialized)
@MainActor
struct ToolbarSearchFieldEditingTests {
    @Test("Editing the toolbar name filter field does not count as renaming")
    func toolbarFieldIsNotRenaming() throws {
        try withWindow(ToolbarSearchField(width: 180)) { window, field in
            #expect(window.makeFirstResponder(field))
            let editor = try #require(window.firstResponder as? NSTextView)
            #expect((editor.delegate as AnyObject?) === field)
            #expect(FileListViewController.isRenaming(firstResponder: editor) == false)
        }
    }

    @Test("Editing another text field, such as a name being renamed, still counts as renaming")
    func otherFieldIsRenaming() throws {
        let rename = NSTextField(string: "original.jpg")
        rename.isEditable = true
        try withWindow(rename) { window, field in
            #expect(window.makeFirstResponder(field))
            let editor = try #require(window.firstResponder as? NSTextView)
            #expect(FileListViewController.isRenaming(firstResponder: editor))
        }
    }

    @Test("No first responder and a non-text responder are not renaming")
    func nonTextResponders() {
        #expect(FileListViewController.isRenaming(firstResponder: nil) == false)
        #expect(FileListViewController.isRenaming(firstResponder: NSView()) == false)
    }

    private func withWindow<Field: NSTextField>(
        _ field: Field,
        body: (NSWindow, Field) throws -> Void
    ) throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 60),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 60))
        window.contentView = container
        field.frame = NSRect(x: 10, y: 20, width: 200, height: 22)
        container.addSubview(field)
        defer {
            window.makeFirstResponder(nil)
            window.close()
        }
        try body(window, field)
    }
}
