import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SlideshowSession")
struct SlideshowSessionTests {
    private let clock = ContinuousClock()
    private var t0: ContinuousClock.Instant { clock.now }

    @Test("開始は running と now+3秒の期限を作り、実行中の再開始は変えない")
    func starts() {
        var session = SlideshowSession()
        let now = t0

        #expect(session.phase == .idle)
        #expect(!session.isActive)

        let started = session.start(now: now)
        #expect(started)
        #expect(session.phase == .running)
        #expect(session.deadline == now.advanced(by: .seconds(3)))
        #expect(session.generation == 1)

        let deadline = session.deadline
        let restarted = session.start(now: now.advanced(by: .seconds(1)))
        #expect(!restarted)
        #expect(session.deadline == deadline)
        #expect(session.generation == 1)
    }

    @Test("期限前の timeout は false、期限後は保留し、commit で次の期限へ進む")
    func timeoutThenCommit() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now)

        let early = session.timeout(now: now.advanced(by: .seconds(2.999)))
        #expect(!early)
        let earlyCommit = session.commit(now: now.advanced(by: .seconds(2.999)))
        #expect(!earlyCommit)

        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)
        #expect(session.pendingDue?.generation == session.generation)
        #expect(session.phase == .running)

        let commitTime = now.advanced(by: .seconds(3.2))
        let committed = session.commit(now: commitTime)
        #expect(committed)
        #expect(session.pendingDue == nil)
        #expect(session.phase == .running)
        #expect(session.deadline == commitTime.advanced(by: .seconds(3)))

        let secondCommit = session.commit(now: commitTime.advanced(by: .seconds(1)))
        #expect(!secondCommit)
    }

    @Test("timeout の後に矢印が来たら、保留を取り消して矢印の期限を優先する")
    func arrowCancelsPendingDue() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now)

        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)
        let arrowTime = now.advanced(by: .seconds(3.1))
        let arrowed = session.arrow(now: arrowTime)
        #expect(arrowed)

        #expect(session.pendingDue == nil)
        #expect(session.phase == .waitingAfterArrow)
        #expect(session.deadline == arrowTime.advanced(by: .seconds(3)))
        let committed = session.commit(now: arrowTime.advanced(by: .seconds(0.1)))
        #expect(!committed)
    }

    @Test("矢印の後に期限が来たら、commit で次の送りを実行できる")
    func dueAfterArrowCommits() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now)

        let arrowTime = now.advanced(by: .seconds(1))
        let arrowed = session.arrow(now: arrowTime)
        #expect(arrowed)
        let early = session.timeout(now: arrowTime.advanced(by: .seconds(2.999)))
        #expect(!early)

        let dueTime = arrowTime.advanced(by: .seconds(3))
        let due = session.timeout(now: dueTime)
        #expect(due)
        #expect(session.hasPendingDue(for: session.generation))
        let committed = session.commit(now: dueTime.advanced(by: .seconds(0.01)))
        #expect(committed)
        #expect(session.phase == .running)
    }

    @Test("停止は待機と保留を無効化し、再開始で世代を進める")
    func stopInvalidates() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now)
        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)

        let stopped = session.stop()
        #expect(stopped)
        #expect(session.phase == .idle)
        #expect(session.deadline == nil)
        #expect(session.pendingDue == nil)
        let committed = session.commit(now: now.advanced(by: .seconds(3.1)))
        #expect(!committed)
        let stoppedAgain = session.stop()
        #expect(!stoppedAgain)

        let generation = session.generation
        let restarted = session.start(now: now.advanced(by: .seconds(4)))
        #expect(restarted)
        #expect(session.generation == generation + 1)
    }

    @Test("idle の矢印・timeout・commit は何もしない")
    func idleIgnoresInputs() {
        var session = SlideshowSession()
        let now = t0

        let arrowed = session.arrow(now: now)
        #expect(!arrowed)
        let due = session.timeout(now: now.advanced(by: .seconds(10)))
        #expect(!due)
        let committed = session.commit(now: now.advanced(by: .seconds(10)))
        #expect(!committed)
        #expect(session.phase == .idle)
    }

    @Test("remaining は期限までを返し、超過後は zero、idle は nil")
    func remaining() {
        var session = SlideshowSession(interval: .seconds(2.5))
        let now = t0
        session.start(now: now)

        #expect(session.remaining(at: now) == .seconds(2.5))
        #expect(session.remaining(at: now.advanced(by: .seconds(1))) == .seconds(1.5))
        #expect(session.remaining(at: now.advanced(by: .seconds(3))) == Duration.zero)

        session.stop()
        #expect(session.remaining(at: now) == nil)
    }

    @Test("世代の異なる pending は commit できない")
    func stalePendingCannotCommit() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now)
        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)
        let oldGeneration = session.generation

        session.arrow(now: now.advanced(by: .seconds(3.1)))
        #expect(session.generation != oldGeneration)
        #expect(!session.hasPendingDue(for: oldGeneration))
    }
}
