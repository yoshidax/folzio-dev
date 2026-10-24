import AppKit
import MediaViewerCore

/// お気に入りの名前の入力欄に付ける。ペーストを含めて改行と 256 文字目以降が入らないようにする（FR-100、R50）。
/// 規則は `FavoriteName` に任せ、ここには書かない。状態を持たず、`Formatter` の override は nonisolated のため
/// 分離の注釈は付けない
final class FavoriteNameFormatter: Formatter {
    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func string(for obj: Any?) -> String? {
        obj as? String
    }

    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        obj?.pointee = string as NSString
        return true
    }

    override func isPartialStringValid(
        _ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>,
        proposedSelectedRange proposedSelRangePtr: NSRangePointer?,
        originalString origString: String,
        originalSelectedRange origSelRange: NSRange,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        let partial = partialStringPtr.pointee as String
        let sanitized = FavoriteName.sanitizedForEditing(partial)
        if sanitized == partial { return true }

        let result = sanitized as NSString
        partialStringPtr.pointee = result
        if let range = proposedSelRangePtr {
            // 整形後の長さを超えない範囲に直す
            let location = min(range.pointee.location, result.length)
            range.pointee = NSRange(location: location, length: 0)
        }
        return false
    }
}
