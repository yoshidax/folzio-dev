import AppKit
import MediaViewerCore

/// システムの「キーボードナビゲーション」の設定に関わらず、Tab でフォーカスが止まるボタン（R39）
private final class KeyViewButton: NSButton {
    override var canBecomeKeyView: Bool { true }
}

/// 検索のモーダル（メインウインドウのシート）。検索キーワードと検索起点ディレクトリを受け取り、
/// 起点を確かめてから `onSearch` を呼ぶ（FR-080〜082、research.md R39）
@MainActor
final class SearchPanelController: NSViewController, NSTextFieldDelegate {
    private let initialKeyword: String?
    private let initialRootPath: String
    private let onSearch: (SearchPattern, URL) -> Void

    private let keywordField = NSTextField()
    private let rootField = NSTextField()
    private let reasonLabel = NSTextField(labelWithString: "")
    private let cancelButton = KeyViewButton()
    private let searchButton = KeyViewButton()
    private var isValidating = false

    init(keyword: String?, rootPath: String, onSearch: @escaping (SearchPattern, URL) -> Void) {
        self.initialKeyword = keyword
        self.initialRootPath = rootPath
        self.onSearch = onSearch
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
        configureField(keywordField, label: "検索キーワード")
        configureField(rootField, label: "検索起点ディレクトリ")
        keywordField.stringValue = initialKeyword ?? ""
        rootField.stringValue = initialRootPath

        reasonLabel.textColor = .systemRed
        reasonLabel.lineBreakMode = .byWordWrapping
        reasonLabel.maximumNumberOfLines = 0
        reasonLabel.isHidden = true

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

        let buttons = NSStackView(views: [cancelButton, searchButton])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [keywordLabel, keywordField, rootLabel, rootField, reasonLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(14, after: keywordField)
        stack.setCustomSpacing(14, after: reasonLabel)
        stack.setCustomSpacing(14, after: rootField)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            container.widthAnchor.constraint(equalToConstant: 420),
            keywordField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            rootField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            reasonLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        keywordField.nextKeyView = rootField
        rootField.nextKeyView = cancelButton
        cancelButton.nextKeyView = searchButton
        searchButton.nextKeyView = keywordField

        view = container
        updateSearchButton()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.initialFirstResponder = keywordField
        view.window?.makeFirstResponder(keywordField)
        if initialKeyword != nil {
            keywordField.currentEditor()?.selectAll(nil)
        }
    }

    private func configureField(_ field: NSTextField, label: String) {
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.lineBreakMode = .byTruncatingHead
        field.delegate = self
        field.setAccessibilityLabel(label)
    }

    func controlTextDidChange(_ obj: Notification) {
        updateSearchButton()
    }

    /// キーワードが空（前後の空白だけを含む）か確認中なら「検索」を無効にする。既定ボタンのため Return も効かない（FR-082）
    private func updateSearchButton() {
        searchButton.isEnabled = !isValidating && SearchPattern(keyword: keywordField.stringValue) != nil
    }

    @objc private func cancel(_ sender: Any?) {
        dismiss(self)
    }

    @objc private func search(_ sender: Any?) {
        guard !isValidating, let pattern = SearchPattern(keyword: keywordField.stringValue) else { return }
        let parsed = SearchRoot.parse(rootField.stringValue, home: FileManager.default.homeDirectoryForCurrentUser)
        let url: URL
        switch parsed {
        case let .success(value):
            url = value
        case let .failure(error):
            showReason(error)
            return
        }

        isValidating = true
        updateSearchButton()
        Task { @MainActor [weak self] in
            let result = await SearchRoot.validate(url)
            guard let self else { return }
            self.isValidating = false
            switch result {
            case let .success(root):
                self.dismiss(self)
                self.onSearch(pattern, root)
            case let .failure(error):
                self.showReason(error)
                self.updateSearchButton()
            }
        }
    }

    /// 理由を入力欄の下に出し、読み上げる（モーダルは閉じない。FR-081）
    private func showReason(_ error: SearchRootError) {
        reasonLabel.stringValue = error.message
        reasonLabel.isHidden = false
        NSAccessibility.post(
            element: NSApp.mainWindow ?? reasonLabel,
            notification: .announcementRequested,
            userInfo: [
                .announcement: error.message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
