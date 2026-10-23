import AVFoundation

/// プレビューの動画を再生する `AVPlayer` とループの扱い（FR-031・FR-033）。
/// ループは `AVPlayerLooper` を使わず、1つのアイテムを終端で先頭へ戻す。
/// `AVPlayerLooper` はアイテムを複製して切り替えるため、AVPlayerView の 15 秒スキップで終端を越えると
/// 映像が止まる（bug: preview-skip-forward-frame-freeze）。
@MainActor
public final class VideoPlayback {
    public let player: AVPlayer
    private var endObserver: NSObjectProtocol?

    public init(asset: AVAsset, loop: Bool) {
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        self.player = player

        guard loop else {
            player.actionAtItemEnd = .pause
            return
        }
        // 終端で止めずに先頭へ戻す。rate は変えないので、再生中ならそのまま続き、一時停止中なら先頭で止まったまま
        player.actionAtItemEnd = .none
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak player] _ in
            MainActor.assumeIsolated {
                player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    /// 終端の監視をやめて再生を止める。以降この再生は使わない
    public func invalidate() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    /// 現在位置から `seconds` 秒動かした位置を `[0, duration]` に丸めて返す。位置か長さが定まらなければ nil
    public nonisolated static func seekTarget(from current: Double, by seconds: Double, duration: Double) -> Double? {
        guard duration.isFinite, duration > 0, current.isFinite else { return nil }
        return min(max(0, current + seconds), duration)
    }
}
