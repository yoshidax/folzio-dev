import Foundation
import Testing
@testable import MediaViewerCore

@Suite("FolderDisclosure")
struct FolderDisclosureTests {
    private func makeNode() -> FolderNode {
        FolderNode(url: URL(fileURLWithPath: "/tmp/folder"), name: "folder", kind: .folder)
    }

    @Test("既定ではサブフォルダの有無は未確認で、開閉できない")
    func defaultsToUnknown() {
        let node = makeNode()
        #expect(node.subfolderState == .unknown)
        #expect(!node.isExpandable)
    }

    @Test(
        "開閉できるのは権限なし以外で、サブフォルダがあるか確認に失敗したときだけ",
        arguments: [FolderNode.AccessState.unknown, .accessible, .denied, .unavailable]
    )
    func expandability(access: FolderNode.AccessState) {
        let states: [FolderNode.SubfolderState] = [.unknown, .present, .absent, .failed]
        for state in states {
            var node = makeNode()
            node.accessState = access
            node.subfolderState = state
            let expected = access != .denied && (state == .present || state == .failed)
            #expect(node.isExpandable == expected, "access: \(access), subfolders: \(state)")
        }
    }

    @Test("確認でサブフォルダがあれば present になる")
    func probeFindsSubfolders() {
        var node = makeNode()
        node.applySubfolderProbe(.success(true))
        #expect(node.subfolderState == .present)
        #expect(node.accessState == .accessible)
        #expect(node.isExpandable)
    }

    @Test("確認でサブフォルダがなければ absent になる")
    func probeFindsNoSubfolders() {
        var node = makeNode()
        node.applySubfolderProbe(.success(false))
        #expect(node.subfolderState == .absent)
        #expect(node.accessState == .accessible)
        #expect(!node.isExpandable)
    }

    @Test("確認が権限なしで失敗すれば denied になり、開閉できない")
    func probeDenied() {
        var node = makeNode()
        node.applySubfolderProbe(.failure(.accessDenied))
        #expect(node.accessState == .denied)
        #expect(!node.isExpandable)
    }

    @Test("確認が権限以外の理由で失敗すれば failed になり、開閉できる", arguments: [
        ListingError.notFound,
        .other("x"),
    ])
    func probeFailed(error: ListingError) {
        var node = makeNode()
        node.applySubfolderProbe(.failure(error))
        #expect(node.subfolderState == .failed)
        #expect(node.isExpandable)
    }

    @Test("再確認の結果で状態を上書きする")
    func reprobeOverridesState() {
        var node = makeNode()
        node.applySubfolderProbe(.success(true))
        node.applySubfolderProbe(.success(false))
        #expect(node.subfolderState == .absent)

        var denied = makeNode()
        denied.applySubfolderProbe(.failure(.accessDenied))
        denied.applySubfolderProbe(.success(true))
        #expect(denied.subfolderState == .present)
        #expect(denied.accessState == .accessible)
        #expect(denied.isExpandable)
    }

    @Test("展開して子が1件以上なら present になる")
    func listingWithChildren() {
        var node = makeNode()
        node.subfolderState = .failed
        node.applySubfolderListing(.success(3))
        #expect(node.subfolderState == .present)
        #expect(node.accessState == .accessible)
    }

    @Test("展開して子が0件なら absent になり、開閉できない")
    func listingWithoutChildren() {
        var node = makeNode()
        node.subfolderState = .present
        node.applySubfolderListing(.success(0))
        #expect(node.subfolderState == .absent)
        #expect(!node.isExpandable)
    }

    @Test("展開時の読み込みが権限なしで失敗すれば denied になり、子は空になる")
    func listingDenied() {
        var node = makeNode()
        node.subfolderState = .present
        node.applySubfolderListing(.failure(.accessDenied))
        #expect(node.accessState == .denied)
        #expect(node.children == [])
        #expect(!node.isExpandable)
    }

    @Test("展開時の読み込みが権限以外の理由で失敗すれば unavailable になり、再展開できる", arguments: [
        ListingError.notFound,
        .other("x"),
    ])
    func listingUnavailable(error: ListingError) {
        var node = makeNode()
        node.subfolderState = .present
        node.children = []
        node.applySubfolderListing(.failure(error))
        #expect(node.accessState == .unavailable)
        #expect(node.subfolderState == .failed)
        #expect(node.children == nil)
        #expect(node.isExpandable)
    }

    @Test("読めなかったフォルダも、読み直しに成功すれば accessible に戻る")
    func listingRecovers() {
        var node = makeNode()
        node.applySubfolderListing(.failure(.other("x")))
        node.applySubfolderListing(.success(2))
        #expect(node.subfolderState == .present)
        #expect(node.accessState == .accessible)
    }

    @Test("ダブルクリックは展開中なら折りたたみ、開閉できれば展開し、それ以外は何もしない")
    func doubleClickToggle() {
        #expect(FolderDisclosure.doubleClickToggle(isExpandable: true, isExpanded: false) == .expand)
        #expect(FolderDisclosure.doubleClickToggle(isExpandable: true, isExpanded: true) == .collapse)
        #expect(FolderDisclosure.doubleClickToggle(isExpandable: false, isExpanded: true) == .collapse)
        #expect(FolderDisclosure.doubleClickToggle(isExpandable: false, isExpanded: false) == .none)
    }
}
