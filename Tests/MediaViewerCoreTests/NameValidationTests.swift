import Foundation
import Testing
@testable import MediaViewerCore

@Suite("NameValidation")
struct NameValidationTests {
    private let file = URL(fileURLWithPath: "/tmp/a.jpg")
    private let existingNames: Set<String> = ["a.jpg", "photo.png"]

    @Test("空・不正な文字・先頭のドット・大文字小文字だけ異なる名前を拒否する", arguments: [
        "",
        "   ",
        "a/b.jpg",
        "a:b.jpg",
        ".hidden.jpg",
        "A.JPG",
    ])
    func rejectsInvalidNames(name: String) {
        guard case .invalid = validateNewName(name, for: file, existingNames: existingNames) else {
            Issue.record("\(String(reflecting: name)) was accepted")
            return
        }
    }

    @Test("拡張子が変わる場合は確認を求める")
    func asksForExtensionChange() {
        #expect(
            validateNewName("a.png", for: file, existingNames: existingNames)
                == .needsExtensionChangeConfirmation
        )
        #expect(
            validateNewName("a", for: file, existingNames: existingNames)
                == .needsExtensionChangeConfirmation
        )
    }

    @Test("拡張子が同じ名前は受け入れる")
    func acceptsValidName() {
        #expect(validateNewName("b.jpg", for: file, existingNames: existingNames) == .ok)
        #expect(validateNewName("B.JPG", for: file, existingNames: existingNames) == .ok)
    }

    @Test("対象のファイル自身と同じ名前は衝突として拒否する")
    func rejectsSameName() {
        #expect(validateNewName("a.jpg", for: file, existingNames: existingNames) == .invalid(.duplicate))
    }

    @Test("フォルダの名前の変更では拡張子の確認を求めない")
    func folderSkipsExtensionConfirmation() {
        let folder = URL(fileURLWithPath: "/tmp/album", isDirectory: true)
        #expect(validateNewName("album.2024", for: folder, existingNames: [], isDirectory: true) == .ok)
        let dotted = URL(fileURLWithPath: "/tmp/photos.old", isDirectory: true)
        #expect(validateNewName("photos", for: dotted, existingNames: [], isDirectory: true) == .ok)
        // Files that omit isDirectory behave as before.
        #expect(validateNewName("a.png", for: file, existingNames: existingNames) == .needsExtensionChangeConfirmation)
    }

    @Test("フォルダでも空・不正な文字・先頭のドット・同名は拒否する", arguments: ["", "a/b", ".x", "ALBUM 2"])
    func folderRejectsInvalidNames(name: String) {
        let folder = URL(fileURLWithPath: "/tmp/album", isDirectory: true)
        guard case .invalid = validateNewName(name, for: folder, existingNames: ["album 2"], isDirectory: true) else {
            Issue.record("\(String(reflecting: name)) was accepted")
            return
        }
    }

    // MARK: Names That Become Packages (EC-53, EC-14)

    @Test("フォルダをパッケージになる名前に変えようとすると拒否する")
    func folderRejectsPackageName() {
        let folder = URL(fileURLWithPath: "/tmp/a/Photos", isDirectory: true)
        #expect(
            validateNewName("Photos.app", for: folder, existingNames: [], isDirectory: true)
                == .invalid(.becomesPackage)
        )
        #expect(validateNewName("2025.01", for: folder, existingNames: [], isDirectory: true) == .ok)
    }

    @Test("ファイルにはパッケージの検査を適用しない")
    func fileIgnoresPackageName() {
        let png = URL(fileURLWithPath: "/tmp/a/Photos.png")
        #expect(
            validateNewName("Photos.app", for: png, existingNames: [], isDirectory: false)
                == .needsExtensionChangeConfirmation
        )
    }

    @Test("パッケージの検査より既存の検査が先に当たる")
    func existingChecksComeFirst() {
        let folder = URL(fileURLWithPath: "/tmp/a/Photos", isDirectory: true)
        #expect(
            validateNewName(".app", for: folder, existingNames: [], isDirectory: true)
                == .invalid(.leadingDot)
        )
        #expect(
            validateNewName("a/b.app", for: folder, existingNames: [], isDirectory: true)
                == .invalid(.forbiddenCharacter)
        )
        #expect(
            validateNewName("photos.app", for: folder, existingNames: ["Photos.app"], isDirectory: true)
                == .invalid(.duplicate)
        )
    }

    @Test("uniqueName は 2 から連番を振る")
    func numbersUniqueNames() {
        #expect(uniqueName(for: "a.jpg", existingNames: []) == "a 2.jpg")
        #expect(uniqueName(for: "a.jpg", existingNames: ["a.jpg"]) == "a 2.jpg")
        #expect(uniqueName(for: "a.jpg", existingNames: ["a.jpg", "a 2.jpg"]) == "a 3.jpg")
    }

    @Test("既存の連番の続きから採番する")
    func continuesExistingCounter() {
        #expect(uniqueName(for: "c 2.jpg", existingNames: ["c 2.jpg"]) == "c 3.jpg")
        #expect(uniqueName(for: "c 2.jpg", existingNames: ["c 2.jpg", "c 3.jpg"]) == "c 4.jpg")
    }

    @Test("大文字小文字を区別せずに衝突を判定する")
    func detectsCaseInsensitiveCollisions() {
        #expect(uniqueName(for: "a.jpg", existingNames: ["A.JPG"]) == "a 2.jpg")
        #expect(uniqueName(for: "a.jpg", existingNames: ["A.JPG", "A 2.JPG"]) == "a 3.jpg")
    }

    @Test("拡張子のない名前にも連番を付ける")
    func handlesNameWithoutExtension() {
        #expect(uniqueName(for: "notes", existingNames: ["notes"]) == "notes 2")
        #expect(uniqueName(for: "notes", existingNames: ["NOTES", "notes 2"]) == "notes 3")
    }
}
