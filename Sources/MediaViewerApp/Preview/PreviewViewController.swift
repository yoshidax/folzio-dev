import AppKit
import MediaViewerCore

@MainActor
final class PreviewViewController: NSViewController {
    private let model: BrowserModel
    private let decoder: any ImageDecoding
    private let imageView = ImagePreviewView()
    private let videoView = VideoPreviewView()
    private let containerView = NSView()
    private var animatedTask: Task<Void, Never>?
    private var configuredVideoURL: URL?

    init(model: BrowserModel, decoder: any ImageDecoding) {
        self.model = model
        self.decoder = decoder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var primaryFocusView: NSView {
        if case .video = model.preview {
            return videoView
        }
        return imageView
    }

    var onDoubleClick: (() -> Void)? {
        get { imageView.onDoubleClick }
        set { imageView.onDoubleClick = newValue }
    }

    func togglePlayback() {
        guard !videoView.isHidden else { return }
        videoView.togglePlayPause()
    }

    @discardableResult
    func seekVideo(by seconds: Double) -> Bool {
        guard case .video = model.preview else { return false }
        videoView.seek(by: seconds)
        return true
    }

    override func loadView() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.isHidden = true

        containerView.addSubview(imageView)
        containerView.addSubview(videoView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            videoView.topAnchor.constraint(equalTo: containerView.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        view = containerView
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
            _ = model.stopPlaybackSignal
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
            stopVideo()
            showImageView()
            imageView.showEmpty()
        case let .loading(url), let .animatedImageData(url, _):
            // .animatedImageData は仮の表示（T196 で置き換える）
            animatedTask?.cancel()
            animatedTask = nil
            stopVideo()
            showImageView()
            imageView.showLoading(fileName: url.lastPathComponent)
        case let .image(decoded):
            animatedTask?.cancel()
            animatedTask = nil
            stopVideo()
            showImageView()
            imageView.showImage(
                decoded,
                fileName: model.selection.focused?.lastPathComponent ?? ""
            )
        case let .animatedImage(url):
            stopVideo()
            showImageView()
            loadAnimatedImage(url)
        case let .video(url):
            animatedTask?.cancel()
            animatedTask = nil
            imageView.showEmpty()
            showVideoView()
            if configuredVideoURL != url {
                configuredVideoURL = url
                let playback = model.playbackRequest
                videoView.configure(
                    url: url,
                    autoplay: playback.autoplay,
                    loop: playback.loop,
                    fileName: url.lastPathComponent
                )
            }
        case let .unavailable(name, reason):
            animatedTask?.cancel()
            animatedTask = nil
            stopVideo()
            showImageView()
            imageView.showUnavailable(name: name, reason: reason)
        }
    }

    private func showImageView() {
        imageView.isHidden = false
        videoView.isHidden = true
    }

    private func showVideoView() {
        imageView.isHidden = true
        videoView.isHidden = false
    }

    private func stopVideo() {
        videoView.stop()
        videoView.isHidden = true
        configuredVideoURL = nil
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
