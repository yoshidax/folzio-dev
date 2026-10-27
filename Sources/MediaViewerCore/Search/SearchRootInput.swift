import Foundation

/// 検索起点欄の入力元（FR-081・142、data-model.md 1）。
///
/// - `typed` はユーザーが直接入力・編集した文字列で、既存の `SearchRoot.parse` の規則で解釈する
/// - `picked` は標準フォルダ選択パネルで確定した絶対 file URL で、選択した URL をそのまま使う（trim しない）
///
/// 初期状態は `typed`。`picked` は確定後の検証成功からのみ作る。起点欄のユーザー編集は同じ文字列へ戻しても
/// `typed` にし、キーワード編集・パネルの取消・失敗・再表示では変えない
public enum SearchRootInput: Sendable, Equatable {
    case typed(String)
    case picked(URL)

    /// 起点欄に表示する文字列。`picked` は引用符・エスケープを加えない絶対パス
    public var displayText: String {
        switch self {
        case let .typed(text):
            return text
        case let .picked(url):
            return url.path
        }
    }

    /// 検索と初期位置の両方が使う解釈。`picked` は選択 URL をそのまま返し、リンク解決は `SearchRoot.validate` に任せる
    public func resolvedInput(home: URL) -> Result<URL, SearchRootError> {
        switch self {
        case let .typed(text):
            return SearchRoot.parse(text, home: home)
        case let .picked(url):
            return .success(url)
        }
    }
}

/// 親の検索シートが持つ非同期処理の種別（FR-143、data-model.md 4）
public enum SearchPanelOperation: Sendable, Equatable {
    case idle
    case resolvingInitialLocation
    case validatingSelection
    case validatingSearch
}

/// 非同期処理の開始時に捕捉する入力・選択 URL・世代。完了の採否はこの値と現在の状態だけで決める
public struct SearchPanelOperationTicket: Sendable, Equatable {
    public let operation: SearchPanelOperation
    public let revision: Int
    public let requestGeneration: Int
    public let input: SearchRootInput
    public let keyword: String
    public let selection: URL?

    init(
        operation: SearchPanelOperation,
        revision: Int,
        requestGeneration: Int,
        input: SearchRootInput,
        keyword: String,
        selection: URL? = nil
    ) {
        self.operation = operation
        self.revision = revision
        self.requestGeneration = requestGeneration
        self.input = input
        self.keyword = keyword
        self.selection = selection
    }
}

/// 検索シートの入力元と、初期位置の解決・確定後の検証・検索検証の競合を判断する小さな状態（data-model.md 4）。
///
/// MainActor 上の操作を直列に渡す前提の値型で、I/O を持たない。完了の採用は
/// 「捕捉した revision・requestGeneration・処理種別が現在の値と一致し、`isActive` である」場合だけ行う
public struct SearchPanelInputState: Sendable, Equatable {
    public private(set) var rootInput: SearchRootInput
    public private(set) var keyword: String
    /// 入力元とキーワードの変更回数。古い検証結果の採否に使う
    public private(set) var revision: Int
    /// 検索シートが開いているか。終了後の完了を採用しない
    public private(set) var isActive: Bool
    public private(set) var pendingOperation: SearchPanelOperation
    /// 処理開始・失効で進める依頼世代。同じ入力でも別の依頼を区別する
    public private(set) var requestGeneration: Int

    public init(rootInput: SearchRootInput, keyword: String = "") {
        self.rootInput = rootInput
        self.keyword = keyword
        revision = 0
        isActive = true
        pendingOperation = .idle
        requestGeneration = 0
    }

    public var displayText: String {
        rootInput.displayText
    }

    /// 起点欄のユーザー編集。同じ文字列へ戻しても `typed` にし、保留中の処理を失効させる
    public mutating func updateRootText(_ text: String) {
        guard isActive else { return }
        rootInput = .typed(text)
        revision &+= 1
        invalidatePending()
    }

    /// キーワードの編集。起点の入力元は変えず、保留中の処理を失効させる
    public mutating func updateKeyword(_ text: String) {
        guard isActive else { return }
        keyword = text
        revision &+= 1
        invalidatePending()
    }

    /// 標準パネルの確定成功。選択 URL を `picked` として保持し、古い処理を失効させる
    public mutating func applyPickedRoot(_ url: URL) {
        guard isActive else { return }
        rootInput = .picked(url)
        revision &+= 1
        invalidatePending()
    }

    /// 検索シートの終了。以降の完了を採用しない
    public mutating func close() {
        isActive = false
        revision &+= 1
        invalidatePending()
    }

    /// 標準パネルの初期位置解決の開始。パネル表示中の重複開始と検索検証中は受け付けない
    public mutating func beginInitialLocationResolution(
        panelPresented: Bool
    ) -> SearchPanelOperationTicket? {
        guard isActive, !panelPresented, pendingOperation == .idle else { return nil }
        requestGeneration &+= 1
        pendingOperation = .resolvingInitialLocation
        return makeTicket(operation: .resolvingInitialLocation)
    }

    /// 確定後の再検証の開始。選択 URL・入力・依頼世代を捕捉する。重複確定とパネル表示中は受け付けない
    public mutating func beginSelectionValidation(
        _ url: URL,
        panelPresented: Bool
    ) -> SearchPanelOperationTicket? {
        guard isActive, !panelPresented, pendingOperation == .idle else { return nil }
        requestGeneration &+= 1
        pendingOperation = .validatingSelection
        return makeTicket(operation: .validatingSelection, selection: url)
    }

    /// 検索の受理。空キーワードは従来どおり無操作で、保留中の処理も失効させない。
    /// 受理した場合は初期位置・選択の検証を先に失効させてから検索検証へ遷移する
    public mutating func beginSearchValidation(
        panelPresented: Bool
    ) -> SearchPanelOperationTicket? {
        guard isActive, !panelPresented else { return nil }
        guard SearchPattern(keyword: keyword) != nil else { return nil }
        guard pendingOperation != .validatingSearch else { return nil }
        requestGeneration &+= 1
        pendingOperation = .validatingSearch
        return makeTicket(operation: .validatingSearch)
    }

    /// 捕捉した処理の完了を採用する。成功した検索検証だけが親を終了させる。
    /// 一致しない完了（編集・終了・別の依頼・別種別）は状態を変えず `false` を返す
    @discardableResult
    public mutating func complete(_ ticket: SearchPanelOperationTicket, succeeded: Bool) -> Bool {
        guard isActive,
              pendingOperation == ticket.operation,
              revision == ticket.revision,
              requestGeneration == ticket.requestGeneration
        else { return false }

        pendingOperation = .idle
        if ticket.operation == .validatingSearch, succeeded {
            isActive = false
        }
        return true
    }

    private func makeTicket(
        operation: SearchPanelOperation,
        selection: URL? = nil
    ) -> SearchPanelOperationTicket {
        SearchPanelOperationTicket(
            operation: operation,
            revision: revision,
            requestGeneration: requestGeneration,
            input: rootInput,
            keyword: keyword,
            selection: selection
        )
    }

    private mutating func invalidatePending() {
        guard pendingOperation != .idle else { return }
        pendingOperation = .idle
        requestGeneration &+= 1
    }
}
