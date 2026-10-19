import Testing
@testable import MediaViewerCore

@Suite("MediaKind")
struct MediaKindTests {
    @Test("対応拡張子を大文字小文字を区別せず判定する", arguments: [
        ("jpg", MediaKind.jpeg),
        ("JPG", .jpeg),
        ("Jpeg", .jpeg),
        ("jPeG", .jpeg),
        ("png", .png),
        ("PNG", .png),
        ("gif", .gif),
        ("GIF", .gif),
        ("webp", .webp),
        ("WEBP", .webp),
        ("mp4", .mp4),
        ("MP4", .mp4),
        ("mov", .mov),
        ("MOV", .mov),
    ])
    func recognizesSupportedExtensions(fileExtension: String, expected: MediaKind) {
        #expect(MediaKind(fileExtension: fileExtension) == expected)
    }

    @Test("非対応拡張子は nil になる", arguments: ["txt", "pdf", "heic", ""])
    func rejectsUnsupportedExtensions(fileExtension: String) {
        #expect(MediaKind(fileExtension: fileExtension) == nil)
    }

    @Test("動画だけ isVideo が true になる")
    func marksVideos() {
        #expect(MediaKind.mp4.isVideo)
        #expect(MediaKind.mov.isVideo)
        #expect(!MediaKind.jpeg.isVideo)
        #expect(!MediaKind.png.isVideo)
        #expect(!MediaKind.gif.isVideo)
        #expect(!MediaKind.webp.isVideo)
    }
}
