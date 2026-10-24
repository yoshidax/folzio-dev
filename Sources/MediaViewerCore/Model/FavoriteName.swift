import Foundation

/// お気に入りの表示名の入力規則（FR-100、R50）。AppKit に依存しない純粋関数の名前空間。
/// `/`・`:` を含む名前や、ほかの項目と同じ名前も拒否しない（EC-41）
public enum FavoriteName {
    /// 表示名の上限。`String.count`（書記素クラスタ）で数える。絵文字や結合文字も見た目の1文字を1と数える（FR-100、R50）
    public static let maximumLength = 255

    /// 編集中の入力。改行を取り除き、先頭から `maximumLength` 文字で打ち切る。前後の空白は残す（入力中のため。FR-100、R50）
    public static func sanitizedForEditing(_ text: String) -> String {
        // `\r\n` は1書記素のため Character 単位では判定できない。Unicode scalar 単位で取り除く
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars where !CharacterSet.newlines.contains(scalar) {
            scalars.append(scalar)
        }
        return String(String(scalars).prefix(maximumLength))
    }

    /// 確定時の入力。`sanitizedForEditing` の後に前後の空白と改行を取り除く。空なら nil（表示名の解除。FR-100、R50）
    public static func normalized(_ text: String) -> String? {
        let trimmed = sanitizedForEditing(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
