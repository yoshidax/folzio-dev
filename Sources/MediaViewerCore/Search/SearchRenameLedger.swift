import Foundation

/// 検索の間のフォルダの名前の変更と、列挙ごとの照合の記録（EC-52・EC-94、research.md R2・R3、data-model.md §3）。
///
/// 名前の変更より前に始めた列挙から届く結果は古い場所の URL を持つため、列挙を始めた後の変更を順に当てて
/// 新しい場所に付け替える。名前を変えたフォルダ自身が未照合だった場合（変更の時点でそのフォルダをまだ照合して
/// いなかった場合）は、元の場所の行を捨て、追加の列挙が新しい名前で流す行を使う。
/// ディスクは読まず、パスは `SearchPath.normalized` で比べる（`standardizedFileURL` は `/private` を外して
/// 列挙の記録と形が変わるため使わない）
public struct SearchRenameLedger: Sendable {
    private struct Stream: Sendable {
        /// その列挙が照合したディレクトリの記録
        var visits: SearchVisitLog
        /// その列挙を始めた時点の `renames` の件数
        var renameCount: Int
    }

    /// 今の検索の間の名前の変更（古い順）
    private var renames: [RenamedFolder] = []
    /// 列挙ごとの記録と、開始時点の名前の変更の件数
    private var streams: [Stream] = []
    /// 未照合として扱った名前の変更の位置 → 元の場所の正規化したパス
    private var rejudged: [Int: String] = [:]

    public init() {}

    /// 名前の変更がない（台帳が空）か
    public var isEmpty: Bool { renames.isEmpty }

    /// 列挙を登録し、その番号（0, 1, …）を返す
    public mutating func addStream(visits: SearchVisitLog) -> Int {
        streams.append(Stream(visits: visits, renameCount: renames.count))
        return streams.count - 1
    }

    /// 名前の変更を記録する。`visited == false` は「変更の時点でそのフォルダをまだ照合していなかった」
    public mutating func recordRename(_ renamed: RenamedFolder, visited: Bool) {
        if !visited {
            rejudged[renames.count] = SearchPath.normalized(renamed.from)
        }
        renames.append(renamed)
    }

    /// フォルダを、各列挙が照合した時点の場所に戻して記録を問う。いずれかの列挙に記録があれば true
    public func hasVisited(_ folder: URL) -> Bool {
        for stream in streams {
            var location = folder
            for renamed in renames[stream.renameCount...].reversed() {
                guard let reversed = renamed.reversed.rebase(location) else { continue }
                location = reversed
            }
            if stream.visits.contains(SearchPath.normalized(location)) {
                return true
            }
        }
        return false
    }

    /// 列挙 `index` から届いた結果に、その列挙を始めた後の名前の変更を順に当てる。未照合として扱った変更の
    /// 時点で元の場所と同じ行（名前を変えたフォルダ自身）は nil（捨てる）。フォルダの行は URL の最後の要素が
    /// 変わったときに `name` も新しい名前にする（FR-105）
    public func place(_ file: MediaFile, fromStream index: Int) -> MediaFile? {
        guard streams.indices.contains(index) else { return file }
        let stream = streams[index]
        var placed = file
        for offset in 0..<(renames.count - stream.renameCount) {
            let renameIndex = stream.renameCount + offset
            let renamed = renames[renameIndex]
            if rejudged[renameIndex] == SearchPath.normalized(placed.url) {
                return nil
            }
            guard let rebased = renamed.rebase(placed.url) else { continue }
            if placed.kind == .folder, rebased.lastPathComponent != placed.url.lastPathComponent {
                placed.name = rebased.lastPathComponent
            }
            placed.url = rebased
        }
        return placed
    }
}
