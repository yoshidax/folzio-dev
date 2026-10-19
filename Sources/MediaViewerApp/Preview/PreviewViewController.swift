import AppKit
import MediaViewerCore

@MainActor
final class PreviewViewController: NSViewController {
    private let model: BrowserModel
    private let decoder: any ImageDecoding
    private let imageView = ImagePreviewView()
    private var animatedTask: Task<Void, Never>?

    init(model: BrowserModel, decoder: any ImageDecoding) {
        self.model = model
        self.decoder = decoder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var primaryFocusView: NSView { imageView }

    override func loadView() {
        view = imageView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeScreen(_:)),
            name: NSWindow.didChangeScreenNotification,
            object: nil
        )
        updateFromModel()
        observePreview()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateScreenMaxPixel()
    }

    private func observePreview() {
        withObservationTracking {
            _ = model.preview
            _ = model.selection.focused
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateFromModel()
                self?.observePreview()
            }
        }
    }

    private func updateFromModel() {
        switch model.preview {
        case .empty:
            animatedTask?.cancel()
            animatedTask = nil
            imageView.showEmpty()
        case let .loading(url):
            animatedTask?.cancel()
            animatedTask = nil
            imageView.showLoading(fileName: url.lastPathComponent)
        case let .image(decoded):
            animatedTask?.cancel()
            animatedTask = nil
            imageView.showImage(
                decoded,
                fileName: model.selection.focused?.lastPathComponent ?? ""
            )
        case let .animatedImage(url):
            loadAnimatedImage(url)
        case .video:
            animatedTask?.cancel()
            animatedTask = nil
            imageView.showEmpty()
        case let .unavailable(name, reason):
            animatedTask?.cancel()
            animatedTask = nil
            imageView.showUnavailable(name: name, reason: reason)
        }
    }

    private func loadAnimatedImage(_ url: URL) {
        animatedTask?.cancel()
        imageView.showLoading(fileName: url.lastPathComponent)

        let maxPixelSize = max(1, model.screenMaxPixel)
        animatedTask = Task { [weak self] in
            guard let self else { return }

            let fallback: DecodedImage?
            do {
                fallback = try await self.decoder.decode(url, maxPixelSize: maxPixelSize)
            } catch {
                fallback = nil
            }

            guard !Task.isCancelled else { return }
            guard case let .animatedImage(current) = self.model.preview, current == url else {
                return
            }
            self.imageView.showAnimated(
                url: url,
                fileName: url.lastPathComponent,
                fallback: fallback
            )
        }
    }

    private func updateScreenMaxPixel() {
        guard let screen = view.window?.screen ?? NSScreen.main else { return }
        let frame = screen.frame.size
        let pixels = Int(max(frame.width, frame.height) * screen.backingScaleFactor)
        guard pixels > 0, pixels != model.screenMaxPixel else { return }
        model.screenMaxPixel = pixels
    }

    @objc private func windowDidChangeScreen(_ notification: Notification) {
        guard let window = view.window,
              let changedWindow = notification.object as? NSWindow,
              changedWindow === window else {
            return
        }
        updateScreenMaxPixel()
    }
}
