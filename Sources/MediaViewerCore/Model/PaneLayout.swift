/// ペインの種類（FR-088〜094、research.md R40）。`Pane.allCases` の順は Tab の巡回順（ツリー → ファイルリスト → プレビュー）。
public enum Pane: Sendable, Equatable, CaseIterable {
    case tree, fileList, preview
}

/// ツールバーのボタンとメニュー項目の対象（FR-088・089）。保存しない。状態の持ち主は `MainSplitViewController` だけ。
public enum SoloPane: Sendable, Equatable {
    case fileList, preview
}

/// ペインの表示状態（FR-088〜093、research.md R40）。値を3つだけに保ち、ツリーだけを隠す状態などは持たない。
/// 保存しない。状態の持ち主は `MainSplitViewController` だけ。起動のたびに `.all` で始まる。
public enum PaneLayout: Sendable, Equatable {
    /// 3ペイン表示（既定）
    case all
    /// ツリーとプレビューを隠す
    case fileListOnly
    /// ツリーとファイルリストを隠す
    case previewOnly

    /// `nil` は `.all`、それ以外はその側だけの表示（FR-088）
    public init(soloPane: SoloPane?) {
        switch soloPane {
        case .none:
            self = .all
        case .fileList:
            self = .fileListOnly
        case .preview:
            self = .previewOnly
        }
    }

    /// ツールバーの押下とメニューのチェックの対象。`.all` は `nil`（FR-089）
    public var soloPane: SoloPane? {
        switch self {
        case .all:
            return nil
        case .fileListOnly:
            return .fileList
        case .previewOnly:
            return .preview
        }
    }

    /// メニュー・ショートカット。いまその側だけの表示なら `.all`、そうでなければその側だけの表示（FR-089・090）
    public func toggling(_ pane: SoloPane) -> PaneLayout {
        switch (self, pane) {
        case (.fileListOnly, .fileList), (.previewOnly, .preview):
            return .all
        case (_, .fileList):
            return .fileListOnly
        case (_, .preview):
            return .previewOnly
        }
    }

    /// ツールバーのボタングループ（`selectAny`）が報告した押下状態から次の状態を決める（FR-089）。
    /// 両方 true なら直前に押されていなかった側だけを残す（直前が `.all` なら変えない）
    public func applyingToolbarSelection(fileListSelected: Bool, previewSelected: Bool) -> PaneLayout {
        switch (fileListSelected, previewSelected) {
        case (false, false):
            return .all
        case (true, false):
            return .fileListOnly
        case (false, true):
            return .previewOnly
        case (true, true):
            switch self {
            case .fileListOnly:
                return .previewOnly
            case .previewOnly:
                return .fileListOnly
            case .all:
                return .all
            }
        }
    }

    /// `layout` でそのペインを表示している（FR-088・092）
    public func isVisible(_ pane: Pane) -> Bool {
        switch self {
        case .all:
            return true
        case .fileListOnly:
            return pane == .fileList
        case .previewOnly:
            return pane == .preview
        }
    }

    /// 切り替え後にフォーカスを移す先。`nil` は移さない（FR-091）
    public func focusTarget(afterSwitchingFrom focused: Pane?) -> Pane? {
        switch self {
        case .all:
            return nil
        case .fileListOnly:
            return focused == .fileList ? nil : .fileList
        case .previewOnly:
            return focused == .preview ? nil : .preview
        }
    }

    /// プレビューのみ表示に切り替えたときに、最初のファイルを自動選択してよいか（FR-093）。
    /// 通常の読み込み中と検索中の `.loading` では自動選択しない（読み込み完了後もやり直さない）
    public static func shouldAutoSelectEntry(in listing: FolderListing) -> Bool {
        listing.state != .loading
    }

    /// プレビューのみ表示で、読み込み中でなく、表示中の一覧にメディアが1件もないとき true（FR-093）。
    /// プレビューに「表示するメディアファイルがありません」を出す
    public func showsNoMediaMessage(in listing: FolderListing) -> Bool {
        self == .previewOnly
            && listing.state != .loading
            && !listing.files.contains { $0.kind.isMedia }
    }
}

/// 表示状態とフルスクリーンから、実際に表示するペインを決める純粋計算（FR-094、research.md R41・R44）。
/// 保存しない。状態の持ち主は `MainSplitViewController` だけ。
public struct PanePresentation: Sendable, Equatable {
    public let layout: PaneLayout
    public let isFullScreen: Bool

    public init(layout: PaneLayout, isFullScreen: Bool) {
        self.layout = layout
        self.isFullScreen = isFullScreen
    }

    /// フルスクリーン中は `[.preview]`。それ以外は `layout` で表示するペイン（ツリー → ファイルリスト → プレビューの順）
    public var visiblePanes: [Pane] {
        if isFullScreen {
            return [.preview]
        }
        return Pane.allCases.filter { layout.isVisible($0) }
    }

    public func isVisible(_ pane: Pane) -> Bool {
        visiblePanes.contains(pane)
    }

    /// 3つとも表示（ペイン幅の保持・復元と自動保存の再開に使う。FR-094）
    public var showsAllPanes: Bool {
        !isFullScreen && layout == .all
    }

    /// ファイルリストが隠れていてプレビューが見えている（矢印キーで隠れたファイルリストの選択を動かす。FR-046・093）
    public var navigatesHiddenFileList: Bool {
        !isVisible(.fileList) && isVisible(.preview)
    }
}

/// 隠したペインに関わる操作の可否（FR-062・065・080・090・092・094、research.md R42）。
/// 保存しない。状態の持ち主は `MainSplitViewController` だけ。
public struct PaneCommands: Sendable, Equatable {
    public let layout: PaneLayout
    public let isFullScreen: Bool
    public let isEditingText: Bool

    public init(layout: PaneLayout, isFullScreen: Bool, isEditingText: Bool) {
        self.layout = layout
        self.isFullScreen = isFullScreen
        self.isEditingText = isEditingText
    }

    /// ⌃⌘2・⌃⌘3・ツールバーのボタン（FR-090・094）
    public var canChangeLayout: Bool {
        !isFullScreen && !isEditingText
    }

    /// ⌥⌘1〜3（FR-092）
    public func canFocus(_ pane: Pane) -> Bool {
        layout.isVisible(pane)
    }

    /// ⇧⌘F（FR-065・092）
    public var canGoToFavorites: Bool {
        !isFullScreen && !isEditingText && layout.isVisible(.tree)
    }

    /// ⌃⌘T。ツリー側の判定と AND を取る（FR-062・092）
    public var allowsAddingFavorite: Bool {
        !isEditingText && layout.isVisible(.tree)
    }

    /// ⌘F（FR-080・092）
    public var canSearch: Bool {
        !isFullScreen && !isEditingText && layout.isVisible(.fileList)
    }

    /// ⌘[・⌘]・「移動」メニュー・ツールバーの戻る・進む（FR-112）。
    /// 履歴の有無は `HistoryNavigator` と AND を取る
    public var canNavigateHistory: Bool {
        !isFullScreen && !isEditingText
    }
}

/// 3ペインへ戻すときの仕切りの位置（FR-088、research.md R41）。保存しない。状態の持ち主は `MainSplitViewController` だけ。
public enum PaneWidths {
    /// 3ペインへ戻すときの2本の仕切りの位置（FR-088）。`savedWidths`・`minimumWidths` は
    /// ツリー・ファイルリスト・プレビューの3要素。
    /// プレビューが最小幅に足りなければ、ファイルリスト → ツリーの順に最小幅まで詰める。
    /// 不正な入力では初回の既定（220 / 360 / 残り）を使う
    public static func dividerPositions(
        savedWidths: [Double],
        totalWidth: Double,
        dividerThickness: Double,
        minimumWidths: [Double]
    ) -> [Double] {
        let minimums = minimumWidths.count == 3 && minimumWidths.allSatisfy({ $0.isFinite })
            ? minimumWidths
            : [160, 240, 320]

        var tree: Double
        var list: Double
        if savedWidths.count == 3 && savedWidths.allSatisfy({ $0.isFinite }) {
            tree = savedWidths[0]
            list = savedWidths[1]
        } else {
            tree = 220
            list = 360
        }

        let thickness = dividerThickness.isFinite && dividerThickness >= 0 ? dividerThickness : 0
        let preview = totalWidth - tree - list - 2 * thickness
        let previewMinimum = minimums[2]

        if preview < previewMinimum {
            var deficit = previewMinimum - preview
            let listReduction = min(deficit, max(0, list - minimums[1]))
            list -= listReduction
            deficit -= listReduction
            if deficit > 0 {
                let treeReduction = min(deficit, max(0, tree - minimums[0]))
                tree -= treeReduction
            }
        }

        return [tree, tree + thickness + list]
    }
}
