import CoreFoundation
import Foundation

/// zip の中の名前の文字コードの判定（FR-074、research.md R27）
public enum ArchiveNameDecoder {
    private static let cp932 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)
        )
    )

    private static let cp437 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue)
        )
    )

    /// 1. UTF-8 フラグ（汎用フラグのビット 11）があれば UTF-8（不正なバイトは置換文字）
    /// 2. 厳密な UTF-8 として読めれば UTF-8
    /// 3. CP932
    /// 4. CP437（すべてのバイトが定義されているため、必ず読める）
    public static func decode(_ bytes: Data, utf8Flag: Bool) -> String {
        if utf8Flag {
            return String(decoding: bytes, as: UTF8.self)
        }
        if let text = String(validating: bytes, as: UTF8.self) {
            return text
        }
        if let text = String(data: bytes, encoding: cp932) {
            return text
        }
        if let text = String(data: bytes, encoding: cp437) {
            return text
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
