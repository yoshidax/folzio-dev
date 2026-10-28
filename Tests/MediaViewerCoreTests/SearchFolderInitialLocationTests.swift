import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SearchFolderInitialLocation の候補順")
struct SearchFolderInitialLocationTests {
    private let home = URL(fileURLWithPath: "/Users/me", isDirectory: true)

    private func directory(_ path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    @Test("現在入力、開始時既定、ホームの順に最初の有効な候補を使う")
    func candidateOrder() async {
        let current = home.appendingPathComponent("current", isDirectory: true)
        let defaultFolder = home.appendingPathComponent("default", isDirectory: true)
        let recorder = ValidationRecorder(successes: [current, defaultFolder, home])

        let first = await SearchFolderInitialLocation.resolve(
            input: .typed(current.path),
            defaultPath: defaultFolder.path,
            home: home,
            validate: recorder.validate
        )
        #expect(first == .success(current))
        #expect(recorder.calls == [current], "Stops at the first valid candidate")

        let secondRecorder = ValidationRecorder(successes: [defaultFolder, home])
        let second = await SearchFolderInitialLocation.resolve(
            input: .typed(current.path),
            defaultPath: defaultFolder.path,
            home: home,
            validate: secondRecorder.validate
        )
        #expect(second == .success(defaultFolder))
        #expect(secondRecorder.calls == [current, defaultFolder])

        let thirdRecorder = ValidationRecorder(successes: [home])
        let third = await SearchFolderInitialLocation.resolve(
            input: .typed(current.path),
            defaultPath: defaultFolder.path,
            home: home,
            validate: thirdRecorder.validate
        )
        #expect(third == .success(home))
        #expect(thirdRecorder.calls == [current, defaultFolder, home])
    }

    @Test("全候補が無効なら理由を返し、入力を書き換えない")
    func allCandidatesFail() async {
        let recorder = ValidationRecorder(successes: [])
        let input = SearchRootInput.typed("/missing")
        let result = await SearchFolderInitialLocation.resolve(
            input: input,
            defaultPath: "/missing-default",
            home: home,
            validate: recorder.validate
        )
        #expect(result == .failure(.noUsableFolder))
        #expect(recorder.calls.count == 3)
        #expect(input.displayText == "/missing")
    }

    @Test("入力の解釈失敗は飛ばし、既定パスは trim せず文字どおり使う")
    func skipsInvalidInputAndKeepsTrailingSpace() async {
        let spaced = directory("/Users/me/Photos ")
        let plain = directory("/Users/me/Photos")
        let recorder = ValidationRecorder(successes: [spaced])

        let result = await SearchFolderInitialLocation.resolve(
            input: .typed("relative"),
            defaultPath: spaced.path,
            home: plain,
            validate: recorder.validate
        )

        #expect(result == .success(spaced))
        #expect(recorder.calls == [spaced], "Does not try another candidate after a typed parse failure and trim")
        #expect(spaced.path != plain.path)
    }

    @Test("隠しフォルダは許可し、パッケージ・ファイル・読取不能は次候補へ進む")
    func acceptsHiddenAndSkipsInvalidKinds() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchFolderInitialLocation-\(UUID().uuidString)", isDirectory: true)
        let hidden = base.appendingPathComponent(".hidden", isDirectory: true)
        let package = base.appendingPathComponent("Picker.app", isDirectory: true)
        let file = base.appendingPathComponent("file.jpg")
        let normal = base.appendingPathComponent("normal", isDirectory: true)
        try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: package.appendingPathComponent("Contents", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: normal, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: base) }

        let hiddenResult = await SearchFolderInitialLocation.resolve(
            input: .typed(hidden.path),
            defaultPath: nil,
            home: normal
        )
        #expect(try hiddenResult.get().path == hidden.resolvingSymlinksInPath().standardizedFileURL.path)

        let packageResult = await SearchFolderInitialLocation.resolve(
            input: .typed(package.path),
            defaultPath: file.path,
            home: normal
        )
        #expect(try packageResult.get().path == normal.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    @Test("EC-102 の一覧 F が無効なら既定の F も飛ばしてホームへ進み、ツリー候補を加えない")
    func ec102FallsBackToHome() async {
        let f = home.appendingPathComponent("F", isDirectory: true)
        let recorder = ValidationRecorder(successes: [home])
        let result = await SearchFolderInitialLocation.resolve(
            input: .typed(f.path),
            defaultPath: f.path,
            home: home,
            validate: recorder.validate
        )

        #expect(result == .success(home))
        #expect(recorder.calls == [f, home], "Does not try the same F twice or use the additional tree candidate")
    }

    @Test("同じ候補は一度だけ検証する")
    func deduplicatesCandidates() async {
        let recorder = ValidationRecorder(successes: [home])
        let result = await SearchFolderInitialLocation.resolve(
            input: .typed(home.path),
            defaultPath: home.path,
            home: home,
            validate: recorder.validate
        )

        #expect(result == .success(home))
        #expect(recorder.calls == [home])
    }
}

/// Injected validator that records call order and availability.
private final class ValidationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let successes: Set<String>
    private var _calls: [URL] = []

    init(successes: [URL]) {
        self.successes = Set(successes.map(\.path))
    }

    var calls: [URL] {
        lock.withLock { _calls }
    }

    var validate: @Sendable (URL) async -> Result<URL, SearchRootError> {
        { [self] url in
            lock.withLock { _calls.append(url) }
            if successes.contains(url.path) {
                return .success(url)
            }
            return .failure(.notFound)
        }
    }
}
