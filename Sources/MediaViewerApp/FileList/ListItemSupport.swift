import AppKit
import MediaViewerCore

extension BrowserModel {
    /// フォーカス行の種類と zip の中を表示中かから、操作ごとの可否を返す。
    /// メニュー・キー・ドラッグで同じ判断を使う（FR-069・073、research.md R26）
    var focusedItemCommands: ListItemCommands {
        let kind = selection.focused.flatMap { focused in
            listing.files.first { $0.url == focused }?.kind
        }
        return ListItemCommands(kind: kind, isBrowsingArchive: isBrowsingArchive)
    }

    /// 指定した行の種類に対する可否。行が範囲外なら nil の種類として扱う
    func itemCommands(forRowAt index: Int) -> ListItemCommands {
        let files = listing.files
        let kind = files.indices.contains(index) ? files[index].kind : nil
        return ListItemCommands(kind: kind, isBrowsingArchive: isBrowsingArchive)
    }
}

extension NSEvent {
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
