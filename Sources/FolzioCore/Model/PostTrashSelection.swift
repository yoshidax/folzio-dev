import Foundation

/// Keeps the displayed order and selection until a file-list Move to Trash finishes.
public struct PostTrashSelection: Sendable {
    let orderedURLs: [URL]
    let targets: Set<URL>
    let selection: SelectionState
    let navigationGeneration: Int
    let intentGeneration: Int

    init?(orderedURLs: [URL], targets: Set<URL>, selection: SelectionState,
          navigationGeneration: Int = 0, intentGeneration: Int = 0) {
        guard !targets.isEmpty, targets.isSubset(of: selection.selected),
              targets.isSubset(of: Set(orderedURLs)) else { return nil }
        self.orderedURLs = orderedURLs
        self.targets = targets
        self.selection = selection
        self.navigationGeneration = navigationGeneration
        self.intentGeneration = intentGeneration
    }

    /// Returns nil when nothing succeeded; an empty selection means there is no following survivor.
    func selection(afterRemoving removed: Set<URL>, remainingURLs: [URL]) -> SelectionState? {
        guard !targets.isDisjoint(with: removed) else { return nil }
        let removedPaths = Set(removed.map { $0.standardizedFileURL.path })
        // Walk path components rather than scanning all removed paths for each row in a large batch.
        func survives(_ url: URL) -> Bool {
            let path = url.standardizedFileURL.path
            var prefix = path[...]
            while !prefix.isEmpty {
                if removedPaths.contains(String(prefix)) { return false }
                guard let slash = prefix.lastIndex(of: "/") else { break }
                prefix = prefix[..<slash]
            }
            return !removedPaths.contains("/")
        }
        let available = Set(remainingURLs.filter(survives))
        let kept = selection.selected.intersection(available)
        if !kept.isEmpty {
            let focused = selection.focused.flatMap { kept.contains($0) ? $0 : nil }
                ?? remainingURLs.last { kept.contains($0) }
            return SelectionState(selected: kept, focused: focused)
        }
        guard let lastTarget = orderedURLs.lastIndex(where: targets.contains) else { return nil }
        let next = orderedURLs.dropFirst(lastTarget + 1).first(where: available.contains)
        return SelectionState(selected: Set(next.map { [$0] } ?? []), focused: next)
    }
}
