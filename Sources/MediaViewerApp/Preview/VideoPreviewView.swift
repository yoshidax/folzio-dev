import AVFoundation
import AVKit
import AppKit
import os

@MainActor
final class VideoPreviewView: NSView {
    private let playerView = AVPlayerView()
    private let performanceSignposter = OSSignposter(
        subsystem: "local.my-img-viewer.MediaViewer",
        category: "Performance"
    )
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var endObserver: NSObjectProtocol?
    private var timeControlObservation: NSKeyValueObservation?
    private var playbackIntervalState: OSSignpostIntervalState?
    private var playbackIntervalStarted = false
    private var playbackGeneration = 0

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

        let generation = playbackGeneration
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleTimeControlStatusChange(generation: generation)
            }
        }

        if autoplay {
            beginPlaybackIntervalIfNeeded()
            player.play()
        } else {
            player.pause()
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func stop() {
        playbackGeneration &+= 1
        endPlaybackInterval()
        playbackIntervalStarted = false

        timeControlObservation?.invalidate()
        timeControlObservation = nil

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
            beginPlaybackIntervalIfNeeded()
            player.play()
        }
    }

    func seek(by seconds: Double) {
        guard let player,
              let duration = player.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0 else {
            return
        }

        let current = player.currentTime().seconds
        guard current.isFinite else { return }
        let target = min(max(0, current + seconds), duration)
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func beginPlaybackIntervalIfNeeded() {
        guard !playbackIntervalStarted else { return }
        playbackIntervalStarted = true
        playbackIntervalState = performanceSignposter.beginInterval("VideoPlaybackStart")
    }

    private func endPlaybackInterval() {
        guard let state = playbackIntervalState else { return }
        playbackIntervalState = nil
        performanceSignposter.endInterval("VideoPlaybackStart", state)
    }

    private func handleTimeControlStatusChange(generation: Int) {
        guard generation == playbackGeneration,
              let player,
              player.timeControlStatus == .playing else {
            return
        }
        endPlaybackInterval()
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
