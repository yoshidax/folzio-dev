import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("HistoryNavigator")
@MainActor
struct HistoryNavigatorTests {
    @MainActor
    private final class Host: HistoryPresentationHost {
        var presentation = HistoryPresentation(
            displayMode: .list,
            thumbnailSize: ViewSettings.defaultThumbnailSize,
            paneLayout: .all
        )
        var applied: [HistoryPresentation] = []

        var historyPresentation: HistoryPresentation { presentation }

        func applyHistoryPresentation(_ presentation: HistoryPresentation) {
            self.presentation = presentation
            applied.append(presentation)
        }
    }

    @MainActor
    private final class Env {
        let root: URL
        let defaults: UserDefaults
        let suite: String
        let model: BrowserModel
        let navigator: HistoryNavigator
        let host: Host

        init(reader: any ArchiveReading = ZipArchiveReader()) throws {
            var root = FileManager.default.temporaryDirectory
                .appendingPathComponent("HistoryNavigatorTests-\(UUID().uuidString)", isDirectory: true)
            if root.path.hasPrefix("/var/") {
                root = URL(fileURLWithPath: "/private" + root.path, isDirectory: true)
            }
            let fileManager = FileManager.default
            for path in ["A", "A/Sub", "B", "B/Sub", "C", "D"] {
                try fileManager.createDirectory(
                    at: root.appendingPathComponent(path, isDirectory: true),
                    withIntermediateDirectories: true
                )
            }
            try ImageFixtures.jpeg(at: root.appendingPathComponent("A/cover.jpg"), width: 16, height: 12)
            try ImageFixtures.jpeg(at: root.appendingPathComponent("A/Sub/inner.jpg"), width: 16, height: 12)
            try ImageFixtures.jpeg(at: root.appendingPathComponent("B/photo.jpg"), width: 16, height: 12)
            try ImageFixtures.jpeg(at: root.appendingPathComponent("C/photo.jpg"), width: 16, height: 12)
            try ImageFixtures.jpeg(at: root.appendingPathComponent("D/photo.jpg"), width: 16, height: 12)

            let work = fileManager.temporaryDirectory
                .appendingPathComponent("HistoryNavigatorTests-work-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: work) }
            let jpeg = work.appendingPathComponent("photo.jpg")
            try ImageFixtures.jpeg(at: jpeg, width: 16, height: 12)
            for name in ["z1.zip", "z2.zip"] {
                try ZipFixtureWriter.write(
                    [ZipFixtureEntry(name: "sub/photo.jpg", content: .bytes(try Data(contentsOf: jpeg)))],
                    to: root.appendingPathComponent("A/\(name)")
                )
            }
            try ZipFixtureWriter.write(
                [ZipFixtureEntry(name: "photo.jpg", content: .bytes(try Data(contentsOf: jpeg)))],
                to: root.appendingPathComponent("C/broken-source.zip")
            )

            let suite = "HistoryNavigatorTests.\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: suite)!
            defaults.set(true, forKey: "view.showsZipFiles")
            model = BrowserModel(
                lister: DirectoryLister(),
                decoder: ImageDecoder(),
                cache: DecodedImageCache(costLimitBytes: 50_000_000),
                settings: SettingsStore(defaults: defaults),
                archiveReader: reader
            )
            model.setNavigationRoots([root])
            host = Host()
            navigator = HistoryNavigator(model: model)
            navigator.presentationHost = host
            self.root = root
            self.suite = suite
        }

        func url(_ path: String) -> URL {
            root.appendingPathComponent(path, isDirectory: true)
        }

        func select(_ path: String) async {
            await model.selectFolder(url(path))
        }

        func openFolder(_ path: String) async {
            await model.openItem(url(path))
        }

        func openArchiveDirectory(_ name: String) async {
            guard let row = model.listing.files.first(where: { $0.name == name && $0.kind == .directory }) else {
                Issue.record("zip の中のフォルダがありません: \(name)")
                return
            }
            await model.openItem(row.url)
        }

        func openZip(_ name: String) async {
            guard let row = model.listing.files.first(where: { $0.name == name }) else {
                Issue.record("zip の行がありません: \(name)")
                return
            }
            await model.openItem(row.url)
        }

        func goBack() async {
            navigator.goBack()
            await navigator.waitUntilIdle()
            await waitForListing()
        }

        func goForward() async {
            navigator.goForward()
            await navigator.waitUntilIdle()
            await waitForListing()
        }

        func waitForListing() async {
            let deadline = ContinuousClock.now + .seconds(3)
            while model.listing.state == .loading, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(5))
            }
        }

        func cleanup() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    private final class SlowArchiveReader: ArchiveReading, @unchecked Sendable {
        private let base = ZipArchiveReader()
        private let delay: Duration

        init(delay: Duration) {
            self.delay = delay
        }

        func open(_ archive: URL) async throws(ArchiveError) -> ArchiveIndex {
            try? await Task.sleep(for: delay)
            return try await base.open(archive)
        }

        func data(for entryURL: URL, limit: Int) async throws(ArchiveError) -> Data {
            try await base.data(for: entryURL, limit: limit)
        }

        func stream(for entryURL: URL) async throws(ArchiveError) -> ArchiveEntryStream {
            try await base.stream(for: entryURL)
        }

        func identity(of archive: URL) -> ArchiveIdentity? {
            base.identity(of: archive)
        }
    }

    private func path(_ url: URL?) -> String? {
        url?.standardizedFileURL.path
    }

    private func name(_ navigator: HistoryNavigator) -> String? {
        navigator.history.current?.location.folder.lastPathComponent
    }

    private func archiveDirectory(_ navigator: HistoryNavigator) -> String? {
        navigator.history.current?.location.archive?.directory
    }

    @Test("最初の表示は1件だけ記録し、戻る・進むはどちらも使えない（SC-032）")
    func initialRecord() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        #expect(env.navigator.history.count == 1)
        #expect(name(env.navigator) == "A")
        #expect(env.navigator.canGoBack == false)
        #expect(env.navigator.canGoForward == false)
    }

    @Test("A → B → C を戻って進める（US7-AS1・AS2）")
    func backAndForward() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        await env.select("C")
        #expect(env.navigator.history.count == 3)

        await env.goBack()
        #expect(name(env.navigator) == "B")
        await env.goBack()
        #expect(name(env.navigator) == "A")
        #expect(env.navigator.canGoBack == false)
        await env.goForward()
        #expect(name(env.navigator) == "B")
    }

    @Test("戻った後に新しく移ると進む側を消す（US7-AS5）")
    func newNavigationClearsForward() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        await env.select("C")
        await env.goBack()
        await env.goBack()
        #expect(env.navigator.canGoForward)

        await env.select("D")
        #expect(env.navigator.canGoForward == false)
        #expect(name(env.navigator) == "D")
        #expect(env.navigator.history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
    }

    @Test("戻る先が消えていれば飛ばして前の履歴へ移り、その履歴を取り除く（EC-54・SC-030）")
    func skipsMissingBackEntry() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        await env.select("C")
        try FileManager.default.removeItem(at: env.url("B"))

        await env.goBack()
        #expect(name(env.navigator) == "A")
        #expect(env.navigator.history.count == 2)
        #expect(env.navigator.history.forwardEntries.count == 1)

        await env.goForward()
        #expect(name(env.navigator) == "C")
        #expect(env.navigator.canGoForward == false)
    }

    @Test("進む先が消えていても飛ばす（EC-55）")
    func skipsMissingForwardEntry() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        await env.select("C")
        await env.goBack()
        await env.goBack()
        try FileManager.default.removeItem(at: env.url("B"))

        await env.goForward()
        #expect(name(env.navigator) == "C")
        #expect(env.navigator.history.count == 2)
        #expect(env.navigator.history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
    }

    @Test("複数の候補が続けて消えていても、存在する履歴まで飛ばす")
    func skipsSeveralMissingEntries() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        await env.select("D")
        await env.select("C")
        try FileManager.default.removeItem(at: env.url("B"))
        try FileManager.default.removeItem(at: env.url("D"))

        await env.goBack()
        #expect(name(env.navigator) == "A")
        #expect(env.navigator.history.count == 2)
    }

    @Test("表示中のフォルダが消えて現在を取り除いても、戻るで前の履歴へ移れる（EC-65）")
    func removedCurrentStillAllowsBack() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        try FileManager.default.removeItem(at: env.url("B"))

        await env.navigator.revalidateAll()
        #expect(env.navigator.history.current == nil)
        #expect(env.navigator.history.count == 1)

        await env.goBack()
        #expect(name(env.navigator) == "A")
    }

    @Test("外で名前を変えた場所は見つからないので取り除く（EC-57）")
    func externallyRenamedFolderIsRemoved() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        try FileManager.default.moveItem(at: env.url("B"), to: env.url("B2"))

        await env.navigator.revalidateAll()
        #expect(env.navigator.history.current == nil)
        #expect(env.navigator.history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        await env.goBack()
        #expect(name(env.navigator) == "A")
    }

    @Test("表示中のフォルダが消えると親の履歴に置き換わり、隣と同じならまとめる（EC-60）")
    func relocatedReplacesCurrentAndConsolidates() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("A/Sub")
        try FileManager.default.removeItem(at: env.url("A/Sub"))

        await env.model.handleFileSystemEvent([env.url("A/Sub")])
        #expect(path(env.model.listing.folder) == path(env.url("A")))
        #expect(env.navigator.history.count == 1)
        #expect(name(env.navigator) == "A")
        #expect(env.navigator.canGoBack == false)
    }

    @Test("置き換えても進む側は残る（EC-60）")
    func relocatedKeepsForward() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("A/Sub")
        await env.select("C")
        await env.goBack()
        try FileManager.default.removeItem(at: env.url("A/Sub"))

        await env.model.handleFileSystemEvent([env.url("A/Sub")])
        #expect(name(env.navigator) == "A")
        #expect(env.navigator.history.forwardEntries.map(\.location.folder.lastPathComponent) == ["C"])

        await env.goForward()
        #expect(name(env.navigator) == "C")
    }

    @Test("壊れた zip の履歴は飛ばさず、エラーの表示にする（EC-56）")
    func brokenArchiveIsNotSkipped() async throws {
        let env = try Env()
        defer { env.cleanup() }

        let broken = env.url("A").appendingPathComponent("broken.zip")
        try Data("not a zip".utf8).write(to: broken)
        await env.select("A")
        await env.openZip("broken.zip")
        #expect(env.navigator.history.current?.location.archive != nil)
        if case let .failed(message) = env.model.listing.state {
            #expect(message.hasPrefix("zip を開けません: "))
        } else {
            Issue.record("壊れた zip が .failed になっていません: \(env.model.listing.state)")
        }

        await env.goBack()
        #expect(path(env.model.listing.folder) == path(env.url("A")))
        await env.goForward()
        #expect(env.navigator.history.current?.location.archive != nil)
        #expect(env.navigator.canGoBack)
    }

    @Test("検索結果の表示中は戻るで検索を終え、履歴は移らない（US7-AS11）")
    func backEndsSearch() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let count = env.navigator.history.count
        let pattern = try #require(SearchPattern(keyword: "photo"))
        env.model.startSearch(pattern, root: env.root)
        #expect(env.navigator.canGoBack)
        #expect(env.navigator.canGoForward == false)

        await env.goBack()
        #expect(env.model.isShowingSearchResults == false)
        #expect(path(env.model.listing.folder) == path(env.url("A")))
        #expect(env.navigator.history.count == count)
        #expect(env.navigator.canGoBack == false)
    }

    @Test("起動直後の検索でも戻るで検索を終えられる（US7-AS12）")
    func backEndsSearchAtStartup() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let pattern = try #require(SearchPattern(keyword: "photo"))
        env.model.startSearch(pattern, root: env.root)
        #expect(env.navigator.canGoBack)

        await env.goBack()
        #expect(env.model.isShowingSearchResults == false)
        #expect(env.navigator.canGoBack == false)
    }

    @Test("zip の中で始めた検索を終えるとフォルダが新しい履歴になり、もう一度戻ると zip の中へ戻る（US7-AS13・R76）")
    func backEndsSearchInsideArchive() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.openZip("z1.zip")
        await env.openArchiveDirectory("sub")
        #expect(archiveDirectory(env.navigator) == "sub/")

        let pattern = try #require(SearchPattern(keyword: "photo"))
        env.model.startSearch(pattern, root: env.url("A"))
        await env.goBack()
        #expect(env.model.isShowingSearchResults == false)
        #expect(path(env.model.listing.folder) == path(env.url("A")))
        #expect(env.model.listing.archive == nil)
        #expect(env.navigator.canGoBack)

        await env.goBack()
        #expect(env.model.listing.archive?.directory == "sub/")
        #expect(archiveDirectory(env.navigator) == "sub/")
    }

    @Test("名前の変更で現在は新しい場所に置き換わり、ほかの履歴は取り除かれる（EC-61）")
    func renamedFolderUpdatesHistory() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        try FileManager.default.moveItem(at: env.url("B"), to: env.url("B2"))
        env.model.didRenameFolder(from: env.url("B"), to: env.url("B2"))
        env.navigator.didRenameFolder(from: env.url("B"), to: env.url("B2"))

        #expect(name(env.navigator) == "B2")
        #expect(env.navigator.history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
    }

    @Test("ごみ箱に入れた履歴を取り除いても現在は残る（EC-58・FR-109）")
    func removedItemsLeaveCurrent() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        await env.select("C")
        env.navigator.didRemoveItems([env.url("B")])
        #expect(env.navigator.history.count == 2)
        #expect(env.navigator.history.backEntries.map(\.location.folder.lastPathComponent) == ["A"])
        #expect(name(env.navigator) == "C")
    }

    @Test("確認中に場所が変わったら、古い戻る要求を捨てる（R72）")
    func supersededRequestIsDiscarded() async throws {
        let env = try Env(reader: SlowArchiveReader(delay: .milliseconds(300)))
        defer { env.cleanup() }

        await env.select("A")
        await env.openZip("z1.zip")
        await env.goBack()
        #expect(path(env.model.listing.folder) == path(env.url("A")))
        await env.waitForListing()
        await env.openZip("z2.zip")
        await env.goBack()
        #expect(path(env.model.listing.folder) == path(env.url("A")))
        #expect(env.navigator.canGoForward)

        env.navigator.goForward()
        try await Task.sleep(for: .milliseconds(50))
        await env.select("D")
        await env.navigator.waitUntilIdle()

        #expect(name(env.navigator) == "D")
        #expect(env.model.listing.archive == nil)
        #expect(path(env.model.listing.folder) == path(env.url("D")))
    }

    @Test("連打した戻るは1つずつ順に処理し、最終的に2つ前へ移る（R72）")
    func queuedRequestsKeepOrder() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        await env.select("C")

        let start = ContinuousClock.now
        env.navigator.goBack()
        env.navigator.goBack()
        let enqueueElapsed = ContinuousClock.now - start
        #expect(enqueueElapsed < .milliseconds(100), "要求の受付で UI を止めない (実測: \(enqueueElapsed))")

        await env.navigator.waitUntilIdle()
        #expect(name(env.navigator) == "A")
        #expect(env.navigator.history.current?.location.archive == nil)
        #expect(env.navigator.canGoBack == false)
        #expect(env.navigator.canGoForward)
    }

    @Test("確認と読み込みの間も goBack・goForward の呼び出しは 100ms 以上止まらない（SC-029）")
    func navigationCallDoesNotBlock() async throws {
        let env = try Env(reader: SlowArchiveReader(delay: .milliseconds(300)))
        defer { env.cleanup() }

        await env.select("A")
        await env.openZip("z1.zip")
        await env.goBack()

        let start = ContinuousClock.now
        env.navigator.goForward()
        let elapsed = ContinuousClock.now - start
        #expect(elapsed < .milliseconds(100), "goForward の受付は 100ms 未満 (実測: \(elapsed))")

        await env.navigator.waitUntilIdle()
        #expect(env.navigator.history.current?.location.archive != nil)
    }

    @Test("検索結果の表示中と見つからない表示では表示の変更を記録しない（FR-113）")
    func recordViewChangeIgnoresUnavailableLocations() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let pattern = try #require(SearchPattern(keyword: "photo"))
        env.model.startSearch(pattern, root: env.root)
        let count = env.navigator.history.count
        env.navigator.recordViewChange(.viewChange)
        #expect(env.navigator.history.count == count)

        await env.goBack()
        await env.select("Missing")
        let noCurrentCount = env.navigator.history.count
        env.navigator.recordViewChange(.viewChange)
        #expect(env.navigator.history.count == noCurrentCount)
    }

    @Test("presentationHost がないときは表示の変更を記録しない")
    func recordViewChangeNeedsHost() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let count = env.navigator.history.count
        env.navigator.presentationHost = nil
        env.navigator.recordViewChange(.viewChange)
        #expect(env.navigator.history.count == count)
        env.navigator.presentationHost = env.host
    }

    @Test("同じ状態の再設定は記録しない")
    func recordViewChangeIgnoresSameState() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let version = env.navigator.history.version
        env.navigator.recordViewChange(.viewChange)
        env.navigator.recordViewChange(.thumbnailSize)
        #expect(env.navigator.history.version == version)
    }

    @Test("同じ場所の戻るは一覧を作り直さず、表示の状態だけを戻す（US8-AS1・AS5）")
    func sameLocationRestoresPresentation() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let cover = try #require(env.model.listing.files.first { $0.name == "cover.jpg" })
        env.model.select([cover.url], focused: cover.url)
        env.host.presentation = HistoryPresentation(displayMode: .thumbnails, thumbnailSize: 256, paneLayout: .all)
        env.navigator.recordViewChange(.viewChange)
        #expect(env.navigator.history.count == 2)
        #expect(env.navigator.canGoBack)

        let listing = env.model.listing
        await env.goBack()
        #expect(env.host.presentation.displayMode == .list)
        #expect(env.host.presentation.thumbnailSize == 128)
        #expect(env.model.listing.folder == listing.folder)
        #expect(env.model.listing.files == listing.files)
        #expect(env.model.selection.focused == cover.url)
        #expect(env.navigator.canGoForward)
    }

    @Test("場所が変わる戻るは、場所と表示の状態の両方を戻す（US8-AS5）")
    func differentLocationRestoresPresentation() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        env.host.presentation = HistoryPresentation(displayMode: .thumbnails, thumbnailSize: 192, paneLayout: .all)
        env.navigator.recordViewChange(.viewChange)
        await env.select("B")

        await env.goBack()
        #expect(name(env.navigator) == "A")
        #expect(env.host.presentation.displayMode == .thumbnails)
        #expect(env.host.presentation.thumbnailSize == 192)

        await env.goBack()
        #expect(env.host.presentation.displayMode == .list)
        #expect(env.host.presentation.thumbnailSize == 128)
    }

    @Test("種類フィルタ・zip の表示・ペインの表示も戻す（US8-AS3・AS4）")
    func restoresModelAndPaneState() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let initialFilter = env.model.mediaTypeFilter
        let initialZip = env.model.showsZipFiles
        env.model.setMediaTypeFilter(MediaTypeFilter(imagesOnly: true))
        env.model.setShowsZipFiles(false)
        env.host.presentation = HistoryPresentation(displayMode: .list, thumbnailSize: 128, paneLayout: .previewOnly)
        env.navigator.recordViewChange(.viewChange)

        await env.goBack()
        #expect(env.model.mediaTypeFilter == initialFilter)
        #expect(env.model.showsZipFiles == initialZip)
        #expect(env.host.presentation.paneLayout == .all)
        #expect(env.navigator.history.canGoBack == false)
    }

    @Test("検索を終えた後の表示の状態は現在の履歴になる（R76）")
    func searchEndUpdatesCurrentViewState() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let pattern = try #require(SearchPattern(keyword: "photo"))
        env.model.startSearch(pattern, root: env.root)
        env.host.presentation = HistoryPresentation(displayMode: .thumbnails, thumbnailSize: 192, paneLayout: .all)
        env.navigator.recordViewChange(.viewChange)
        #expect(env.navigator.history.current?.viewState.presentation.displayMode == .list)

        await env.goBack()
        #expect(env.navigator.history.current?.viewState.presentation.displayMode == .thumbnails)
        #expect(env.navigator.history.current?.viewState.presentation.thumbnailSize == 192)
    }

    @Test("戻った直後の表示の変更は新しい履歴になり、進む側を消す（US8-AS7）")
    func viewChangeAfterBackClearsForward() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        env.host.presentation = HistoryPresentation(displayMode: .thumbnails, thumbnailSize: 160, paneLayout: .all)
        env.navigator.recordViewChange(.thumbnailSize)
        await env.goBack()
        #expect(env.navigator.canGoForward)

        env.host.presentation = HistoryPresentation(displayMode: .thumbnails, thumbnailSize: 176, paneLayout: .all)
        env.navigator.recordViewChange(.thumbnailSize)
        #expect(env.navigator.canGoForward == false)
        #expect(env.navigator.history.count == 2)
    }

    @Test("見つからなかった移動は記録を取り消し、現在を残さない（EC-62）")
    func missingNavigationRollsBackRecord() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        await env.select("B")
        let missing = env.url("Missing")
        await env.select("Missing")
        #expect(path(env.model.listing.folder) == path(missing))
        #expect(env.navigator.history.current == nil)
        #expect(env.navigator.history.count == 2)

        await env.goBack()
        #expect(name(env.navigator) == "B")
    }

    @Test("検索結果の表示中にフォルダを選ぶと新しい履歴になる（FR-113）")
    func folderSelectedDuringSearchIsRecorded() async throws {
        let env = try Env()
        defer { env.cleanup() }

        await env.select("A")
        let pattern = try #require(SearchPattern(keyword: "photo"))
        env.model.startSearch(pattern, root: env.root)
        await env.select("B")
        #expect(name(env.navigator) == "B")
        #expect(env.navigator.history.count == 2)
    }
}
