import CoreFoundation
import Foundation
import Testing
@testable import MediaViewerCore

@Suite("ArchiveNameDecoder")
struct ArchiveNameDecoderTests {
    private static let cp932 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)
        )
    )

    private func cp932Bytes(_ text: String) throws -> Data {
        try #require(text.data(using: Self.cp932))
    }

    @Test("UTF-8 フラグありの UTF-8 はそのまま読む")
    func utf8WithFlag() {
        let bytes = Data("写真.jpg".utf8)
        #expect(ArchiveNameDecoder.decode(bytes, utf8Flag: true) == "写真.jpg")
    }

    @Test("UTF-8 フラグありで不正なバイトを含んでも置換文字で返す")
    func utf8FlagWithInvalidBytes() {
        var bytes = Data("ab".utf8)
        bytes.append(contentsOf: [0xFF, 0xFE])
        bytes.append(contentsOf: Array("c.png".utf8))
        let decoded = ArchiveNameDecoder.decode(bytes, utf8Flag: true)
        #expect(decoded.contains("\u{FFFD}"))
        #expect(decoded.hasPrefix("ab"))
        #expect(decoded.hasSuffix("c.png"))
    }

    @Test("UTF-8 フラグなしでも、厳密に UTF-8 として読めれば UTF-8 で読む")
    func utf8WithoutFlag() {
        let bytes = Data("日本語/画像.png".utf8)
        #expect(ArchiveNameDecoder.decode(bytes, utf8Flag: false) == "日本語/画像.png")
    }

    @Test("UTF-8 フラグなしの CP932 を読む")
    func cp932WithoutFlag() throws {
        let bytes = try cp932Bytes("写真①.jpg")
        #expect(ArchiveNameDecoder.decode(bytes, utf8Flag: false) == "写真①.jpg")
    }

    @Test("2バイト目が 0x5C の文字を含む CP932 も壊れない")
    func cp932WithBackslashTrailByte() throws {
        let bytes = try cp932Bytes("表示.png")
        #expect(bytes.contains(0x5C))
        #expect(ArchiveNameDecoder.decode(bytes, utf8Flag: false) == "表示.png")
    }

    @Test("UTF-8 でも CP932 でもないバイト列は CP437 で読む")
    func cp437Fallback() {
        let decoded = ArchiveNameDecoder.decode(Data([0x80, 0xFF, 0x41]), utf8Flag: false)
        #expect(decoded == "\u{00C7}\u{00A0}A")
        #expect(decoded.count == 3)
    }

    @Test("ASCII だけの名前はフラグに関わらず同じ結果")
    func asciiIsIndependentOfFlag() {
        let bytes = Data("dir/photo 1.jpg".utf8)
        #expect(ArchiveNameDecoder.decode(bytes, utf8Flag: true) == "dir/photo 1.jpg")
        #expect(ArchiveNameDecoder.decode(bytes, utf8Flag: false) == "dir/photo 1.jpg")
    }

    @Test("空のバイト列は空文字")
    func emptyBytes() {
        #expect(ArchiveNameDecoder.decode(Data(), utf8Flag: true) == "")
        #expect(ArchiveNameDecoder.decode(Data(), utf8Flag: false) == "")
    }
}
