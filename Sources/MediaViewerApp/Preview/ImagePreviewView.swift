import AppKit
import ImageIO
import MediaViewerCore

@MainActor
final class ImagePreviewView: NSView {
    @MainActor
    fileprivate final class AnimationState: @unchecked Sendable {
        weak var view: ImagePreviewView?
        var shouldStop = false
        var frameCount = 0

        init(view: ImagePreviewView) {
            self.view = view
        }

        func receive(_ image: CGImage, stop: UnsafeMutablePointer<Bool>) {
            if shouldStop {
                stop.pointee = true
                return
            }
            guard let view, view.isCurrentAnimation(self) else {
                stop.pointee = true
                return
            }
            frameCount += 1
            view.displayFrame(image)
        }
    }

    private let contentLayer = CALayer()
    private let messageStack = NSStackView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let spinner = NSProgressIndicator()
    private let doubleClickRecognizer = NSClickGestureRecognizer()

    var onDoubleClick: (() -> Void)?

    private var displayedImage: CGImage?
    private var fallbackImage: CGImage?
    private var animatedURL: URL?
    private var animationState: AnimationState?
    private var fileName = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    private func setup() {
        wantsLayer = true
        layer = CALayer()

        contentLayer.contentsGravity = .resize
        contentLayer.magnificationFilter = .trilinear
        layer?.addSublayer(contentLayer)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.maximumNumberOfLines = 2

        detailLabel.alignment = .center
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.preferredMaxLayoutWidth = 400

        messageStack.translatesAutoresizingMaskIntoConstraints = false
        messageStack.orientation = .vertical
        messageStack.alignment = .centerX
        messageStack.spacing = 8
        messageStack.addArrangedSubview(spinner)
        messageStack.addArrangedSubview(nameLabel)
        messageStack.addArrangedSubview(detailLabel)
        messageStack.isHidden = true
        addSubview(messageStack)

        NSLayoutConstraint.activate([
            messageStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            messageStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            messageStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            messageStack.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
        ])

        doubleClickRecognizer.numberOfClicksRequired = 2
        doubleClickRecognizer.delaysPrimaryMouseButtonEvents = false
        doubleClickRecognizer.target = self
        doubleClickRecognizer.action = #selector(handleDoubleClick(_:))
        addGestureRecognizer(doubleClickRecognizer)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsDidChange(_:)),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    override func layout() {
        super.layout()
        guard displayedImage != nil, !bounds.isEmpty else {
            contentLayer.frame = .zero
            return
        }
        contentLayer.frame = fittedFrame()
        contentLayer.contentsScale = backingScale
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }

    func showImage(_ image: DecodedImage, fileName: String) {
        stopAnimation(clearAnimatedURL: true)
        self.fileName = fileName
        setAccessibilityLabel(fileName)
        messageStack.isHidden = true
        spinner.stopAnimation(nil)
        setDisplayed(image.cgImage)
    }

    func showAnimated(url: URL, fileName: String, fallback: DecodedImage?) {
        stopAnimation(clearAnimatedURL: false)
        self.fileName = fileName
        animatedURL = url
        fallbackImage = fallback?.cgImage
        setAccessibilityLabel(fileName)
        messageStack.isHidden = true
        spinner.stopAnimation(nil)

        if let fallback {
            setDisplayed(fallback.cgImage)
        } else {
            displayedImage = nil
            contentLayer.contents = nil
        }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            if fallback == nil {
                showUnavailable(name: fileName, reason: "アニメーションを表示できません")
            }
            return
        }

        startAnimation()
    }

    func showLoading(fileName: String) {
        stopAnimation(clearAnimatedURL: true)
        self.fileName = fileName
        setAccessibilityLabel(fileName)
        displayedImage = nil
        contentLayer.contents = nil

        spinner.isHidden = false
        spinner.startAnimation(nil)
        nameLabel.stringValue = "読み込み中…"
        detailLabel.stringValue = fileName
        messageStack.isHidden = false
    }

    func showEmpty() {
        stopAnimation(clearAnimatedURL: true)
        fileName = ""
        setAccessibilityLabel("")
        displayedImage = nil
        contentLayer.contents = nil
        spinner.stopAnimation(nil)
        messageStack.isHidden = true
    }

    func showUnavailable(name: String, reason: String) {
        stopAnimation(clearAnimatedURL: true)
        fileName = name
        setAccessibilityLabel(name)
        displayedImage = nil
        contentLayer.contents = nil

        spinner.stopAnimation(nil)
        spinner.isHidden = true
        nameLabel.stringValue = name
        detailLabel.stringValue = "表示できません\n\(reason)"
        messageStack.isHidden = false
    }

    fileprivate func isCurrentAnimation(_ state: AnimationState) -> Bool {
        animationState === state
    }

    fileprivate func displayFrame(_ image: CGImage) {
        setDisplayed(image)
    }

    private func startAnimation() {
        guard let url = animatedURL else { return }

        let state = AnimationState(view: self)
        animationState = state

        let status = CGAnimateImageAtURLWithBlock(url as CFURL, nil) { _, image, stop in
            MainActor.assumeIsolated {
                state.receive(image, stop: stop)
            }
        }

        guard status == noErr else {
            animationState = nil
            if fallbackImage == nil {
                showUnavailable(name: fileName, reason: "アニメーションを表示できません")
            }
            return
        }
    }

    private func stopAnimation(clearAnimatedURL: Bool) {
        animationState?.shouldStop = true
        animationState = nil
        spinner.stopAnimation(nil)
        if clearAnimatedURL {
            animatedURL = nil
            fallbackImage = nil
        }
    }

    private func setDisplayed(_ image: CGImage) {
        displayedImage = image
        contentLayer.contents = image
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private var backingScale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func fittedFrame() -> CGRect {
        guard let image = displayedImage else { return .zero }

        let scale = backingScale
        let pixelContainer = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let fitted = FitCalculator.fit(
            imageSize: CGSize(width: image.width, height: image.height),
            in: pixelContainer
        )

        return CGRect(
            x: fitted.origin.x / scale,
            y: fitted.origin.y / scale,
            width: fitted.width / scale,
            height: fitted.height / scale
        )
    }

    @objc private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onDoubleClick?()
    }

    @objc private func accessibilityDisplayOptionsDidChange(_ notification: Notification) {
        guard animatedURL != nil else { return }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            stopAnimation(clearAnimatedURL: false)
            if let fallbackImage {
                setDisplayed(fallbackImage)
            }
        } else if animationState == nil {
            startAnimation()
        }
    }
}
