import Foundation

/// 履歴の列（FR-107〜FR-111）。記録・移動・分岐・上限・まとめの規則をすべてこの値型に置く（R68）
public struct NavigationHistory: Sendable {
    public static let capacity = 100

    public private(set) var backEntries: [HistoryEntry]
    public private(set) var current: HistoryEntry?
    public private(set) var forwardEntries: [HistoryEntry]
    public private(set) var version: Int

    private var lastRecordKind: HistoryRecordKind?

    public init() {
        self.backEntries = []
        self.current = nil
        self.forwardEntries = []
        self.version = 0
        self.lastRecordKind = nil
    }

    public var count: Int {
        backEntries.count + (current == nil ? 0 : 1) + forwardEntries.count
    }

    public var canGoBack: Bool { !backEntries.isEmpty }
    public var canGoForward: Bool { !forwardEntries.isEmpty }

    /// 戻る側・現在・進む側を1列に並べたもの（存在の確認に使う）
    public var allEntries: [HistoryEntry] {
        var entries = backEntries
        if let current { entries.append(current) }
        entries.append(contentsOf: forwardEntries)
        return entries
    }

    /// 操作の後の状態を1件の履歴として記録する。同じ状態なら何もせず false（FR-107・R71）
    @discardableResult
    public mutating func record(
        location: HistoryLocation,
        viewState: HistoryViewState,
        kind: HistoryRecordKind,
        leavingFocus: URL?
    ) -> Bool {
        if kind == .thumbnailSize, lastRecordKind == .thumbnailSize, var merged = current {
            guard merged.viewState != viewState else { return false }
            merged.viewState = viewState
            current = merged
            let didConsolidate = consolidate()
            lastRecordKind = didConsolidate ? nil : .thumbnailSize
            version += 1
            return true
        }

        let entry = HistoryEntry(location: location, viewState: viewState)
        if let current, current.hasSameState(as: entry) {
            return false
        }

        if var leaving = current {
            leaving.focusedItem = leavingFocus
            backEntries.append(leaving)
        }
        current = entry
        forwardEntries.removeAll()

        if count > Self.capacity {
            let overflow = count - Self.capacity
            backEntries.removeFirst(min(overflow, backEntries.count))
        }

        lastRecordKind = kind
        version += 1
        return true
    }

    public func candidate(_ direction: HistoryDirection) -> HistoryEntry? {
        switch direction {
        case .back:
            return backEntries.last
        case .forward:
            return forwardEntries.first
        }
    }

    /// 見つからなかった候補を取り除く（FR-109・EC-54）
    public mutating func dropCandidate(_ direction: HistoryDirection) {
        switch direction {
        case .back:
            guard !backEntries.isEmpty else { return }
            backEntries.removeLast()
        case .forward:
            guard !forwardEntries.isEmpty else { return }
            forwardEntries.removeFirst()
        }
        _ = consolidate()
        version += 1
    }

    /// 1つ前・1つ後の履歴へ移る。離れる履歴にフォーカス行を記録する（FR-108）
    @discardableResult
    public mutating func move(_ direction: HistoryDirection, leavingFocus: URL?) -> HistoryEntry? {
        guard let target = candidate(direction) else { return nil }

        switch direction {
        case .back:
            backEntries.removeLast()
            if var leaving = current {
                leaving.focusedItem = leavingFocus
                forwardEntries.insert(leaving, at: 0)
            }
        case .forward:
            forwardEntries.removeFirst()
            if var leaving = current {
                leaving.focusedItem = leavingFocus
                backEntries.append(leaving)
            }
        }

        current = target
        lastRecordKind = nil
        version += 1
        return target
    }

    /// 現在の表示の状態を書き換える（検索結果の表示を終えたとき。R76）
    public mutating func updateCurrentViewState(_ viewState: HistoryViewState) {
        guard var entry = current, entry.viewState != viewState else { return }
        entry.viewState = viewState
        current = entry
        _ = consolidate()
        lastRecordKind = nil
        version += 1
    }

    /// 現在の場所を置き換える（EC-60）。表示の状態と進む側は変えない
    public mutating func replaceCurrentLocation(_ location: HistoryLocation) {
        guard var entry = current, entry.location != location else { return }
        entry.location = location
        current = entry
        _ = consolidate()
        version += 1
    }

    /// 現在を戻る側の末尾へ移して現在を nil にする（EC-62）
    public mutating func detachCurrent() {
        guard let entry = current else { return }
        backEntries.append(entry)
        current = nil
        lastRecordKind = nil
        version += 1
    }

    /// 現在を取り除いて nil にする（EC-65）
    public mutating func removeCurrent() {
        guard current != nil else { return }
        current = nil
        lastRecordKind = nil
        _ = consolidate()
        version += 1
    }

    /// いずれかの `url` 自身か配下を指す履歴を取り除く（FR-109）
    public mutating func removeEntries(within urls: [URL], keepingCurrent: Bool) {
        guard !urls.isEmpty else { return }
        var changed = false

        if !keepingCurrent, let current, urls.contains(where: { current.location.isWithin($0) }) {
            self.current = nil
            changed = true
        }
        backEntries.removeAll { entry in
            guard urls.contains(where: { entry.location.isWithin($0) }) else { return false }
            changed = true
            return true
        }
        forwardEntries.removeAll { entry in
            guard urls.contains(where: { entry.location.isWithin($0) }) else { return false }
            changed = true
            return true
        }
        if changed {
            _ = consolidate()
            version += 1
        }
    }

    /// `allEntries` の位置で指定した履歴を取り除く（外部の変更。現在を含みうる）
    public mutating func removeEntries(at positions: Set<Int>) {
        guard !positions.isEmpty else { return }
        let entries = allEntries
        guard positions.contains(where: { entries.indices.contains($0) }) else { return }

        let boundary = backEntries.count
        let currentIndex = current == nil ? nil : boundary
        var newBack: [HistoryEntry] = []
        var newCurrent: HistoryEntry?
        var newForward: [HistoryEntry] = []

        for (index, entry) in entries.enumerated() where !positions.contains(index) {
            if let currentIndex, index == currentIndex {
                newCurrent = entry
            } else if index < boundary {
                newBack.append(entry)
            } else {
                newForward.append(entry)
            }
        }

        backEntries = newBack
        current = newCurrent
        forwardEntries = newForward
        _ = consolidate()
        version += 1
    }

    /// 名前を変えたフォルダの履歴を直す。現在は新しい場所に置き換え、ほかは取り除く（FR-109・R75）
    public mutating func renameFolder(_ renamed: RenamedFolder) {
        var changed = false

        if var entry = current, entry.location.isWithin(renamed.from),
           let rebased = entry.location.rebased(by: renamed) {
            entry.location = rebased
            current = entry
            changed = true
        }

        backEntries.removeAll { entry in
            guard entry.location.isWithin(renamed.from) else { return false }
            changed = true
            return true
        }
        forwardEntries.removeAll { entry in
            guard entry.location.isWithin(renamed.from) else { return false }
            changed = true
            return true
        }

        guard changed else { return }
        _ = consolidate()
        version += 1
    }

    /// 隣り合う同じ状態の履歴を1つにする（EC-59）。現在を含む組は現在を、含まなければ新しい方を残す
    @discardableResult
    private mutating func consolidate() -> Bool {
        let entries = allEntries
        guard entries.count > 1 else { return false }

        let boundary = backEntries.count
        let currentIndex = current == nil ? nil : boundary
        var keptIndices: [Int] = []
        var index = 0

        while index < entries.count {
            var end = index + 1
            while end < entries.count, entries[end].hasSameState(as: entries[index]) {
                end += 1
            }
            if end - index == 1 {
                keptIndices.append(index)
            } else if let currentIndex, currentIndex >= index, currentIndex < end {
                keptIndices.append(currentIndex)
            } else {
                keptIndices.append(end - 1)
            }
            index = end
        }

        guard keptIndices.count != entries.count else { return false }

        var newBack: [HistoryEntry] = []
        var newCurrent: HistoryEntry?
        var newForward: [HistoryEntry] = []
        for index in keptIndices {
            if let currentIndex, index == currentIndex {
                newCurrent = entries[index]
            } else if index < boundary {
                newBack.append(entries[index])
            } else {
                newForward.append(entries[index])
            }
        }

        backEntries = newBack
        current = newCurrent
        forwardEntries = newForward
        return true
    }
}
