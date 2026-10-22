import Testing
@testable import MediaViewerCore

@Suite("ListItemCommands")
struct ListItemCommandsTests {
    private static let allKinds: [ListItemKind] = [.media(.jpeg), .media(.mp4), .archive, .folder, .directory, .parent]

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

    @Test("通常のフォルダのフォルダの行は中へ入れて、全操作も有効")
    func folderOutsideArchive() {
        let commands = ListItemCommands(kind: .folder, isBrowsingArchive: false)
        #expect(commands.canOpenContainer == true)
        #expect(commands.allowsFileOperations == true)
        #expect(commands.allowsPaste == true)
    }

    @Test("通常のフォルダの .. の行は開けるが、ファイル操作の対象にならない。ペーストは表示中のフォルダへできる")
    func parentOutsideArchive() {
        let commands = ListItemCommands(kind: .parent, isBrowsingArchive: false, hasEnclosingLevel: true)
        #expect(commands.canOpenContainer == true)
        #expect(commands.canGoUp == true)
        #expect(commands.allowsFileOperations == false)
        #expect(commands.allowsPaste == true)
    }

    @Test("hasEnclosingLevel を省略すると、canGoUp は isBrowsingArchive と同じ")
    func hasEnclosingLevelDefaultsToBrowsingArchive() {
        let kinds: [ListItemKind?] = Self.allKinds + [nil]
        for kind in kinds {
            #expect(ListItemCommands(kind: kind, isBrowsingArchive: false).hasEnclosingLevel == false)
            #expect(ListItemCommands(kind: kind, isBrowsingArchive: true).hasEnclosingLevel == true)
        }
    }

    @Test("zip の外では、戻る先があればどの行の種類でも canGoUp が true、なければ false")
    func canGoUpFollowsEnclosingLevel() {
        let kinds: [ListItemKind?] = Self.allKinds + [nil]
        for kind in kinds {
            let label = "kind=\(String(describing: kind))"
            #expect(ListItemCommands(kind: kind, isBrowsingArchive: false, hasEnclosingLevel: true).canGoUp == true, Comment(rawValue: label))
            #expect(ListItemCommands(kind: kind, isBrowsingArchive: false, hasEnclosingLevel: false).canGoUp == false, Comment(rawValue: label))
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

    @Test("zip の中の .. は上へ戻れる")
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

    // MARK: - 検索結果（FR-087）

    @Test("検索結果ではペーストと上の階層へが不可で、ほかのファイル操作は通常のフォルダと同じ")
    func searchResults() {
        let commands = ListItemCommands(
            kind: .media(.jpeg),
            isBrowsingArchive: false,
            hasEnclosingLevel: true,
            isShowingSearchResults: true
        )
        #expect(commands.allowsPaste == false)
        #expect(commands.canGoUp == false)
        #expect(commands.allowsFileOperations == true)
        #expect(commands.canOpenContainer == false)

        let noFocus = ListItemCommands(kind: nil, isBrowsingArchive: false, isShowingSearchResults: true)
        #expect(noFocus.allowsPaste == false)
    }

    @Test("isShowingSearchResults を省略した呼び出しの結果は変わらない")
    func searchFlagDefaultsToFalse() {
        let kinds: [ListItemKind?] = Self.allKinds + [nil]
        for kind in kinds {
            for archive in [false, true] {
                for enclosing in [false, true] {
                    let omitted = ListItemCommands(kind: kind, isBrowsingArchive: archive, hasEnclosingLevel: enclosing)
                    let explicit = ListItemCommands(
                        kind: kind,
                        isBrowsingArchive: archive,
                        hasEnclosingLevel: enclosing,
                        isShowingSearchResults: false
                    )
                    #expect(omitted == explicit)
                    #expect(omitted.canGoUp == enclosing)
                    #expect(omitted.allowsPaste == !archive)
                }
            }
        }
    }
}
