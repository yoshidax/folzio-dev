import AppKit
import MediaViewerCore
import os

/// スライドショー開始前の通常表示と、終了後に戻す状態。App 側だけで保持する。
struct SlideshowRestoreState {
    let normalPaneLayout: PaneLayout
    let normalFocusedPane: Pane?
    let threePaneWidths: [Double]?
}

@MainActor
protocol SlideshowCoordinatorDelegate: AnyObject {
    var slideshowFiles: [MediaFile] { get }
    var slideshowSelectedURLs: Set<URL> { get }
    var slideshowFocusedURL: URL? { get }
    var slideshowListingIsLoading: Bool { get }
    func slideshowPrepareForStart() -> Bool
    func slideshowSynchronizeSelection(to url: URL) -> Bool
    func slideshowMoveFocus(_ move: FocusMove)
    func slideshowFocusPreview()
    func slideshowRestoreAfterStop(completion: @escaping @MainActor () -> Void)
    func slideshowDiscardRestore()
    func slideshowAcceptsKeyEvent(_ event: NSEvent) -> Bool
    func slideshowHasPendingKeyEvent() -> Bool
    func slideshowAvailabilityDidChange()
}

/// 設定した間隔の期限、矢印・Esc の入力、保留中の自動送りを調停する App 側の実行主体。
/// playlist は持たず、送るたびに Core の `SlideshowSequence` と最新の一覧から対象を決める。
@MainActor
final class SlideshowCoordinator {
    weak var delegate: SlideshowCoordinatorDelegate?

    private(set) var isActive = false
    private(set) var isRestoring = false

    private let settings: SettingsStore
    private var session = SlideshowSession()
    private var deadlineTask: Task<Void, Never>?
    private let clock = ContinuousClock()
    private let signposter = OSSignposter(
        subsystem: "local.my-img-viewer.MediaViewer",
        category: "Performance"
    )
    private var startInterval: OSSignpostIntervalState?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var canStart: Bool {
        !isActive && !isRestoring && delegate != nil
    }

    func start() {
        guard canStart, let delegate else { return }
        guard let target = SlideshowSequence.startTarget(
            in: delegate.slideshowFiles,
            selected: delegate.slideshowSelectedURLs,
            focused: delegate.slideshowFocusedURL
        ) else {
            return
        }
        guard delegate.slideshowPrepareForStart() else { return }

        isActive = true
        startInterval = signposter.beginInterval("SlideshowStart")
        _ = delegate.slideshowSynchronizeSelection(to: target)
        delegate.slideshowFocusPreview()

        let started = session.start(now: clock.now, interval: settings.slideshow.interval)
        assert(started, "idle のときだけ start する")
        guard started else {
            isActive = false
            isRestoring = true
            endStartInterval()
            delegate.slideshowRestoreAfterStop { [weak self] in
                self?.isRestoring = false
                self?.delegate?.slideshowAvailabilityDidChange()
            }
            return
        }

        delegate.slideshowAvailabilityDidChange()
        schedule()
    }

    /// 実行中なら止めて復帰する。復帰が全画面解除を待つ間は `isRestoring` を立てる。
    func stop() {
        guard isActive else { return }
        isActive = false
        isRestoring = true
        cancelDeadline()
        _ = session.stop()
        endStartInterval()
        signposter.emitEvent("SlideshowStop")
        delegate?.slideshowAvailabilityDidChange()

        guard let delegate else {
            isRestoring = false
            return
        }
        delegate.slideshowRestoreAfterStop { [weak self] in
            guard let self else { return }
            self.isRestoring = false
            self.delegate?.slideshowAvailabilityDidChange()
        }
    }

    /// ウインドウを閉じる・終了するときに、復帰表示を待たずに資源だけ捨てる。
    func stopImmediately() {
        guard isActive || isRestoring else { return }
        isActive = false
        isRestoring = false
        cancelDeadline()
        _ = session.stop()
        endStartInterval()
        signposter.emitEvent("SlideshowStop")
        delegate?.slideshowDiscardRestore()
        delegate?.slideshowAvailabilityDidChange()
    }

    /// 閲覧先を置き換える直前（FR-126）。復帰先の確定を待たせず、送りだけを同期で止める。
    func handleWillReplaceLocation() {
        guard isActive else { return }
        stop()
    }

    /// ローカルモニタから渡されたキーを、スライドショーが受理する場合だけ処理する。
    /// Esc は停止、矢印は期限のやり直しと隠れたファイルリストの移動。`<`・`>` などは既存の処理へ返す。
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isActive, !isRestoring,
              let delegate,
              delegate.slideshowAcceptsKeyEvent(event) else {
            return false
        }

        if event.keyCode == 53 {
            stop()
            return true
        }

        guard let move = Self.focusMove(for: event) else { return false }
        guard session.arrow(now: clock.now, interval: settings.slideshow.interval) else { return false }
        signposter.emitEvent("SlideshowArrow")
        delegate.slideshowMoveFocus(move)
        schedule()
        return true
    }

    /// 一覧・選択の変更後に呼ぶ。対象が0件になったときだけ、読み込み中を除いて自動終了する。
    /// 現在の対象が消えただけでは選択を変えず、次の期限で先頭から選び直す。
    func listingDidChange() {
        guard isActive, !isRestoring, let delegate else { return }
        guard !SlideshowSequence.hasMedia(in: delegate.slideshowFiles),
              !delegate.slideshowListingIsLoading else {
            return
        }
        stop()
    }

    private func schedule() {
        cancelDeadline()
        guard isActive, let deadline = session.deadline else { return }

        let generation = session.generation
        let clock = self.clock
        deadlineTask = Task { @MainActor [weak self] in
            // 期限が過去なら即座に戻り、次の run loop で保留とキー入力を調停する。
            try? await clock.sleep(until: deadline, tolerance: .zero)
            guard !Task.isCancelled,
                  let self,
                  self.isActive,
                  !self.isRestoring,
                  self.session.generation == generation else {
                return
            }
            self.handleTimeout(generation: generation)
        }
    }

    private func cancelDeadline() {
        deadlineTask?.cancel()
        deadlineTask = nil
    }

    private func handleTimeout(generation: Int) {
        guard isActive, !isRestoring, session.generation == generation else { return }
        guard session.timeout(now: clock.now) else { return }

        // 期限の到来とキー入力が同じ run loop に並んだとき、受理する Esc・矢印を先に
        // AppKit へ dispatch させる。ここでは保留だけを立て、次の run loop で確定する。
        RunLoop.main.perform(inModes: [.default, .eventTracking, .modalPanel]) { [weak self] in
            MainActor.assumeIsolated {
                self?.commitPendingDue(generation: generation)
            }
        }
    }

    private func commitPendingDue(generation: Int) {
        guard isActive, !isRestoring,
              let delegate,
              session.generation == generation else {
            return
        }
        // 未処理の受理キーがあれば、この自動送りは延期する。キー側が期限やり直し・停止を行う。
        if delegate.slideshowHasPendingKeyEvent() {
            return
        }

        let options = settings.slideshow
        guard session.commit(now: clock.now, interval: options.interval) else { return }
        switch SlideshowSequence.advance(
            in: delegate.slideshowFiles,
            focused: delegate.slideshowFocusedURL,
            repeats: options.repeats
        ) {
        case .target(let target):
            let changed = delegate.slideshowSynchronizeSelection(to: target)
            if changed {
                signposter.emitEvent("SlideshowAdvance")
            }
            schedule()
        case .finish, .empty:
            stop()
        }
    }

    private func endStartInterval() {
        guard let startInterval else { return }
        signposter.endInterval("SlideshowStart", startInterval)
        self.startInterval = nil
    }

    private static func focusMove(for event: NSEvent) -> FocusMove? {
        switch event.specialKey {
        case .leftArrow:
            return .left
        case .rightArrow:
            return .right
        case .upArrow:
            return .up
        case .downArrow:
            return .down
        default:
            return nil
        }
    }
}
