import Foundation
import Testing
import FixtureKit
@testable import FolzioCore

// Temporary diagnostic: breaks down the cost of didRenameFolder with 10,101 search results. Not a baseline.
@Suite("RenameBreakdownDiagnostics", .serialized)
struct RenameBreakdownDiagnostics {
    @Test("Breaks down the didRenameFolder cost (diagnostic, always passes)")
    @MainActor
    func breakDownRenameCost() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolzioRenameDiagnostics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FixtureSets.huge(in: directory, count: 10_000)
        let seeded = directory.appendingPathComponent("huge", isDirectory: true)
        for index in 0 ..< 100 {
            try FileManager.default.createDirectory(
                at: seeded.appendingPathComponent(String(format: "img-folder-%03d", index), isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        let folder = directory.appendingPathComponent("img-huge", isDirectory: true)
        try FileManager.default.moveItem(at: seeded, to: folder)

        let suite = "RenameBreakdownDiagnostics.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = BrowserModel(
            kindNames: FixtureKit.kindNames,
            lister: DirectoryLister(kindNames: FixtureKit.kindNames),
            decoder: ImageDecoder(),
            cache: DecodedImageCache(),
            settings: SettingsStore(defaults: defaults)
        )
        model.startSearch(try #require(SearchPattern(keyword: "img")), root: directory)
        let deadline = ContinuousClock.now + .seconds(30)
        while model.listing.search?.phase != .finished, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let files = model.listing.files
        let renamed = RenamedFolder(from: folder, to: directory.appendingPathComponent("img-huge2", isDirectory: true))
        let order = model.sortOrder

        func measure(_ label: String, _ body: () -> Void) {
            var samples: [Duration] = []
            for _ in 0 ..< 3 {
                let start = ContinuousClock.now
                body()
                samples.append(ContinuousClock.now - start)
            }
            print("[diag] \(label): median \(samples.sorted()[1]), samples \(samples)")
        }

        print("[diag] rows \(files.count), sort \(order)")
        measure("sorted(10,101 rows) by current order") { _ = sorted(files, by: order) }
        var compareCount = 0
        measure("10,101 x name.localizedStandardCompare(neighbor)") {
            for index in 1 ..< files.count {
                if files[index - 1].name.localizedStandardCompare(files[index].name) == .orderedAscending {
                    compareCount += 1
                }
            }
        }
        measure("RenamedFolder.rebase over 10,101 rows (map with copy)") {
            _ = files.map { file -> MediaFile in
                guard let url = renamed.rebase(file.url) else { return file }
                var moved = file
                moved.url = url
                return moved
            }
        }
        let moves = files.compactMap { file in renamed.rebase(file.url).map { (file.url, $0) } }
        measure("Dictionary of 10,101 moves") { _ = Dictionary(moves, uniquingKeysWith: { first, _ in first }) }
        let moved = Dictionary(moves, uniquingKeysWith: { first, _ in first })
        let index = Dictionary(grouping: files.map(\.url), by: { $0.deletingLastPathComponent().standardizedFileURL.path })
            .mapValues(Set.init)
        measure("rebuild index of 10,101 URLs (lookup + Set union)") {
            var rebuilt: [String: Set<URL>] = [:]
            for (key, urls) in index {
                rebuilt[key, default: []].formUnion(urls.map { moved[$0] ?? renamed.rebaseOrSelf($0) })
            }
            _ = rebuilt
        }
        var rootToggle = false
        measure("rebuildListing via setNavigationRoots") {
            rootToggle.toggle()
            model.setNavigationRoots([directory.appendingPathComponent(rootToggle ? "a" : "b", isDirectory: true)])
        }
        var current = folder
        for name in ["img-huge2", "img-huge", "img-huge2"] {
            let next = directory.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.moveItem(at: current, to: next)
            let start = ContinuousClock.now
            model.didRenameFolder(from: current, to: next)
            print("[diag] didRenameFolder total (\(name)): \(ContinuousClock.now - start)")
            current = next
        }
        #expect(compareCount >= 0)
    }
}
