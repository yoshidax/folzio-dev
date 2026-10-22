/// 行の種類・「zip の中を表示中か」・「戻る先があるか」・「検索結果を表示中か」から、操作ごとの可否を返す純粋計算
/// （FR-069・073・076・077・087、research.md R26・R30・R32・R38）。
/// 不可の操作は、メニュー項目を淡色にし、キーボードショートカットとドラッグでは何もしない
public struct ListItemCommands: Sendable, Equatable {
    /// フォーカス行の種類。行がない（未選択）ときは nil
    public let kind: ListItemKind?
    /// zip の中を表示中なら true
    public let isBrowsingArchive: Bool
    /// ⌘↑ で戻る先があるか（zip の中、またはツリーのルート以外の通常のフォルダ）
    public let hasEnclosingLevel: Bool
    /// 検索結果を表示中なら true。ペーストと ⌘↑ を不可にする（貼り付け先・戻る先のフォルダがない。FR-087）
    public let isShowingSearchResults: Bool

    /// `hasEnclosingLevel` を省略（nil）すると `isBrowsingArchive` と同じにする
    public init(
        kind: ListItemKind?,
        isBrowsingArchive: Bool,
        hasEnclosingLevel: Bool? = nil,
        isShowingSearchResults: Bool = false
    ) {
        self.kind = kind
        self.isBrowsingArchive = isBrowsingArchive
        self.hasEnclosingLevel = hasEnclosingLevel ?? isBrowsingArchive
        self.isShowingSearchResults = isShowingSearchResults
    }

    /// 中を表示（ダブルクリック・⌘↓）。zip ファイル・フォルダ・ディレクトリは中へ、`..` は上へ。メディアと行なしは何もしない
    public var canOpenContainer: Bool {
        kind?.opensAsContainer ?? false
    }

    /// 上の階層へ（⌘↑）。どの行を選択中でも、戻る先があれば戻れる
    public var canGoUp: Bool {
        hasEnclosingLevel && !isShowingSearchResults
    }

    /// 開く（⌘O）・コピー・複製・名前の変更・ゴミ箱・Finder に表示・ドラッグ。zip の中は読み取り専用で、`..` は対象にならない
    public var allowsFileOperations: Bool {
        !isBrowsingArchive && kind != .parent
    }

    /// 一覧へのペースト・移動ペースト。zip の中と検索結果の表示中は不可
    public var allowsPaste: Bool {
        !isBrowsingArchive && !isShowingSearchResults
    }
}
