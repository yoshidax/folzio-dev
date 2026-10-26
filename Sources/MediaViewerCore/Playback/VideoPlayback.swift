import AVFoundation

/// プレビューの動画を再生する `AVPlayer` とループの扱い（FR-031・FR-033）。
/// `AVPlayer` は1つだけ作り、動画の切り替えはアイテムの載せ替えで行う。
/// 切り替えのたびに `AVPlayer` を作り直すと、スライドショーで routing context の生成と破棄が繰り返され、
/// CoreMedia 内部の競合で落ちる（bug: slideshow-video-routing-context-crash）。
/// ループは `AVPlayerLooper` を使わず、1つのアイテムを終端で先頭へ戻す。
/// `AVPlayerLooper` はアイテムを複製して切り替えるため、AVPlayerView の 15 秒スキップで終端を越えると
/// 映像が止まる（bug: preview-skip-forward-frame-freeze）。
@MainActor
public final class VideoPlayback {
    public let player = AVPlayer()
    private var endObserver: NSObjectProtocol?

    public init() {}

    /// 前のアイテムを外し、`asset` のアイテムを載せる。再生の開始・一時停止は呼び出し側が決める
    public func load(asset: AVAsset, loop: Bool) {
        unload()
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)

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

    /// 終端の監視をやめ、再生を止めてアイテムを外す。`AVPlayer` は次の `load` で使い回す
    public func unload() {
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
