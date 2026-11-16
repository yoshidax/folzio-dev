import AppKit
import FolzioCore
import Testing
@testable import FolzioApp

@Suite("File list context click", .serialized)
@MainActor
struct FileListContextClickTests {
    enum Mode: CaseIterable, Sendable {
        case list, thumbnails
    }

    private struct Fixture {
        let model: BrowserModel
        let urls: [String: URL]
        /// Context-clicks the item named `name` (nil for the background) in the view of `mode`.
        let contextClick: (String?) -> Void
    }

    @Test("A context click on an unselected item selects only that item (FR-397, SC-219)", arguments: Mode.allCases)
    func unselectedItemBecomesTheSelection(_ mode: Mode) async throws {
        try await withFixture(mode, selected: ["a.png"]) { fixture in
            fixture.contextClick("b.png")
            let b = try #require(fixture.urls["b.png"])
            #expect(fixture.model.selection.selected == [b])
            #expect(fixture.model.selection.focused == b)
        }
    }

    @Test("A context click on a selected item keeps the multiple selection (SC-220)", arguments: Mode.allCases)
    func selectedItemKeepsTheSelection(_ mode: Mode) async throws {
        try await withFixture(mode, selected: ["a.png", "b.png", "c.png"]) { fixture in
            let before = fixture.model.selection
            fixture.contextClick("b.png")
            #expect(fixture.model.selection.selected == before.selected)
            #expect(fixture.model.selection.focused == before.focused)
            #expect(fixture.model.selection.selected.count == 3)
        }
    }

    @Test("A context click on the background keeps the selection (FR-213)", arguments: Mode.allCases)
    func backgroundKeepsTheSelection(_ mode: Mode) async throws {
        try await withFixture(mode, selected: ["a.png"]) { fixture in
            let before = fixture.model.selection
            fixture.contextClick(nil)
            #expect(fixture.model.selection.selected == before.selected)
            #expect(fixture.model.selection.focused == before.focused)
        }
    }

    private func withFixture(
        _ mode: Mode,
        selected: [String],
        _ body: @MainActor (Fixture) async throws -> Void
    ) async throws {
        _ = NSApplication.shared
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("folzio-context-click-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["a.png", "b.png", "c.png"] {
            try Data().write(to: folder.appendingPathComponent(name))
        }

        let suite = "Folzio.ContextClick.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        let model = BrowserModel(kindNames: l10n.kindNames, lister: DirectoryLister(kindNames: l10n.kindNames),
            decoder: ImageDecoder(), cache: DecodedImageCache(), settings: settings)
        await model.selectFolder(folder)
        let files = model.listing.files
        var urls: [String: URL] = [:]
        for file in files { urls[file.url.lastPathComponent] = file.url }
        let selectedURLs = Set(try selected.map { try #require(urls[$0]) })
        model.select(selectedURLs, focused: selectedURLs.max { $0.path < $1.path })

        func index(of name: String?) -> Int? {
            name.flatMap { name in files.firstIndex { $0.url.lastPathComponent == name } }
        }
        // The views apply the model's listing and selection when created.
        let provider = ThumbnailProvider()
        let contextClick: (String?) -> Void
        switch mode {
        case .list:
            let view = ListModeView(model: model, provider: provider)
            contextClick = { view.selectForContextClick(row: index(of: $0) ?? -1) }
        case .thumbnails:
            let view = ThumbnailModeView(model: model, provider: provider)
            contextClick = { view.selectForContextClick(item: index(of: $0)) }
        }
        try await body(Fixture(model: model, urls: urls, contextClick: contextClick))
    }
}
