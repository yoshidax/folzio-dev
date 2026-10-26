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

        let started = session.start(now: now, interval: .seconds(3))
        #expect(started)
        #expect(session.phase == .running)
        #expect(session.deadline == now.advanced(by: .seconds(3)))
        #expect(session.generation == 1)

        let deadline = session.deadline
        let restarted = session.start(now: now.advanced(by: .seconds(1)), interval: .seconds(3))
        #expect(!restarted)
        #expect(session.deadline == deadline)
        #expect(session.generation == 1)
    }

    @Test("期限前の timeout は false、期限後は保留し、commit で次の期限へ進む")
    func timeoutThenCommit() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now, interval: .seconds(3))

        let early = session.timeout(now: now.advanced(by: .seconds(2.999)))
        #expect(!early)
        let earlyCommit = session.commit(now: now.advanced(by: .seconds(2.999)), interval: .seconds(3))
        #expect(!earlyCommit)

        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)
        #expect(session.pendingDue?.generation == session.generation)
        #expect(session.phase == .running)

        let commitTime = now.advanced(by: .seconds(3.2))
        let committed = session.commit(now: commitTime, interval: .seconds(3))
        #expect(committed)
        #expect(session.pendingDue == nil)
        #expect(session.phase == .running)
        #expect(session.deadline == commitTime.advanced(by: .seconds(3)))

        let secondCommit = session.commit(now: commitTime.advanced(by: .seconds(1)), interval: .seconds(3))
        #expect(!secondCommit)
    }

    @Test("timeout の後に矢印が来たら、保留を取り消して矢印の期限を優先する")
    func arrowCancelsPendingDue() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now, interval: .seconds(3))

        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)
        let arrowTime = now.advanced(by: .seconds(3.1))
        let arrowed = session.arrow(now: arrowTime, interval: .seconds(3))
        #expect(arrowed)

        #expect(session.pendingDue == nil)
        #expect(session.phase == .waitingAfterArrow)
        #expect(session.deadline == arrowTime.advanced(by: .seconds(3)))
        let committed = session.commit(now: arrowTime.advanced(by: .seconds(0.1)), interval: .seconds(3))
        #expect(!committed)
    }

    @Test("矢印の後に期限が来たら、commit で次の送りを実行できる")
    func dueAfterArrowCommits() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now, interval: .seconds(3))

        let arrowTime = now.advanced(by: .seconds(1))
        let arrowed = session.arrow(now: arrowTime, interval: .seconds(3))
        #expect(arrowed)
        let early = session.timeout(now: arrowTime.advanced(by: .seconds(2.999)))
        #expect(!early)

        let dueTime = arrowTime.advanced(by: .seconds(3))
        let due = session.timeout(now: dueTime)
        #expect(due)
        #expect(session.hasPendingDue(for: session.generation))
        let committed = session.commit(now: dueTime.advanced(by: .seconds(0.01)), interval: .seconds(3))
        #expect(committed)
        #expect(session.phase == .running)
    }

    @Test("停止は待機と保留を無効化し、再開始で世代を進める")
    func stopInvalidates() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now, interval: .seconds(3))
        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)

        let stopped = session.stop()
        #expect(stopped)
        #expect(session.phase == .idle)
        #expect(session.deadline == nil)
        #expect(session.pendingDue == nil)
        let committed = session.commit(now: now.advanced(by: .seconds(3.1)), interval: .seconds(3))
        #expect(!committed)
        let stoppedAgain = session.stop()
        #expect(!stoppedAgain)

        let generation = session.generation
        let restarted = session.start(now: now.advanced(by: .seconds(4)), interval: .seconds(3))
        #expect(restarted)
        #expect(session.generation == generation + 1)
    }

    @Test("idle の矢印・timeout・commit は何もしない")
    func idleIgnoresInputs() {
        var session = SlideshowSession()
        let now = t0

        let arrowed = session.arrow(now: now, interval: .seconds(3))
        #expect(!arrowed)
        let due = session.timeout(now: now.advanced(by: .seconds(10)))
        #expect(!due)
        let committed = session.commit(now: now.advanced(by: .seconds(10)), interval: .seconds(3))
        #expect(!committed)
        #expect(session.phase == .idle)
    }

    @Test("remaining は期限までを返し、超過後は zero、idle は nil")
    func remaining() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now, interval: .seconds(2.5))

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
        session.start(now: now, interval: .seconds(3))
        let due = session.timeout(now: now.advanced(by: .seconds(3)))
        #expect(due)
        let oldGeneration = session.generation

        session.arrow(now: now.advanced(by: .seconds(3.1)), interval: .seconds(3))
        #expect(session.generation != oldGeneration)
        #expect(!session.hasPendingDue(for: oldGeneration))
    }

    @Test("設定した間隔の期限でだけ1回送り、遅延後は確定時刻から次を数える", arguments: [1, 3, 10])
    func configurableIntervals(seconds: Int) {
        var session = SlideshowSession()
        let now = t0
        let interval = Duration.seconds(seconds)
        let started = session.start(now: now, interval: interval)
        #expect(started)
        let deadline = now.advanced(by: interval)
        let early = session.timeout(now: deadline.advanced(by: .milliseconds(-1)))
        #expect(!early)
        let earlyCommit = session.commit(now: deadline.advanced(by: .milliseconds(-1)), interval: interval)
        #expect(!earlyCommit)
        #expect(session.deadline == deadline)
        let due = session.timeout(now: deadline)
        #expect(due)
        let committed = session.commit(now: deadline, interval: interval)
        #expect(committed)
        let secondCommit = session.commit(now: deadline, interval: interval)
        #expect(!secondCommit)
        #expect(session.deadline == deadline.advanced(by: interval))

        let late = deadline.advanced(by: interval * 10)
        let lateDue = session.timeout(now: late)
        #expect(lateDue)
        let lateCommit = session.commit(now: late, interval: interval)
        #expect(lateCommit)
        let secondLateCommit = session.commit(now: late, interval: interval)
        #expect(!secondLateCommit)
        #expect(session.deadline == late.advanced(by: interval))
    }

    @Test("間隔を変更しても予定済みの期限は変えず、次の確定から新しい間隔を使う")
    func intervalChangesAfterCommit() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now, interval: .seconds(5))
        let deadline = now.advanced(by: .seconds(5))
        let earlyCommit = session.commit(now: now.advanced(by: .seconds(2)), interval: .seconds(2))
        #expect(!earlyCommit)
        #expect(session.deadline == deadline)
        #expect(session.remaining(at: now.advanced(by: .seconds(2))) == .seconds(3))
        let early = session.timeout(now: deadline.advanced(by: .milliseconds(-1)))
        #expect(!early)
        let due = session.timeout(now: deadline)
        #expect(due)
        #expect(session.deadline == deadline)
        let committed = session.commit(now: deadline, interval: .seconds(2))
        #expect(committed)
        #expect(session.deadline == deadline.advanced(by: .seconds(2)))
    }

    @Test("矢印は最新の間隔で待機し、待機中の変更は待機後の周期から使う")
    func intervalChangesWhileWaitingAfterArrow() {
        var session = SlideshowSession()
        let now = t0
        session.start(now: now, interval: .seconds(3))
        let arrowTime = now.advanced(by: .seconds(1))
        let arrowed = session.arrow(now: arrowTime, interval: .seconds(5))
        #expect(arrowed)
        let deadline = arrowTime.advanced(by: .seconds(5))
        #expect(session.phase == .waitingAfterArrow)
        #expect(session.deadline == deadline)
        let earlyCommit = session.commit(now: arrowTime.advanced(by: .seconds(2)), interval: .seconds(2))
        #expect(!earlyCommit)
        #expect(session.deadline == deadline)
        let early = session.timeout(now: deadline.advanced(by: .milliseconds(-1)))
        #expect(!early)
        let due = session.timeout(now: deadline)
        #expect(due)
        let committed = session.commit(now: deadline, interval: .seconds(2))
        #expect(committed)
        #expect(session.phase == .running)
        #expect(session.deadline == deadline.advanced(by: .seconds(2)))
    }
}
