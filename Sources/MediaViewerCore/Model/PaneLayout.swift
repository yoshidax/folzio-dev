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
    /// スライドショーの実行中。開始・終了の遷移中も含めて、ペイン切り替えと履歴移動を止める。
    public let isSlideshowActive: Bool
    /// スライドショー終了後の復帰処理中。開始し直しや切り替えを止める。
    public let isRestoring: Bool

    public init(
        layout: PaneLayout,
        isFullScreen: Bool,
        isEditingText: Bool,
        isSlideshowActive: Bool = false,
        isRestoring: Bool = false
    ) {
        self.layout = layout
        self.isFullScreen = isFullScreen
        self.isEditingText = isEditingText
        self.isSlideshowActive = isSlideshowActive
        self.isRestoring = isRestoring
    }

    /// ⌃⌘2・⌃⌘3・ツールバーのボタン（FR-090・094）
    public var canChangeLayout: Bool {
        !isFullScreen && !isEditingText && !isSlideshowActive && !isRestoring
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
        !isFullScreen && !isEditingText && !isSlideshowActive && !isRestoring
    }
}

/// スライドショー中に横取りしてよいキーの種類（FR-123）。
public enum SlideshowKey: Sendable, Equatable {
    case escape
    case arrow
    case other
}

/// Esc・矢印を受け取る条件。modal・sheet・名前編集・復帰処理中は AppKit の入力先へ任せる（FR-105・123）。
public struct SlideshowInputPolicy: Sendable, Equatable {
    public let isActive: Bool
    public let isRestoring: Bool
    public let isTargetWindowKey: Bool
    public let hasSheet: Bool
    public let hasAppModal: Bool
    public let isEditingText: Bool
    /// メニュー追跡など、AppKit がキーを処理している間。App からは通常 false。
    public let menuOwnsInput: Bool

    public init(
        isActive: Bool,
        isRestoring: Bool,
        isTargetWindowKey: Bool,
        hasSheet: Bool,
        hasAppModal: Bool,
        isEditingText: Bool,
        menuOwnsInput: Bool = false
    ) {
        self.isActive = isActive
        self.isRestoring = isRestoring
        self.isTargetWindowKey = isTargetWindowKey
        self.hasSheet = hasSheet
        self.hasAppModal = hasAppModal
        self.isEditingText = isEditingText
        self.menuOwnsInput = menuOwnsInput
    }

    public var acceptsKeys: Bool {
        isActive
            && !isRestoring
            && isTargetWindowKey
            && !hasSheet
            && !hasAppModal
            && !isEditingText
            && !menuOwnsInput
    }

    public func accepts(_ key: SlideshowKey) -> Bool {
        guard acceptsKeys else { return false }
        switch key {
        case .escape, .arrow:
            return true
        case .other:
            return false
        }
    }
}

/// 開始できるかの共通判断（FR-114・115）。読み込み中でも候補が表示されていれば開始でき、
/// 全画面からも開始できる。編集中・シート・アプリモーダル・実行中・復帰中は不可。
public struct SlideshowStartPolicy: Sendable, Equatable {
    public let hasCandidate: Bool
    public let isLoading: Bool
    public let isFullScreen: Bool
    public let isSlideshowActive: Bool
    public let isRestoring: Bool
    public let isEditingText: Bool
    public let hasSheet: Bool
    public let hasAppModal: Bool

    public init(
        hasCandidate: Bool,
        isLoading: Bool,
        isFullScreen: Bool,
        isSlideshowActive: Bool,
        isRestoring: Bool,
        isEditingText: Bool,
        hasSheet: Bool,
        hasAppModal: Bool
    ) {
        self.hasCandidate = hasCandidate
        self.isLoading = isLoading
        self.isFullScreen = isFullScreen
        self.isSlideshowActive = isSlideshowActive
        self.isRestoring = isRestoring
        self.isEditingText = isEditingText
        self.hasSheet = hasSheet
        self.hasAppModal = hasAppModal
    }

    public var canStart: Bool {
        hasCandidate
            && !isSlideshowActive
            && !isRestoring
            && !isEditingText
            && !hasSheet
            && !hasAppModal
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
