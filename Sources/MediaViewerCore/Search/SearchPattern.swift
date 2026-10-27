import Foundation

/// 検索キーワードとファイル名・フォルダ名の照合（FR-082、research.md R34）。
///
/// - キーワードと名前の両方を NFC にし、大文字小文字をそろえてから比べる。濁点の合成・分解の違いと英字の大文字小文字は区別しない。
///   全角・半角、ひらがな・カタカナは区別する
/// - `*` も `?` も含まないキーワードは、名前（ファイル名は拡張子を含む）に対する部分一致
/// - `*`（0 文字以上）か `?`（1 文字）を含むキーワードは、名前全体との一致。文字の単位は `Character`（書記素クラスタ）
/// - `[`・`]`・`\` などはただの文字として扱い、エスケープは持たない。照合するのは名前だけで、フォルダのパスは含めない
/// - フォルダ名も名前全体を照合し、「.」を含むフォルダ名（`2024.10_trip`・`photos.jpg`）は拡張子として扱わない（EC-97）
public struct SearchPattern: Sendable, Equatable {
    /// 入力から前後の空白を除いたもの。空にはならない
    public let keyword: String
    /// `*` か `?` を含むか
    public let usesWildcards: Bool

    /// 正規化したキーワード（イニシャライザで1回だけ作る）
    private let normalizedKeyword: String
    private let keywordCharacters: [Character]

    /// 前後の空白（改行を含む）を除いて空なら nil（「検索」ボタンは無効、Return は何もしない）
    public init?(keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.keyword = trimmed
        self.usesWildcards = trimmed.contains("*") || trimmed.contains("?")
        self.normalizedKeyword = Self.normalize(trimmed)
        self.keywordCharacters = Array(normalizedKeyword)
    }

    /// ファイル名またはフォルダ名と照合する。フォルダ名も名前全体を照合し、「.」を拡張子として扱わない（FR-082・EC-97）
    public func matches(fileName: String) -> Bool {
        let name = Self.normalize(fileName)
        guard usesWildcards else {
            return name.contains(normalizedKeyword)
        }
        return Self.globMatches(keywordCharacters, Array(name))
    }

    private static func normalize(_ string: String) -> String {
        string.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive], locale: nil)
    }

    /// 直前の `*` の位置を覚えて戻る反復の照合。再帰せず、最悪でも名前の長さ × キーワードの長さで終わる
    private static func globMatches(_ pattern: [Character], _ name: [Character]) -> Bool {
        var p = 0
        var n = 0
        var starIndex: Int?
        var starMatch = 0

        while n < name.count {
            if p < pattern.count, pattern[p] == "?" || (pattern[p] != "*" && pattern[p] == name[n]) {
                p += 1
                n += 1
            } else if p < pattern.count, pattern[p] == "*" {
                starIndex = p
                starMatch = n
                p += 1
            } else if let star = starIndex {
                p = star + 1
                starMatch += 1
                n = starMatch
            } else {
                return false
            }
        }

        while p < pattern.count, pattern[p] == "*" {
            p += 1
        }
        return p == pattern.count
    }
}
