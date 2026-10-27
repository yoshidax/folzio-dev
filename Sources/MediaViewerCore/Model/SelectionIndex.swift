import Foundation

/// 一覧の並びから選択 URL の行番号を作る。
///
/// 選択した URL ごとに一覧全体を線形探索すると、10,000 行・5,000 選択で
/// 約5,000万回の比較になり UI が数十秒止まる。URL の対応表を1回だけ作り、
/// 選択件数に比例する処理にする（FR-016・SC-003・SC-016）。
public enum SelectionIndex {
    /// 一覧に同じ URL が重複する場合は最初の行を選ぶ（`firstIndex(of:)` と同じ意味）。
    /// 一覧にない選択 URL は無視する
    public static func indexes(of selected: Set<URL>, in urls: [URL]) -> IndexSet {
        guard !selected.isEmpty, !urls.isEmpty else { return IndexSet() }

        var indexByURL: [URL: Int] = [:]
        indexByURL.reserveCapacity(urls.count)
        for (index, url) in urls.enumerated() where indexByURL[url] == nil {
            indexByURL[url] = index
        }

        var indexes = IndexSet()
        for url in selected {
            if let index = indexByURL[url] {
                indexes.insert(index)
            }
        }
        return indexes
    }
}
