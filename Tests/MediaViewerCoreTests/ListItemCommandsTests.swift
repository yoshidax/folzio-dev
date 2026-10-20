import Testing
@testable import MediaViewerCore

@Suite("ListItemCommands")
struct ListItemCommandsTests {
    private static let allKinds: [ListItemKind] = [.media(.jpeg), .media(.mp4), .archive, .directory, .parent]

    // MARK: - 通常のフォルダ（zip の外）

    @Test("zip の外のメディアは操作できるが、中へは入れず上へも戻れない")
    func mediaOutsideArchive() {
        let commands = ListItemCommands(kind: .media(.jpeg), isBrowsingArchive: false)
        #expect(commands.canOpenContainer == false)
        #expect(commands.canGoUp == false)
        #expect(commands.allowsFileOperations == true)
        #expect(commands.allowsPaste == true)
    }

    @Test("zip の外の動画も画像と同じ")
    func videoOutsideArchive() {
        let commands = ListItemCommands(kind: .media(.mov), isBrowsingArchive: false)
        #expect(commands.canOpenContainer == false)
        #expect(commands.canGoUp == false)
        #expect(commands.allowsFileOperations == true)
        #expect(commands.allowsPaste == true)
    }

    @Test("zip の外の zip ファイルは中へ入れて、全操作も有効")
    func archiveOutsideArchive() {
        let commands = ListItemCommands(kind: .archive, isBrowsingArchive: false)
        #expect(commands.canOpenContainer == true)
        #expect(commands.canGoUp == false)
        #expect(commands.allowsFileOperations == true)
        #expect(commands.allowsPaste == true)
    }

    @Test("行が選ばれていないとき、zip の外ではファイル操作とペーストが有効で中へは入れない")
    func noFocusOutsideArchive() {
        let commands = ListItemCommands(kind: nil, isBrowsingArchive: false)
        #expect(commands.canOpenContainer == false)
        #expect(commands.canGoUp == false)
        #expect(commands.allowsFileOperations == true)
        #expect(commands.allowsPaste == true)
    }

    @Test("zip の外ではどの行の種類でも canGoUp は false")
    func canGoUpIsFalseOutsideArchive() {
        for kind in Self.allKinds {
            #expect(ListItemCommands(kind: kind, isBrowsingArchive: false).canGoUp == false, "kind=\(kind)")
        }
    }

    // MARK: - zip の中

    @Test("zip の中のメディアは中へ入れず、上へは戻れて、ファイル操作とペーストは不可")
    func mediaInsideArchive() {
        for kind in [ListItemKind.media(.png), .media(.mp4)] {
            let commands = ListItemCommands(kind: kind, isBrowsingArchive: true)
            #expect(commands.canOpenContainer == false, "kind=\(kind)")
            #expect(commands.canGoUp == true, "kind=\(kind)")
            #expect(commands.allowsFileOperations == false, "kind=\(kind)")
            #expect(commands.allowsPaste == false, "kind=\(kind)")
        }
    }

    @Test("zip の中のディレクトリは中へ入れる")
    func directoryInsideArchive() {
        let commands = ListItemCommands(kind: .directory, isBrowsingArchive: true)
        #expect(commands.canOpenContainer == true)
        #expect(commands.canGoUp == true)
        #expect(commands.allowsFileOperations == false)
        #expect(commands.allowsPaste == false)
    }

    @Test("zip の中の ... は上へ戻れる")
    func parentInsideArchive() {
        let commands = ListItemCommands(kind: .parent, isBrowsingArchive: true)
        #expect(commands.canOpenContainer == true)
        #expect(commands.canGoUp == true)
        #expect(commands.allowsFileOperations == false)
        #expect(commands.allowsPaste == false)
    }

    @Test("行が選ばれていないとき、zip の中では上へ戻れるが、中へは入れず操作もできない")
    func noFocusInsideArchive() {
        let commands = ListItemCommands(kind: nil, isBrowsingArchive: true)
        #expect(commands.canOpenContainer == false)
        #expect(commands.canGoUp == true)
        #expect(commands.allowsFileOperations == false)
        #expect(commands.allowsPaste == false)
    }

    @Test("zip の中ではどの行の種類でも読み取り専用で、上へ戻れる")
    func insideArchiveIsReadOnlyForEveryKind() {
        let kinds: [ListItemKind?] = Self.allKinds + [nil]
        for kind in kinds {
            let commands = ListItemCommands(kind: kind, isBrowsingArchive: true)
            #expect(commands.allowsFileOperations == false, "kind=\(String(describing: kind))")
            #expect(commands.allowsPaste == false, "kind=\(String(describing: kind))")
            #expect(commands.canGoUp == true, "kind=\(String(describing: kind))")
        }
    }
}
