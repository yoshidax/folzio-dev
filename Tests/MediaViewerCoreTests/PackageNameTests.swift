import Foundation
import Testing
@testable import MediaViewerCore

@Suite("PackageName")
struct PackageNameTests {
    @Test("拡張子がパッケージの型なら true", arguments: ["Photos.app", "Docs.rtfd", "X.bundle"])
    func detectsPackageExtensions(name: String) {
        #expect(PackageName.isPackage(name))
    }

    @Test("パッケージの型でない拡張子・拡張子なしは false", arguments: ["2025.01", "Photos", "a.txt", "", ".app"])
    func ignoresOrdinaryNames(name: String) {
        #expect(!PackageName.isPackage(name))
    }

    @Test("大文字の拡張子（Photos.APP）も true（UTType の照合は大文字小文字を区別しない）")
    func uppercaseExtensionIsPackage() {
        #expect(PackageName.isPackage("Photos.APP"))
    }
}
