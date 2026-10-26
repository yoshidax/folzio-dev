import AppKit
import ImageIO
import MediaViewerCore

enum AnimatedSource: Sendable {
    case url(URL)
    case data(Data)
}

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
    /// 画像を表示している／していないが入れ替わったとき（最初のフレーム・画像のクリア）
    var onDisplayedImageChange: (() -> Void)?

    private var displayedImage: CGImage? {
        didSet {
            guard (oldValue == nil) != (displayedImage == nil) else { return }
            updateAccessibilityValue()
            onDisplayedImageChange?()
        }
    }
    /// 表示倍率（FR-133）。frame だけに反映し、contents やアニメーションには触れない
    private var zoom = PreviewZoom.fit

    var isShowingImage: Bool { displayedImage != nil }
    private var fallbackImage: CGImage?
    private var animatedSource: AnimatedSource?
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
        // 拡大してビューポートからはみ出した部分を表示しない（FR-133）
        layer?.masksToBounds = true

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

    /// 倍率を適用する。`announce` は明示的な操作による変更のときだけ true にし、新しい倍率を読み上げる（FR-138）
    func applyZoom(_ zoom: PreviewZoom, announce: Bool) {
        let changed = zoom != self.zoom
        self.zoom = zoom
        updateAccessibilityValue()
        if changed {
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
        guard announce, changed, isShowingImage else { return }
        NSAccessibility.post(
            element: self,
            notification: .announcementRequested,
            userInfo: [
                .announcement: Self.percentText(zoom),
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
    }

    private func updateAccessibilityValue() {
        // 画像がない状態では倍率を公開しない（FR-138）
        setAccessibilityValue(isShowingImage ? Self.percentText(zoom) : nil)
    }

    private static func percentText(_ zoom: PreviewZoom) -> String {
        "\(zoom.percentage)%"
    }

    func showImage(_ image: DecodedImage, fileName: String) {
        stopAnimation(clearAnimatedSource: true)
        self.fileName = fileName
        setAccessibilityLabel(fileName)
        messageStack.isHidden = true
        spinner.stopAnimation(nil)
        setDisplayed(image.cgImage)
    }

    func showAnimated(url: URL, fileName: String, fallback: DecodedImage?) {
        showAnimated(source: .url(url), fileName: fileName, fallback: fallback)
    }

    func showAnimated(source: AnimatedSource, fileName: String, fallback: DecodedImage?) {
        stopAnimation(clearAnimatedSource: false)
        self.fileName = fileName
        animatedSource = source
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
        stopAnimation(clearAnimatedSource: true)
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
        stopAnimation(clearAnimatedSource: true)
        fileName = ""
        setAccessibilityLabel("")
        displayedImage = nil
        contentLayer.contents = nil
        spinner.stopAnimation(nil)
        messageStack.isHidden = true
    }

    func showUnavailable(name: String, reason: String) {
        stopAnimation(clearAnimatedSource: true)
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

    func showMessage(_ text: String) {
        stopAnimation(clearAnimatedSource: true)
        setAccessibilityLabel(text)
        displayedImage = nil
        contentLayer.contents = nil

        spinner.stopAnimation(nil)
        spinner.isHidden = true
        nameLabel.stringValue = text
        detailLabel.stringValue = ""
        messageStack.isHidden = false
    }

    func transitionSnapshot() -> (image: CGImage?, frame: CGRect, gravity: CALayerContentsGravity) {
        layoutSubtreeIfNeeded()
        if let displayedImage {
            // contentLayer.contents と同じ画像を共有し、再デコード・再描画しない。
            return (displayedImage, contentLayer.frame, contentLayer.contentsGravity)
        }
        guard !messageStack.isHidden, let layer else { return (nil, .zero, .resize) }
        displayIfNeeded()
        // 文字・spinner の範囲だけを描き、大きなプレビュー全面の bitmap を作らない。
        let rect = messageStack.frame.integral
        let scale = backingScale
        guard rect.width > 0, rect.height > 0,
              let context = CGContext(data: nil, width: Int(rect.width * scale), height: Int(rect.height * scale),
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (nil, .zero, .resize) }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -rect.minX, y: -rect.minY)
        layer.render(in: context)
        return (context.makeImage(), rect, .resize)
    }

    fileprivate func isCurrentAnimation(_ state: AnimationState) -> Bool {
        animationState === state
    }

    fileprivate func displayFrame(_ image: CGImage) {
        setDisplayed(image)
    }

    private func startAnimation() {
        guard let source = animatedSource else { return }

        let state = AnimationState(view: self)
        animationState = state

        let handler: CGImageSourceAnimationBlock = { _, image, stop in
            MainActor.assumeIsolated {
                state.receive(image, stop: stop)
            }
        }
        let status: OSStatus
        switch source {
        case let .url(url):
            status = CGAnimateImageAtURLWithBlock(url as CFURL, nil, handler)
        case let .data(data):
            status = CGAnimateImageDataWithBlock(data as CFData, nil, handler)
        }

        guard status == noErr else {
            animationState = nil
            if fallbackImage == nil {
                showUnavailable(name: fileName, reason: "アニメーションを表示できません")
            }
            return
        }
    }

    private func stopAnimation(clearAnimatedSource: Bool) {
        animationState?.shouldStop = true
        animationState = nil
        spinner.stopAnimation(nil)
        if clearAnimatedSource {
            animatedSource = nil
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
        let fitted = FitCalculator.frame(
            imageSize: CGSize(width: image.width, height: image.height),
            in: pixelContainer,
            zoom: zoom
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
        guard animatedSource != nil else { return }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            stopAnimation(clearAnimatedSource: false)
            if let fallbackImage {
                setDisplayed(fallbackImage)
            }
        } else if animationState == nil {
            startAnimation()
        }
    }
}
