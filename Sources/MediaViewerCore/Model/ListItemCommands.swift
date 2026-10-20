/// 行の種類と「zip の中を表示中か」から、操作ごとの可否を返す純粋計算（FR-069・073、research.md R26）。
/// 不可の操作は、メニュー項目を淡色にし、キーボードショートカットとドラッグでは何もしない
public struct ListItemCommands: Sendable, Equatable {
    /// フォーカス行の種類。行がない（未選択）ときは nil
    public let kind: ListItemKind?
    /// zip の中を表示中なら true
    public let isBrowsingArchive: Bool

    public init(kind: ListItemKind?, isBrowsingArchive: Bool) {
        self.kind = kind
        self.isBrowsingArchive = isBrowsingArchive
    }

    /// 中を表示（ダブルクリック・⌘↓）。zip ファイル・ディレクトリは中へ、`...` は上へ。メディアと行なしは何もしない
    public var canOpenContainer: Bool {
        kind?.opensAsContainer ?? false
    }

    /// 上の階層へ（⌘↑）。zip の中だけ
    public var canGoUp: Bool {
        isBrowsingArchive
    }

    /// 開く（⌘O）・コピー・複製・名前の変更・ゴミ箱・Finder に表示・ドラッグ。zip の中は読み取り専用
    public var allowsFileOperations: Bool {
        !isBrowsingArchive
    }

    /// 一覧へのペースト・移動ペースト。zip の中は不可
    public var allowsPaste: Bool {
        !isBrowsingArchive
    }
}
