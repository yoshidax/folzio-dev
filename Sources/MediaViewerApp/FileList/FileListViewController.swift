import AppKit
import MediaViewerCore

@MainActor
final class FileListViewController: NSViewController {
    private let model: BrowserModel
    private let listModeView: ListModeView
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let progressIndicator = NSProgressIndicator()

    init(model: BrowserModel) {
        self.model = model
        self.listModeView = ListModeView(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var primaryFocusView: NSView { listModeView.focusView }

    var onTogglePlayback: (() -> Void)? {
        get { listModeView.onTogglePlayback }
        set { listModeView.onTogglePlayback = newValue }
    }

    override func loadView() {
        let container = NSView()

        listModeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(listModeView)

        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.alignment = .center
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.isHidden = true

        container.addSubview(progressIndicator)
        container.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            listModeView.topAnchor.constraint(equalTo: container.topAnchor),
            listModeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            listModeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            listModeView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            progressIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            messageLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
        ])

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
        observeModel()
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.listing.state
            _ = model.listing.files
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refresh()
                self?.observeModel()
            }
        }
    }

    private func refresh() {
        messageLabel.isHidden = true
        messageLabel.stringValue = ""
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        listModeView.isHidden = false

        switch model.listing.state {
        case .loaded:
            break
        case .loading:
            listModeView.isHidden = true
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
            messageLabel.stringValue = "読み込み中…"
            messageLabel.isHidden = false
        case .empty:
            listModeView.isHidden = true
            messageLabel.stringValue = "対応するメディアファイルがありません"
            messageLabel.isHidden = false
        case .denied:
            listModeView.isHidden = true
            messageLabel.stringValue = "アクセスできません"
            messageLabel.isHidden = false
        case let .failed(reason):
            listModeView.isHidden = true
            messageLabel.stringValue = reason
            messageLabel.isHidden = false
        }
    }
}
