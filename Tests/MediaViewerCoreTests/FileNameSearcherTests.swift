import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("FileNameSearcher", .serialized)
struct FileNameSearcherTests {
    private struct Env {
        let base: URL
        let root: URL

        func cleanup() {
            try? FileManager.default.removeItem(at: base)
        }
    }

    private func makeEnv() throws -> Env {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileNameSearcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try FixtureSets.search(in: base)
        return Env(base: base, root: base.appendingPathComponent("search", isDirectory: true))
    }

    private func collect(
        _ searcher: FileNameSearcher = FileNameSearcher(kindNames: FixtureKit.kindNames),
        in root: URL,
        _ keyword: String
    ) async throws -> [[MediaFile]] {
        let pattern = try #require(SearchPattern(keyword: keyword))
        var batches: [[MediaFile]] = []
        for await batch in searcher.search(in: root, matching: pattern) {
            batches.append(batch)
        }
        return batches
    }

    /// 起点からの相対パス（NFC にそろえる）。結果の URL が起点と同じ形で始まることも確かめる
    private func relativePaths(_ files: [MediaFile], root: URL) -> Set<String> {
        Set(files.map { file in
            #expect(file.url.path.hasPrefix(root.path + "/"), "起点と違う形の URL: \(file.url.path)")
            return String(file.url.path.dropFirst(root.path.count + 1)).precomposedStringWithCanonicalMapping
        })
    }

    // MARK: - フォルダの照合（US15）

    private struct FolderSearchEnv {
        let base: URL
        let root: URL

        func cleanup() {
            try? FileManager.default.removeItem(at: base)
        }
    }

    private func makeFolderSearchEnv() throws -> FolderSearchEnv {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileNameSearcherTests-folder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try FixtureSets.folderSearch(in: base)
        return FolderSearchEnv(
            base: base,
            root: base.appendingPathComponent("folder-search/Kyoto", isDirectory: true)
        )
    }

    @Test("名前が一致するフォルダをファイルと同じ結果に返し、隠し・パッケージ・フォルダへのリンク・zip・起点を除く")
    func folderSearchMatchesFolders() async throws {
        let env = try makeFolderSearchEnv()
        defer { env.cleanup() }

        let results = try await collect(in: env.root, "kyoto").flatMap { $0 }
        #expect(relativePaths(results, root: env.root) == [
            "2024_Kyoto",
            "2024_Kyoto_old",
            "clips/kyoto_clip.mov",
            "east/kyoto_day1",
            "kyoto",
            "kyoto/kyoto_01.jpg",
            "kyoto/kyoto_day2",
            "kyoto_map.png",
            "locked_kyoto",
            "locked_kyoto/secret_kyoto.jpg",
            "west/kyoto_day1",
        ])
        // 隠しフォルダ・パッケージ・フォルダへのリンク・zip ファイル・起点そのもの・一致しない中のファイル
        for excluded in [
            ".kyoto", "Kyoto.app", "kyoto_link", "kyoto.zip",
            "2024_Kyoto/IMG_0001.jpg", "kyoto/IMG_0002.jpg", ".",
        ] {
            #expect(
                !relativePaths(results, root: env.root).contains(excluded),
                "行になっている: \(excluded)"
            )
        }

        func kind(_ relative: String) -> ListItemKind? {
            results.first { file in
                String(file.url.path.dropFirst(env.root.path.count + 1)) == relative
            }?.kind
        }
        #expect(kind("2024_Kyoto") == .folder)
        #expect(kind("kyoto") == .folder)
        #expect(kind("east/kyoto_day1") == .folder)
        #expect(kind("kyoto_map.png") == .media(.png))
        #expect(kind("clips/kyoto_clip.mov") == .media(.mov))
    }

    @Test("ワイルドカードはフォルダ名の全体と照合し、「.」を拡張子として扱わない")
    func folderSearchWildcardsAndDots() async throws {
        let env = try makeFolderSearchEnv()
        defer { env.cleanup() }

        // 名前全体との一致（ワイルドカードあり）。大文字小文字は区別しないため `locked_kyoto` も一致し、
        // 途中に一致する `2024_Kyoto_old` は一致しない（US15-AS2）
        let kyoto2024 = try await collect(in: env.root, "*_Kyoto").flatMap { $0 }
        #expect(relativePaths(kyoto2024, root: env.root) == ["2024_Kyoto", "locked_kyoto"])
        #expect(!relativePaths(kyoto2024, root: env.root).contains("2024_Kyoto_old"))

        let dotted = try await collect(in: env.root, "2024.10").flatMap { $0 }
        #expect(relativePaths(dotted, root: env.root) == ["2024.10_trip"])

        let jpgFolders = try await collect(in: env.root, "*.jpg").flatMap { $0 }
        let photoFolder = try #require(jpgFolders.first { $0.name == "photos.jpg" })
        #expect(photoFolder.kind == .folder)
        #expect(jpgFolders.contains { $0.name == "kyoto_01.jpg" && $0.kind == .media(.jpeg) })
        #expect(!jpgFolders.contains { $0.name.hasSuffix(".png") })
    }

    @Test("権限のないフォルダは名前が一致すれば行になり、中は辿らない（EC-33・EC-91）")
    func folderSearchUnreadableFolder() async throws {
        let env = try makeFolderSearchEnv()
        defer { env.cleanup() }

        let locked = env.root.appendingPathComponent("locked_kyoto", isDirectory: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let results = try await collect(in: env.root, "kyoto").flatMap { $0 }
        #expect(results.contains { $0.name == "locked_kyoto" && $0.kind == .folder })
        #expect(!results.contains { $0.name == "secret_kyoto.jpg" })
    }

    @Test("フォルダの行の値は DirectoryLister のフォルダの行と同じ")
    func folderRowValuesMatchLister() async throws {
        let env = try makeFolderSearchEnv()
        defer { env.cleanup() }

        let results = try await collect(in: env.root, "kyoto").flatMap { $0 }
        let row = try #require(results.first { $0.name == "kyoto_day1" && $0.url.deletingLastPathComponent().lastPathComponent == "east" })
        #expect(row.kind == .folder)
        #expect(row.typeDescription == FixtureKit.kindNames.folder)
        #expect(row.fileSize == 0)

        let listed = try #require(
            try await DirectoryLister(kindNames: FixtureKit.kindNames).mediaFiles(in: env.root.appendingPathComponent("east", isDirectory: true))
                .first { $0.name == "kyoto_day1" }
        )
        #expect(row.creationDate == listed.creationDate)
        #expect(row.name == listed.name)
        #expect(row.typeDescription == listed.typeDescription)
        #expect(row.fileSize == listed.fileSize)
        // 結果の URL は起点の形（/var/... の起点なら /var/...）で、起点以下を指す
        #expect(row.url.path.hasPrefix(env.root.path + "/"))
    }

    @Test("matchesRoot が true のときだけ起点そのものを照合し、隠し属性とパッケージの起点は行にしない")
    func matchesRootOption() async throws {
        let env = try makeFolderSearchEnv()
        defer { env.cleanup() }
        let pattern = try #require(SearchPattern(keyword: "kyoto"))
        let kyoto2024 = env.root.appendingPathComponent("2024_Kyoto", isDirectory: true)

        func search(root: URL, matchesRoot: Bool) async -> [MediaFile] {
            var found: [MediaFile] = []
            for await batch in FileNameSearcher(kindNames: FixtureKit.kindNames).search(
                SearchRequest(root: root, pattern: pattern, matchesRoot: matchesRoot)
            ) {
                found.append(contentsOf: batch)
            }
            return found
        }

        let withRoot = await search(root: kyoto2024, matchesRoot: true)
        #expect(withRoot.contains {
            $0.url.standardizedFileURL == kyoto2024.standardizedFileURL && $0.kind == .folder
        })
        let withoutRoot = await search(root: kyoto2024, matchesRoot: false)
        #expect(!withoutRoot.contains { $0.url.standardizedFileURL == kyoto2024.standardizedFileURL })

        let hiddenRoot = env.root.appendingPathComponent(".kyoto", isDirectory: true)
        #expect(!(await search(root: hiddenRoot, matchesRoot: true)).contains { $0.name == ".kyoto" })

        let packageRoot = env.root.appendingPathComponent("Kyoto.app", isDirectory: true)
        #expect(!(await search(root: packageRoot, matchesRoot: true)).contains { $0.name == "Kyoto.app" })
    }

    @Test("SC-053: 一致するフォルダ50件とファイル50件のちょうど100件を返す")
    func scaleMatchingFoldersAndFiles() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileNameSearcherTests-scale-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let root = try FixtureSets.folderSearchScale(in: base)
        let results = try await collect(in: root, "kyoto").flatMap { $0 }

        #expect(results.count == 100, "一致は 100 件 (実際: \(results.count))")
        #expect(results.filter { $0.kind == .folder }.count == 50)
        #expect(results.filter { $0.kind.isMedia }.count == 50)
        #expect(!results.contains { $0.name.hasPrefix("kyoto-link-") })
        #expect(!results.contains { $0.name.hasPrefix("kyoto-package-") })
        #expect(!results.contains { $0.name.hasPrefix(".kyoto-hidden-") })
        #expect(!results.contains { $0.name.hasSuffix(".zip") })
        #expect(!results.contains { $0.name.hasPrefix("other-") })
        #expect(!results.contains { $0.url.standardizedFileURL == root.standardizedFileURL })
    }

    @Test("ディレクトリは照合の前に記録し、ファイル・隠し・リンク・パッケージの中・起点は記録しない")
    func recordsVisitedDirectories() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let pattern = try #require(SearchPattern(keyword: "cat"))
        let visits = SearchVisitLog()
        var found: [[MediaFile]] = []
        for await batch in FileNameSearcher(kindNames: FixtureKit.kindNames).search(
            SearchRequest(root: env.root, pattern: pattern, visits: visits)
        ) {
            found.append(batch)
        }
        // 記録したパスを使うため、結果を集め終えてから確かめる
        #expect(!found.isEmpty)

        func path(_ relative: String) -> String {
            env.root.appendingPathComponent(relative).standardizedFileURL.path
        }

        for relative in ["a", "a/b", "a/b/deep", "b", "numbers", "kana", "cat-folder", "Viewer.app"] {
            #expect(visits.contains(path(relative)), "記録がない: \(relative)")
        }
        for relative in ["Cat01.jpg", ".hidden", "link", "Viewer.app/Contents", "cats.zip"] {
            #expect(!visits.contains(path(relative)), "記録されている: \(relative)")
        }
        #expect(!visits.contains(env.root.standardizedFileURL.path), "起点を記録している")

        // プロトコル拡張の search(in:matching:) は search(_:) と同じ結果を返す
        let shortcut = try await collect(in: env.root, "cat").flatMap { $0 }
        #expect(relativePaths(shortcut, root: env.root) == relativePaths(found.flatMap { $0 }, root: env.root))
    }

    @Test("cat は対応メディアとフォルダを返し、隠し・パッケージ・zip・リンク経由・一致したフォルダの中の一致しない名前を除く")
    func keywordCat() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let files = try await collect(in: env.root, "cat").flatMap { $0 }
        #expect(relativePaths(files, root: env.root) == [
            "Cat01.jpg", "a/my_cat.mov", "a/b/deep/cat-deep.png", "b/Cat01.jpg", "cat-folder",
        ])
        #expect(files.count == 5)
        // 名前が一致したフォルダの中も辿るが、親が一致したことを理由に中の項目を一致とはしない（EC-92）
        #expect(!files.contains { $0.url.path.hasSuffix("cat-folder/x.jpg") })
        #expect(files.first { $0.name == "cat-folder" }?.kind == .folder)
    }

    @Test("ワイルドカードと NFD の名前")
    func wildcardsAndNormalization() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let png = try await collect(in: env.root, "*.png").flatMap { $0 }
        #expect(relativePaths(png, root: env.root) == ["a/dog.png", "a/b/deep/cat-deep.png", "kana/が.png"])
        let img = try await collect(in: env.root, "IMG_????.jpg").flatMap { $0 }
        #expect(relativePaths(img, root: env.root) == ["numbers/IMG_0001.jpg"])
        let ga = try await collect(in: env.root, "が").flatMap { $0 }
        #expect(relativePaths(ga, root: env.root) == ["kana/が.png"])
    }

    @Test("ファイルへのリンクは通常のファイルとして返し、フォルダへのリンクは辿らない")
    func symbolicLinks() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let linked = try await collect(in: env.root, "linked").flatMap { $0 }
        #expect(relativePaths(linked, root: env.root) == ["linked.jpg"])
        let listed = try await DirectoryLister(kindNames: FixtureKit.kindNames).mediaFiles(in: env.root)
        #expect(listed.contains { $0.name == "linked.jpg" })

        let link = try await collect(in: env.root, "link").flatMap { $0 }
        #expect(relativePaths(link, root: env.root) == ["linked.jpg"])
        let dog = try await collect(in: env.root, "dog").flatMap { $0 }
        #expect(relativePaths(dog, root: env.root) == ["a/dog.png"])
    }

    @Test("返す MediaFile の値は DirectoryLister と同じ")
    func mediaFileValuesMatchLister() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let files = try await collect(in: env.root, "cat").flatMap { $0 }
        let top = try #require(files.first { $0.url.path == env.root.appendingPathComponent("Cat01.jpg").path })
        let movie = try #require(files.first { $0.name == "my_cat.mov" })
        #expect(top.kind == .media(.jpeg))
        #expect(movie.kind == .media(.mov))
        #expect(top.name == "Cat01.jpg")

        let listedTop = try #require(try await DirectoryLister(kindNames: FixtureKit.kindNames).mediaFiles(in: env.root).first { $0.name == "Cat01.jpg" })
        let listedMovie = try #require(
            try await DirectoryLister(kindNames: FixtureKit.kindNames).mediaFiles(in: env.root.appendingPathComponent("a", isDirectory: true))
                .first { $0.name == "my_cat.mov" }
        )
        for (found, listed) in [(top, listedTop), (movie, listedMovie)] {
            #expect(found.fileSize == listed.fileSize)
            #expect(found.creationDate == listed.creationDate)
            #expect(found.typeDescription == listed.typeDescription)
            #expect(!found.typeDescription.isEmpty)
        }
    }

    @Test("権限のないサブフォルダを飛ばして終わる")
    func skipsUnreadableFolders() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let denied = env.root.appendingPathComponent("denied", isDirectory: true)
        try FileManager.default.createDirectory(at: denied, withIntermediateDirectories: true)
        try ImageFixtures.jpeg(at: denied.appendingPathComponent("cat-denied.jpg"), width: 8, height: 8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path) }

        let files = try await collect(in: env.root, "cat").flatMap { $0 }
        // `denied` は cat に一致しないため行にならず、中の cat-denied.jpg も出ない。`cat-folder` は行になる
        #expect(relativePaths(files, root: env.root) == [
            "Cat01.jpg", "a/my_cat.mov", "a/b/deep/cat-deep.png", "b/Cat01.jpg", "cat-folder",
        ])
    }

    @Test("存在しない起点と空のフォルダでは何も流さずに終わる")
    func emptyAndMissingRoots() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let empty = env.base.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(try await collect(in: empty, "*").isEmpty)
        #expect(try await collect(in: env.base.appendingPathComponent("missing", isDirectory: true), "*").isEmpty)
    }

    @Test("バッチは batchSize 件以下に分けて流す")
    func batches() async throws {
        let env = try makeEnv()
        defer { env.cleanup() }
        let batches = try await collect(FileNameSearcher(kindNames: FixtureKit.kindNames, batchSize: 2, batchInterval: .seconds(10)), in: env.root, "cat")
        #expect(batches.allSatisfy { $0.count <= 2 && !$0.isEmpty })
        #expect(batches.map(\.count).reduce(0, +) == 5)
    }

    /// 受け取る側は BrowserModel と同じくメインアクターで動かす（協調スレッドが塞がっていても止まらない）
    @Test("ストリームを集める Task を取り消すと、列挙が止まる")
    @MainActor
    func cancellationStopsEnumeration() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileNameSearcherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FixtureSets.huge(in: base)

        let counter = BatchCounter()
        let pattern = try #require(SearchPattern(keyword: "*"))
        let stream = FileNameSearcher(kindNames: FixtureKit.kindNames).search(in: base.appendingPathComponent("huge", isDirectory: true), matching: pattern)
        // 最初のバッチを受け取った時点で、集めている Task 自身を取り消す
        let collector = Task { @MainActor in
            for await batch in stream {
                counter.add(batch.count)
                if counter.batches == 1 {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
        }
        await collector.value
        let countAtCancel = counter.total
        try await Task.sleep(for: .milliseconds(500))

        #expect(counter.batches >= 1)
        #expect(counter.total == countAtCancel)
        #expect(countAtCancel < 10_000)
    }
}

@MainActor
private final class BatchCounter {
    private(set) var batches = 0
    private(set) var total = 0

    func add(_ count: Int) {
        batches += 1
        total += count
    }
}
