import Foundation

/// 期限・取消世代・保留中の自動送りを持つ、Core の実行状態。
/// 時刻は呼び出し側から単調時計の Instant として入力し、この型自身は sleep しない。
/// 一度決めた `deadline` は、設定の変更では書き換えない。
/// 新しい間隔は start・arrow・commit で次の期限を作るときだけ使う。
public struct SlideshowSession: Sendable {
    public enum Phase: Sendable, Equatable {
        case idle
        /// 通常の切り替え待ち。
        case running
        /// 最後に受理した矢印から待っている。専用の一時停止状態ではない。
        case waitingAfterArrow
    }

    public struct PendingDue: Sendable, Equatable {
        public let generation: Int
        public let deadline: ContinuousClock.Instant
    }

    public private(set) var phase: Phase = .idle
    public private(set) var deadline: ContinuousClock.Instant?
    public private(set) var generation = 0
    /// timeout が到来した後、App の入力 dispatch 後に commit するまでの保留。最大1つ。
    public private(set) var pendingDue: PendingDue?

    public init() {}

    public var isActive: Bool { phase != .idle }

    /// idle から開始する。実行中の再開始は選択・期限を変えない。
    @discardableResult
    public mutating func start(now: ContinuousClock.Instant, interval: Duration) -> Bool {
        guard phase == .idle else { return false }
        generation &+= 1
        phase = .running
        deadline = now.advanced(by: interval)
        pendingDue = nil
        return true
    }

    /// 実行を止め、待機と pending due を無効化する。実行中でなければ何もしない。
    @discardableResult
    public mutating func stop() -> Bool {
        guard phase != .idle else { return false }
        generation &+= 1
        phase = .idle
        deadline = nil
        pendingDue = nil
        return true
    }

    /// 受理した矢印。移動の成否に関係なく、古い期限と pending due を無効化して now + interval へ移す。
    @discardableResult
    public mutating func arrow(now: ContinuousClock.Instant, interval: Duration) -> Bool {
        guard phase != .idle else { return false }
        generation &+= 1
        pendingDue = nil
        phase = .waitingAfterArrow
        deadline = now.advanced(by: interval)
        return true
    }

    /// 期限が来たことを保留する。選択はまだ変えず、期限も変えない。
    /// 同じ世代の pending が既にあれば true を返す。
    @discardableResult
    public mutating func timeout(now: ContinuousClock.Instant) -> Bool {
        guard phase != .idle, let deadline, now >= deadline else { return false }
        if pendingDue?.generation == generation {
            return true
        }
        pendingDue = PendingDue(generation: generation, deadline: deadline)
        return true
    }

    /// 保留中の自動送りを確定する。現在の世代の pending だけを1回許可し、
    /// 実行状態を running、期限を commit 時刻 + interval にする。
    @discardableResult
    public mutating func commit(now: ContinuousClock.Instant, interval: Duration) -> Bool {
        guard phase != .idle,
              let pending = pendingDue,
              pending.generation == generation else {
            return false
        }
        pendingDue = nil
        phase = .running
        deadline = now.advanced(by: interval)
        return true
    }

    public func hasPendingDue(for generation: Int) -> Bool {
        pendingDue?.generation == generation
    }

    /// 次の期限までの残り。期限を過ぎていれば zero。idle は nil。
    public func remaining(at now: ContinuousClock.Instant) -> Duration? {
        guard let deadline else { return nil }
        let remaining = now.duration(to: deadline)
        return remaining > .zero ? remaining : .zero
    }
}
