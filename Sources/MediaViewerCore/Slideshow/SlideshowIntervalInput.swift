import Foundation

/// 設定ウインドウの切り替え間隔（秒）の入力文字列を解析する。
/// 受理するのは、前後の空白を除いた ASCII／全角の数字だけ。符号・小数点・桁区切りは受け付けない。
public enum SlideshowIntervalInput {
    /// 有効な間隔（秒）を返す。`SlideshowOptions.intervalRange` の外や不正な入力は nil。
    public static func parse(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var ascii = String.UnicodeScalarView()
        for scalar in trimmed.unicodeScalars {
            switch scalar.value {
            case 0xFF10...0xFF19:
                ascii.append(Unicode.Scalar(scalar.value - 0xFF10 + 0x30)!)
            case 0x30...0x39:
                ascii.append(scalar)
            default:
                return nil
            }
        }
        guard !ascii.isEmpty,
              let value = Int(String(ascii)),
              SlideshowOptions.intervalRange.contains(value)
        else { return nil }
        return value
    }
}
