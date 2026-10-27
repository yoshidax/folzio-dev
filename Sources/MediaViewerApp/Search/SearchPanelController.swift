import AppKit
import MediaViewerCore

/// システムの「キーボードナビゲーション」の設定に関わらず、Tab でフォーカスが止まるボタン（R39）
private final class KeyViewButton: NSButton {
    override var canBecomeKeyView: Bool { true }
}

/// 検索のモーダル（メインウインドウのシート）。キーワードと検索起点ディレクトリを受け取り、
/// 起点を確かめてから `onSearch` を呼ぶ（FR-080〜082）。「選択…」は標準の `NSOpenPanel` を
/// 子シートとして開き、確定後に非同期で再検証する（FR-141〜144）
@MainActor
final class SearchPanelController: NSViewController, NSSearchFieldDelegate {
    private let initialKeyword: String?
    private let initialRootPath: String
    private let onSearch: (SearchPattern, URL) -> Void

    private let keywordField = NSSearchField()
    private let rootField = NSTextField()
    private let reasonLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = KeyViewButton()
    private let cancelButton = KeyViewButton()
    private let searchButton = KeyViewButton()

    private var inputState: SearchPanelInputState
    private var initialLocationTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var folderPanel: NSOpenPanel?
    private var panelPresented = false
    private var initialFocusApplied = false

    init(keyword: String?, rootPath: String, onSearch: @escaping (SearchPattern, URL) -> Void) {
        initialKeyword = keyword
        initialRootPath = rootPath
        self.onSearch = onSearch
        inputState = SearchPanelInputState(rootInput: .typed(rootPath), keyword: keyword ?? "")
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let container = NSView()

        let keywordLabel = NSTextField(labelWithString: "検索キーワード")
        let rootLabel = NSTextField(labelWithString: "検索起点ディレクトリ")

        keywordField.placeholderString = "検索キーワード"
        keywordField.delegate = self
        keywordField.setAccessibilityLabel("検索キーワード")
        keywordField.stringValue = initialKeyword ?? ""

        configureRootField()

        reasonLabel.textColor = .systemRed
        reasonLabel.lineBreakMode = .byWordWrapping
        reasonLabel.maximumNumberOfLines = 0
        reasonLabel.isHidden = true
        reasonLabel.setAccessibilityLabel("エラー")

        chooseFolderButton.title = "選択…"
        chooseFolderButton.bezelStyle = .push
        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolder(_:))
        chooseFolderButton.setAccessibilityLabel("選択…")
        chooseFolderButton.setAccessibilityHelp("標準のフォルダ選択パネルを開きます")

        cancelButton.title = "キャンセル"
        cancelButton.bezelStyle = .push
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancel(_:))

        searchButton.title = "検索"
        searchButton.bezelStyle = .push
        searchButton.keyEquivalent = "\r"
        searchButton.target = self
        searchButton.action = #selector(search(_:))

        keywordField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rootField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rootField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chooseFolderButton.setContentHuggingPriority(.required, for: .horizontal)

        let rootRow = NSStackView(views: [rootField, chooseFolderButton])
        rootRow.orientation = .horizontal
        rootRow.alignment = .centerY
        rootRow.spacing = 8

        let buttons = NSStackView(views: [cancelButton, searchButton])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [
            keywordLabel, keywordField, rootLabel, rootRow, reasonLabel, buttons,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(14, after: keywordField)
        stack.setCustomSpacing(14, after: reasonLabel)
        stack.setCustomSpacing(14, after: rootRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            container.widthAnchor.constraint(equalToConstant: 520),
            keywordField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            rootRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            reasonLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        keywordField.nextKeyView = rootField
        rootField.nextKeyView = chooseFolderButton
        chooseFolderButton.nextKeyView = cancelButton
        cancelButton.nextKeyView = searchButton
        searchButton.nextKeyView = keywordField

        view = container
        refreshControls()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !initialFocusApplied else { return }
        initialFocusApplied = true
        view.window?.initialFirstResponder = keywordField
        view.window?.makeFirstResponder(keywordField)
        if initialKeyword != nil {
            keywordField.currentEditor()?.selectAll(nil)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        inputState.close()
        initialLocationTask?.cancel()
        selectionTask?.cancel()
        searchTask?.cancel()
    }

    private func configureRootField() {
        rootField.usesSingleLineMode = true
        rootField.cell?.isScrollable = true
        rootField.cell?.wraps = false
        rootField.lineBreakMode = .byTruncatingHead
        rootField.delegate = self
        rootField.setAccessibilityLabel("検索起点ディレクトリ")
        rootField.stringValue = initialRootPath
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === rootField {
            inputState.updateRootText(field.stringValue)
        } else if field === keywordField {
            inputState.updateKeyword(field.stringValue)
        }
        refreshControls()
    }

    /// 検索・選択の可否を決める。初期位置の解決中も検索でき、検索検証中は選択と重複検索を無効にする
    private func refreshControls() {
        let pending = inputState.pendingOperation
        chooseFolderButton.isEnabled = !panelPresented && pending == .idle
        searchButton.isEnabled = !panelPresented
            && pending != .validatingSearch
            && SearchPattern(keyword: keywordField.stringValue) != nil
        cancelButton.isEnabled = !panelPresented
    }

    @objc private func cancel(_ sender: Any?) {
        guard !panelPresented else { return }
        dismiss(self)
    }

    @objc private func search(_ sender: Any?) {
        guard !panelPresented else { return }
        guard let ticket = inputState.beginSearchValidation(panelPresented: panelPresented) else { return }
        refreshControls()
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let url: URL
            switch ticket.input.resolvedInput(home: home) {
            case let .success(value):
                url = value
            case let .failure(error):
                guard self.inputState.complete(ticket, succeeded: false) else { return }
                self.showReason(error.message)
                self.refreshControls()
                return
            }

            let result = await SearchRoot.validate(url)
            switch result {
            case let .success(root):
                guard self.inputState.complete(ticket, succeeded: true) else { return }
                guard let pattern = SearchPattern(keyword: ticket.keyword) else { return }
                self.dismiss(self)
                self.onSearch(pattern, root)
            case let .failure(error):
                guard self.inputState.complete(ticket, succeeded: false) else { return }
                self.showReason(error.message)
                self.refreshControls()
            }
        }
    }

    @objc private func chooseFolder(_ sender: Any?) {
        guard !panelPresented else { return }
        guard let ticket = inputState.beginInitialLocationResolution(panelPresented: panelPresented) else {
            return
        }
        refreshControls()
        initialLocationTask?.cancel()
        initialLocationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let result = await SearchFolderInitialLocation.resolve(
                input: ticket.input,
                defaultPath: self.initialRootPath,
                home: home
            )
            switch result {
            case let .success(directory):
                guard self.inputState.complete(ticket, succeeded: true) else { return }
                self.presentFolderPanel(initialDirectory: directory)
            case let .failure(error):
                guard self.inputState.complete(ticket, succeeded: false) else { return }
                self.showReason(error.message)
                self.refreshControls()
            }
        }
    }

    private func presentFolderPanel(initialDirectory: URL) {
        guard !panelPresented, let window = view.window else {
            showReason("フォルダ選択パネルを開けませんでした")
            refreshControls()
            return
        }

        let panel = NSOpenPanel()
        panel.title = "検索起点フォルダを選択"
        panel.message = "検索起点にするフォルダを選択してください。"
        panel.prompt = "選択"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = false
        panel.showsHiddenFiles = false
        panel.directoryURL = initialDirectory

        folderPanel = panel
        panelPresented = true
        refreshControls()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.panelPresented = false
            self.folderPanel = nil
            guard response == .OK, let url = panel.url else {
                self.focusChooseButton()
                self.refreshControls()
                return
            }
            self.beginSelectionValidation(url)
        }
    }

    private func beginSelectionValidation(_ url: URL) {
        guard let ticket = inputState.beginSelectionValidation(url, panelPresented: panelPresented) else {
            focusChooseButton()
            refreshControls()
            return
        }
        refreshControls()
        selectionTask?.cancel()
        selectionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await SearchRoot.validate(url)
            switch result {
            case .success:
                guard self.inputState.complete(ticket, succeeded: true) else { return }
                self.inputState.applyPickedRoot(url)
                self.rootField.stringValue = self.inputState.displayText
                self.hideReason()
                self.focusChooseButton()
                self.refreshControls()
            case let .failure(error):
                guard self.inputState.complete(ticket, succeeded: false) else { return }
                self.showReason(error.message)
                self.focusChooseButton()
                self.refreshControls()
            }
        }
    }

    private func focusChooseButton() {
        view.window?.makeFirstResponder(chooseFolderButton)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self.chooseFolderButton)
        }
    }

    private func hideReason() {
        reasonLabel.isHidden = true
    }

    /// 理由を入力欄の下に出し、読み上げる（モーダルは閉じない。FR-081）
    private func showReason(_ message: String) {
        reasonLabel.stringValue = message
        reasonLabel.isHidden = false
        NSAccessibility.post(
            element: NSApp.mainWindow ?? reasonLabel,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
