import Testing
@testable import MediaViewerCore

@Suite("FileListChrome")
struct FileListChromeTests {
    @Test("サムネイル形式でツールバー非表示なら下部バーを出し、スライダーは有効")
    func thumbnailsWithoutToolbar() {
        let chrome = FileListChrome(displayMode: .thumbnails, toolbarShown: false)
        #expect(chrome.showsBottomSizeBar)
        #expect(chrome.toolbarSliderEnabled)
    }

    @Test("サムネイル形式でツールバー表示中なら下部バーを隠し、スライダーは有効")
    func thumbnailsWithToolbar() {
        let chrome = FileListChrome(displayMode: .thumbnails, toolbarShown: true)
        #expect(!chrome.showsBottomSizeBar)
        #expect(chrome.toolbarSliderEnabled)
    }

    @Test("リスト形式でツールバー非表示なら下部バーを出さず、スライダーは無効")
    func listWithoutToolbar() {
        let chrome = FileListChrome(displayMode: .list, toolbarShown: false)
        #expect(!chrome.showsBottomSizeBar)
        #expect(!chrome.toolbarSliderEnabled)
    }

    @Test("リスト形式でツールバー表示中なら下部バーを出さず、スライダーは無効")
    func listWithToolbar() {
        let chrome = FileListChrome(displayMode: .list, toolbarShown: true)
        #expect(!chrome.showsBottomSizeBar)
        #expect(!chrome.toolbarSliderEnabled)
    }
}
