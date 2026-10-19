import AVFoundation
import AVKit
import AppKit

@MainActor
final class VideoPreviewView: NSView {
    private let playerView = AVPlayerView()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var endObserver: NSObjectProtocol?

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    var isPlaying: Bool {
        guard let player else { return false }
        return player.rate != 0
    }

    func configure(url: URL, autoplay: Bool, loop: Bool, fileName: String) {
        stop()

        let player = AVQueuePlayer()
        let item = AVPlayerItem(url: url)

        if loop {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
            endObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: item,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.player?.pause()
                }
            }
        }

        self.player = player
        playerView.player = player
        setAccessibilityLabel(fileName)

        if autoplay {
            player.play()
        } else {
            player.pause()
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func stop() {
        player?.pause()
        looper?.disableLooping()
        looper = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player?.removeAllItems()
        playerView.player = nil
        player = nil
        setAccessibilityLabel("")
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.rate != 0 {
            player.pause()
        } else {
            player.play()
        }
    }

    private func setup() {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = false
        addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }
}
