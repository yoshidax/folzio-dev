import AppKit
import MediaViewerCore

extension BrowserModel {
    /// フォーカス行の種類・zip の中を表示中か・戻る先があるか・検索結果を表示中かから、操作ごとの可否を返す。
    /// メニュー・キー・ドラッグで同じ判断を使う（FR-069・073・077・087、research.md R26・R30・R38）
    var focusedItemCommands: ListItemCommands {
        ListItemCommands(
            kind: focusedKind,
            isBrowsingArchive: isBrowsingArchive,
            hasEnclosingLevel: hasEnclosingLevel,
            isShowingSearchResults: isShowingSearchResults
        )
    }

    /// 選択に対するファイル操作（コピー・ゴミ箱など）の可否。対象は `operableSelection` で `..` を除くため、
    /// フォーカスが `..` でも、ほかの行が選ばれていればその行を操作できる（R30）
    var selectionItemCommands: ListItemCommands {
        let kind = focusedKind == .parent && !operableSelection.isEmpty ? nil : focusedKind
        return ListItemCommands(
            kind: kind,
            isBrowsingArchive: isBrowsingArchive,
            hasEnclosingLevel: hasEnclosingLevel,
            isShowingSearchResults: isShowingSearchResults
        )
    }

    private var focusedKind: ListItemKind? {
        selection.focused.flatMap { focused in
            listing.files.first { $0.url == focused }?.kind
        }
    }

    /// 指定した行の種類に対する可否。行が範囲外なら nil の種類として扱う
    func itemCommands(forRowAt index: Int) -> ListItemCommands {
        let files = listing.files
        let kind = files.indices.contains(index) ? files[index].kind : nil
        return ListItemCommands(
            kind: kind,
            isBrowsingArchive: isBrowsingArchive,
            hasEnclosingLevel: hasEnclosingLevel,
            isShowingSearchResults: isShowingSearchResults
        )
    }
}

extension NSEvent {
    /// 修飾キーなしの Esc か
    var isPlainEscape: Bool {
        guard charactersIgnoringModifiers == "\u{1b}" else { return false }
        let relevant = modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function, .capsLock])
        return relevant.isEmpty
    }

    /// Command だけを押した ↓ / ↑ か。メニュー項目が無効なときに、
    /// NSTableView / NSCollectionView の既定の動作（末尾へ移動など）へ渡さないために使う（R26）
    var isCommandOnlyVerticalArrow: Bool {
        guard specialKey == .downArrow || specialKey == .upArrow else { return false }
        let relevant = modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function, .capsLock])
        return relevant == [.command]
    }
}
