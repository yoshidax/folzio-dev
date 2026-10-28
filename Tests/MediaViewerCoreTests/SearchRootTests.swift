import Foundation
import Testing
@testable import FixtureKit
@testable import MediaViewerCore

@Suite("SearchRoot")
struct SearchRootTests {
    private let home = URL(fileURLWithPath: "/Users/me", isDirectory: true)

    private func parsedPath(_ input: String) -> String? {
        try? SearchRoot.parse(input, home: home).get().path
    }

    @Test("入力を解釈する。ディスクは読まない")
    func parse() {
        #expect(SearchRoot.parse("", home: home) == .failure(.empty))
        #expect(SearchRoot.parse("  ", home: home) == .failure(.empty))
        #expect(parsedPath("~") == "/Users/me")
        #expect(parsedPath(" ~/a/b ") == "/Users/me/a/b")
        #expect(parsedPath("/a/b/") == "/a/b")
        #expect(parsedPath("/") == "/")
        #expect(parsedPath("/a/./b/../c") == "/a/c")
        #expect(SearchRoot.parse("~user/a", home: home) == .failure(.notAbsolute))
        #expect(SearchRoot.parse("a/b", home: home) == .failure(.notAbsolute))
        #expect(SearchRoot.parse("./a", home: home) == .failure(.notAbsolute))
        #expect(parsedPath("/no/such/folder/anywhere") == "/no/such/folder/anywhere")
    }

    @Test("フォルダ・リンク・存在しない・ファイル・zip・パッケージ・権限なしを見分ける")
    func validate() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchRootTests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        let folder = root.appendingPathComponent("folder", isDirectory: true)
        let denied = root.appendingPathComponent("denied", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: denied, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: root.appendingPathComponent("Viewer.app/Contents", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path)
            try? fileManager.removeItem(at: root)
        }
        try Data("x".utf8).write(to: root.appendingPathComponent("file.jpg"))
        try ZipFixtureWriter.write(
            [ZipFixtureEntry(name: "a.txt", content: .bytes(Data("a".utf8)), method: .stored)],
            to: root.appendingPathComponent("x.zip")
        )
        let link = root.appendingPathComponent("link")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: folder)

        let validated = await SearchRoot.validate(folder)
        #expect(try validated.get().resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path)

        let linked = await SearchRoot.validate(link)
        #expect(try linked.get().resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path)

        #expect(await SearchRoot.validate(root.appendingPathComponent("missing")) == .failure(.notFound))
        #expect(await SearchRoot.validate(root.appendingPathComponent("file.jpg")) == .failure(.notAFolder))
        #expect(await SearchRoot.validate(root.appendingPathComponent("x.zip")) == .failure(.notAFolder))
        #expect(await SearchRoot.validate(root.appendingPathComponent("Viewer.app")) == .failure(.notAFolder))

        try fileManager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        // root で実行されていて開けてしまう場合は飛ばす
        if let directory = opendir(denied.path) {
            closedir(directory)
        } else {
            #expect(await SearchRoot.validate(denied) == .failure(.accessDenied))
        }
    }

    @Test("隠し祖先・隠しフォルダは直接入力の検証を拒否せず、パッケージ自身は拒否する")
    func hiddenAncestorsAreNotRejectedForTypedInput() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchRootTests-\(UUID().uuidString)", isDirectory: true)
        let hidden = root.appendingPathComponent(".hidden", isDirectory: true)
        let inside = hidden.appendingPathComponent("inside", isDirectory: true)
        let package = root.appendingPathComponent("Viewer.app", isDirectory: true)
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: package.appendingPathComponent("Contents", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(try await SearchRoot.validate(hidden).get().path == hidden.resolvingSymlinksInPath().path)
        #expect(try await SearchRoot.validate(inside).get().path == inside.resolvingSymlinksInPath().path)
        #expect(await SearchRoot.validate(package) == .failure(.notAFolder))
    }

    @Test("選択後の消失・非フォルダ化・権限変更を再検証で拒否する")
    func revalidationCatchesChanges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchRootTests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        let folder = root.appendingPathComponent("folder", isDirectory: true)
        let denied = root.appendingPathComponent("denied", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: denied, withIntermediateDirectories: true)
        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path)
            try? fileManager.removeItem(at: root)
        }

        #expect(await SearchRoot.validate(folder) != .failure(.notFound))
        try fileManager.removeItem(at: folder)
        #expect(await SearchRoot.validate(folder) == .failure(.notFound))

        try Data("x".utf8).write(to: folder)
        #expect(await SearchRoot.validate(folder) == .failure(.notAFolder))

        try fileManager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        if let directory = opendir(denied.path) {
            closedir(directory)
        } else {
            #expect(await SearchRoot.validate(denied) == .failure(.accessDenied))
        }
    }

}
