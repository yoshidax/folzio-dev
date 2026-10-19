import Foundation

public func sorted(_ files: [MediaFile], by order: SortOrder) -> [MediaFile] {
    let indexed = Array(files.enumerated())

    return indexed.sorted { lhs, rhs in
        let a = lhs.element
        let b = rhs.element

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

        return lhs.offset < rhs.offset
    }.map(\.element)
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
        return a.kind.rawValue.localizedStandardCompare(b.kind.rawValue)
    }
}
