import Foundation

public func sorted(_ files: [MediaFile], by order: SortOrder) -> [MediaFile] {
    // `..`（.parent）は並べ替えに加えず、常に先頭に置く
    let parents = files.filter { $0.kind == .parent }
    let rest = files.filter { $0.kind != .parent }
    let indexed = Array(rest.enumerated())

    return parents + indexed.sorted { lhs, rhs in
        if let result = precedes(lhs.element, rhs.element, by: order) {
            return result
        }
        return lhs.offset < rhs.offset
    }.map(\.element)
}

/// 並べ替え済みの2つの配列から、`sorted(existing + incoming, by: order)` と同じ順序の配列を1回の走査で作る。
/// 同順位は `existing` が先（R36）。`..`（.parent）の行は渡されない前提
public func sortedMerge(_ existing: [MediaFile], _ incoming: [MediaFile], by order: SortOrder) -> [MediaFile] {
    guard !existing.isEmpty else { return incoming }
    guard !incoming.isEmpty else { return existing }

    var result: [MediaFile] = []
    result.reserveCapacity(existing.count + incoming.count)
    var i = 0
    var j = 0
    while i < existing.count, j < incoming.count {
        // incoming が厳密に先のときだけ incoming を置く（同順位は existing が先）
        if precedes(incoming[j], existing[i], by: order) == true {
            result.append(incoming[j])
            j += 1
        } else {
            result.append(existing[i])
            i += 1
        }
    }
    result.append(contentsOf: existing[i...])
    result.append(contentsOf: incoming[j...])
    return result
}

/// `a` が `b` より先なら true、後なら false、同順位なら nil。作成日の nil は向きに関わらず最後、
/// 列の値が同じなら名前の自然順（昇順）を第2キーにする
private func precedes(_ a: MediaFile, _ b: MediaFile, by order: SortOrder) -> Bool? {
    if order.column == .creationDate {
        if a.creationDate == nil, b.creationDate != nil {
            return false
        }
        if a.creationDate != nil, b.creationDate == nil {
            return true
        }
    }

    let primary = comparePrimary(a, b, column: order.column)
    if primary != .orderedSame {
        return order.ascending ? primary == .orderedAscending : primary == .orderedDescending
    }

    let byName = a.name.localizedStandardCompare(b.name)
    if byName != .orderedSame {
        return byName == .orderedAscending
    }
    return nil
}

private func comparePrimary(_ a: MediaFile, _ b: MediaFile, column: SortColumn) -> ComparisonResult {
    switch column {
    case .name:
        return a.name.localizedStandardCompare(b.name)
    case .creationDate:
        switch (a.creationDate, b.creationDate) {
        case let (.some(lhs), .some(rhs)):
            if lhs < rhs { return .orderedAscending }
            if lhs > rhs { return .orderedDescending }
            return .orderedSame
        case (nil, nil):
            return .orderedSame
        case (nil, .some):
            return .orderedDescending
        case (.some, nil):
            return .orderedAscending
        }
    case .kind:
        let lhs = a.typeDescription.localizedStandardCompare(b.typeDescription)
        if lhs != .orderedSame {
            return lhs
        }
        return a.kind.sortKey.localizedStandardCompare(b.kind.sortKey)
    case .location:
        // 検索結果の表示中だけ使う（FR-084）。保存しない
        return a.url.deletingLastPathComponent().path
            .localizedStandardCompare(b.url.deletingLastPathComponent().path)
    }
}
