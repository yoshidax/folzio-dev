import AppKit
import FolzioCore
import FolzioLocalization

struct RawImportItem: Sendable {
    let data: Result<Data, ImportRejection>
    let name: String?
}

final class ImportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isCancelled: Bool { lock.withLock { value } }
    func cancel() { lock.withLock { value = true } }
}

// AppKit invokes this callback on its supplied queue. Clone before the coordinated read returns.
func makeImportPromiseReader(
    staging: ImportStaging, cancellation: ImportCancellation,
    report: @escaping @MainActor @Sendable (Result<ImportSnapshot, ImportRejection>) -> Void
) -> @Sendable (URL, Error?) -> Void {
    { @Sendable url, error in
        if cancellation.isCancelled {
            try? staging.remove()
            return
        }
        let result: Result<ImportSnapshot, ImportRejection> = error == nil
            ? ImportInspector.snapshot(url, receptionFolder: staging.receptionFolder, inspectionFolder: staging.inspectionFolder)
            : .failure(.sourceFailed)
        if cancellation.isCancelled { try? staging.remove() }
        Task { @MainActor in report(result) }
    }
}

@MainActor
struct ImportPromise {
    let declaredTypes: [String]
    let names: () -> [String]
    let request: (ImportStaging, OperationQueue, @escaping @MainActor @Sendable (Result<ImportSnapshot, ImportRejection>) -> Void) -> Void

    static func live(_ receiver: NSFilePromiseReceiver, cancellation: ImportCancellation) -> ImportPromise {
        ImportPromise(declaredTypes: receiver.fileTypes, names: { receiver.fileNames }, request: { stage, queue, report in
            receiver.receivePromisedFiles(atDestination: stage.receptionFolder, options: [:], operationQueue: queue,
                reader: makeImportPromiseReader(staging: stage, cancellation: cancellation, report: report))
        })
    }
}

struct ImportSaveRequest: Sendable {
    let files: [URL]
    let failures: [(url: URL, reason: OperationFailureReason)]
    let destination: URL
    let sameVolume: Bool
}

enum ImportSaveOutcome: Sendable, Equatable { case finished, failed, cancelled }

@MainActor
struct ImportSaveControl {
    let isActive: () -> Bool
    let willConfirm: () -> Void
    let didConfirm: () -> Void
}

@MainActor
final class ImportSession {
    let id = UUID()
    let destination: URL
    let startedAt: TimeInterval
    let date = Date()
    let prefix: String
    let cancellation: ImportCancellation
    let save: ImportSessionManager.Save
    var state: ImportReceptionState
    var staging: ImportStaging?
    let promises: [ImportPromise]
    let budget: ImportBudget
    var snapshots: [ImportSnapshot] = []
    var failures: [(url: URL, reason: OperationFailureReason)] = []
    var counts: [Int: Int] = [:]
    var unlistedFailures: Set<Int> = []
    var owners: [String: Int] = [:]
    var bytes: UInt64 = 0
    var imageCount = 0
    var requesting = false
    var task: Task<Void, Never>?
    var preparation: Task<Result<ImportSaveRequest, OperationFailureReason>, Never>?
    var creation: Task<ImportStaging, Error>?

    init(destination: URL, startedAt: TimeInterval, promises: [ImportPromise], kinds: [ExpectedKind],
         cancellation: ImportCancellation, save: @escaping ImportSessionManager.Save) {
        self.destination = destination; self.startedAt = startedAt; self.promises = promises
        self.budget = ImportBudget(kinds: kinds); self.cancellation = cancellation; self.save = save
        self.prefix = l10n.importedImageNamePrefix
        self.state = ImportReceptionState(hasPromises: !promises.isEmpty)
    }

    var completedReceivers: Set<Int> {
        Set(promises.indices.filter { index in
            let expected = promises[index].names().count
            return expected > 0 ? counts[index, default: 0] >= expected : unlistedFailures.contains(index)
        })
    }
    var total: Int { max(imageCount, max(1, promises.reduce(0) { $0 + max(1, $1.names().count) })) }
    var canCancel: Bool { [.receiving, .checking].contains(state.phase) }
}

struct ImportProgressRow: Identifiable {
    let id: UUID
    let destination: String
    let total: Int
    let completed: Int
    let bytes: UInt64
    let checking: Bool
}

private struct ImportPreparation: Sendable {
    let staging: ImportStaging
    let snapshots: [ImportSnapshot]
    let images: [RawImportItem]
    let failures: [(url: URL, reason: OperationFailureReason)]
    let destination: URL
    let prefix: String
    let date: Date
    let cancellation: ImportCancellation

    func perform() -> Result<ImportSaveRequest, OperationFailureReason> {
        guard !cancellation.isCancelled else { return .failure(.importRejected(.sourceFailed)) }
        if let reason = FileOperationCoordinator.receivedDestinationFailure(destination) { return .failure(reason) }
        var accepted: [(URL, String)] = []
        var rejected = failures
        let fallback = ImportedFileName.datedName(prefix: prefix, date: date, extension: "png")
        for snapshot in snapshots {
            guard !cancellation.isCancelled else { return .failure(.importRejected(.sourceFailed)) }
            switch ImportInspector.inspect(snapshot, prefix: prefix, date: date) {
            case let .success(file): accepted.append((file.url, file.name))
            case let .failure(error): rejected.append((URL(fileURLWithPath: ImportedFileName.isAcceptable(snapshot.originalName) ? snapshot.originalName : fallback), .importRejected(error)))
            }
        }
        for image in images {
            guard !cancellation.isCancelled else { return .failure(.importRejected(.sourceFailed)) }
            let url = staging.inspectionFolder.appendingPathComponent(UUID().uuidString + ".png")
            let result = image.data.flatMap { ImageDataWriter.write($0, to: url) }
            switch result {
            case let .success(file): accepted.append((file, image.name ?? fallback))
            case let .failure(error): rejected.append((URL(fileURLWithPath: image.name ?? fallback), .importRejected(error)))
            }
        }
        guard !cancellation.isCancelled else { return .failure(.importRejected(.sourceFailed)) }
        do {
            let folder = staging.inspectionFolder.appendingPathComponent("ready", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            let names = ImportedFileName.uniqueNames(accepted.map(\.1))
            var files: [URL] = []
            for (index, entry) in accepted.enumerated() {
                guard !cancellation.isCancelled else { return .failure(.importRejected(.sourceFailed)) }
                let target = folder.appendingPathComponent(names[index])
                try FileManager.default.moveItem(at: entry.0, to: target)
                files.append(target)
            }
            return .success(ImportSaveRequest(files: files, failures: rejected, destination: destination,
                sameVolume: staging.sameVolume(as: destination)))
        } catch { return .failure(.systemFailure(systemReason: error.localizedDescription)) }
    }
}

@MainActor
final class ImportSessionManager: NSObject {
    typealias Save = @MainActor (ImportSaveRequest, ImportSaveControl) async -> ImportSaveOutcome
    static let shared = ImportSessionManager()
    let pool: ImportStagingPool
    private(set) var sessions: [ImportSession] = []
    var now: () -> TimeInterval
    var onChange: (() -> Void)?
    private let automaticTicks: Bool
    private let showsPanel: Bool
    private var timer: Task<Void, Never>?
    private var panel: ReceivingPanelController?
    private var cleanups: [UUID: Task<Void, Never>] = [:]
    private var shuttingDown = false
    private let queue: OperationQueue = {
        let result = OperationQueue()
        result.name = "Folzio.Import.Reader"
        result.maxConcurrentOperationCount = 2
        return result
    }()

    init(pool: ImportStagingPool = ImportStagingPool(), automaticTicks: Bool = true, showsPanel: Bool = true,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.pool = pool; self.automaticTicks = automaticTicks; self.showsPanel = showsPanel; self.now = now
    }

    func start() {
        guard timer == nil, !shuttingDown else { return }
        timer = Task { [weak self] in
            await Task.detached { ImportCleanupStore.shared.sweep() }.value
            guard let self, !self.shuttingDown else { return }
            await self.pool.prepare()
            guard self.automaticTicks else { return }
            while !Task.isCancelled, !self.shuttingDown {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled { await self.tick() }
            }
        }
    }

    var rows: [ImportProgressRow] {
        sessions.filter { $0.canCancel && now() - $0.startedAt >= 2 }.map {
            ImportProgressRow(id: $0.id, destination: $0.destination.lastPathComponent, total: $0.total,
                completed: $0.promises.isEmpty ? $0.imageCount : $0.state.receivedCount, bytes: $0.bytes, checking: $0.state.phase == .checking)
        }
    }

    func beginPromises(_ promises: [ImportPromise], destination: URL,
                       cancellation: ImportCancellation = ImportCancellation(), save: @escaping Save) -> ImportSession? {
        guard !shuttingDown, !promises.isEmpty,
              let payload = ImportPayloadPolicy.select(promiseDeclaredTypes: promises.map(\.declaredTypes)),
              case let .promises(kinds) = payload, let stage = pool.take() else { return nil }
        let session = ImportSession(destination: destination, startedAt: now(), promises: promises, kinds: kinds,
            cancellation: cancellation, save: save)
        session.staging = stage
        sessions.append(session)
        session.requesting = true
        for (index, promise) in promises.enumerated() {
            promise.request(stage, queue) { [weak self, weak session] result in
                guard let self, let session else {
                    Task.detached { try? stage.remove() }
                    return
                }
                self.receive(result, from: index, session: session)
            }
        }
        session.requesting = false
        checkCompletion(session)
        publish()
        return session
    }

    func beginImages(_ images: [RawImportItem], destination: URL, save: @escaping Save) -> ImportSession? {
        guard !shuttingDown, !images.isEmpty else { return nil }
        let session = ImportSession(destination: destination, startedAt: now(), promises: [], kinds: [],
            cancellation: ImportCancellation(), save: save)
        session.imageCount = images.count
        session.bytes = images.reduce(0) { total, image in
            total + UInt64((try? image.data.get().count) ?? 0)
        }
        sessions.append(session)
        session.creation = Task { [pool] in try await pool.fresh() }
        session.task = Task { [self, session] in
            do {
                let stage = try await session.creation!.value
                session.staging = stage
                guard session.state.phase == .checking else { cleanup(stage); return }
                await prepare(session, images: images)
            } catch { fail(session, reason: .importRejected(.sourceFailed)) }
        }
        publish()
        return session
    }

    private func receive(_ result: Result<ImportSnapshot, ImportRejection>, from index: Int, session: ImportSession) {
        if case let .success(snapshot) = result, let owner = session.owners[snapshot.canonicalSourcePath], owner != index,
           ![.finished, .failed, .cancelled].contains(session.state.phase) {
            fail(session, reason: .importRejected(.sourceFailed)); return
        }
        guard session.state.phase == .receiving else {
            if [.finished, .failed, .cancelled].contains(session.state.phase), let stage = session.staging { cleanup(stage) }
            return
        }
        switch result {
        case let .success(snapshot):
            if let owner = session.owners[snapshot.canonicalSourcePath] {
                if owner != index { fail(session, reason: .importRejected(.sourceFailed)) }
                return
            }
            session.owners[snapshot.canonicalSourcePath] = index
            session.snapshots.append(snapshot)
            session.state.apply(.received(id: snapshot.canonicalSourcePath))
        case let .failure(error):
            if session.promises[index].names().isEmpty { session.unlistedFailures.insert(index) }
            let name = session.promises[index].names().first ?? session.prefix
            session.failures.append((URL(fileURLWithPath: ImportedFileName.isAcceptable(name) ? name : session.prefix), .importRejected(error)))
            session.state.apply(.received(id: UUID().uuidString))
        }
        session.counts[index, default: 0] += 1
        checkCompletion(session)
        publish()
    }

    private func checkCompletion(_ session: ImportSession) {
        guard !session.requesting, session.state.phase == .receiving,
              session.completedReceivers.count == session.promises.count else { return }
        session.state.apply(.receptionCompleted)
        session.task = Task { [self, session] in await prepare(session, images: []) }
    }

    private func prepare(_ session: ImportSession, images: [RawImportItem]) async {
        guard let stage = session.staging, session.state.phase == .checking else { return }
        let input = ImportPreparation(staging: stage, snapshots: session.snapshots, images: images,
            failures: session.failures, destination: session.destination, prefix: session.prefix, date: session.date,
            cancellation: session.cancellation)
        let work = Task.detached { input.perform() }
        session.preparation = work
        let result = await work.value
        guard session.state.phase == .checking else { cleanup(stage); return }
        switch result {
        case let .failure(reason): fail(session, reason: reason)
        case let .success(request):
            let outcome = await session.save(request, control(for: session))
            switch outcome {
            case .finished: session.state.apply(.saved)
            case .failed: session.state.apply(.failed)
            case .cancelled: session.state.apply(.cancelled)
            }
            finish(session)
        }
    }

    private func control(for session: ImportSession, reportingFailure: Bool = false) -> ImportSaveControl {
        ImportSaveControl(isActive: { [weak self, weak session] in
            guard let self, let session, !self.shuttingDown else { return false }
            return reportingFailure ? session.state.phase == .failed : ![.failed, .cancelled, .finished].contains(session.state.phase)
        }, willConfirm: { [weak self, weak session] in
            session?.state.apply(.checked); self?.publish()
        }, didConfirm: { [weak self, weak session] in
            session?.state.apply(.confirmed); self?.publish()
        })
    }

    private func fail(_ session: ImportSession, reason: OperationFailureReason) {
        guard session.state.apply(.failed) else { return }
        session.cancellation.cancel()
        if let stage = session.staging { cleanup(stage) }
        publish()
        Task { [self, session] in
            let name = ImportedFileName.datedName(prefix: session.prefix, date: session.date, extension: "")
            _ = await session.save(ImportSaveRequest(files: [], failures: [(URL(fileURLWithPath: name), reason)],
                destination: session.destination, sameVolume: false), control(for: session, reportingFailure: true))
            finish(session)
        }
    }

    func tick() async {
        pool.replenish()
        for session in sessions where session.canCancel && !session.promises.isEmpty {
            let elapsed = now() - session.startedAt
            let expired = session.budget.expiredIndices(elapsed: elapsed, completed: session.completedReceivers)
            if session.state.phase == .receiving, let index = expired.first {
                fail(session, reason: .importRejected(.timedOut(seconds: Int(session.budget.kinds[index].timeout))))
                continue
            }
            if let stage = session.staging {
                let size = await Task.detached { try? stage.currentSize() }.value
                guard session.canCancel else { continue }
                guard let size else { fail(session, reason: .importRejected(.sourceFailed)); continue }
                session.bytes = size
                if session.budget.exceedsCapacity(size) { fail(session, reason: .importRejected(.tooLarge(limit: session.budget.kinds.first?.byteLimit ?? 256_000_000))) }
            }
            checkCompletion(session)
        }
        publish()
    }

    func cancel(_ id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }), session.state.apply(.cancelled) else { return }
        session.cancellation.cancel()
        finish(session)
    }
    func cancelLatest() { if let session = sessions.last(where: \.canCancel) { cancel(session.id) } }

    static func canCancel(hasSessions: Bool, hasSheet: Bool, hasModal: Bool, editingText: Bool) -> Bool {
        hasSessions && !hasSheet && !hasModal && !editingText
    }
    var canCancelFromMenu: Bool {
        Self.canCancel(hasSessions: sessions.contains(where: \.canCancel),
            hasSheet: NSApp?.keyWindow?.attachedSheet != nil || NSApp?.mainWindow?.attachedSheet != nil,
            hasModal: NSApp?.modalWindow != nil, editingText: NSApp?.keyWindow?.firstResponder is NSText)
    }
    @objc func cancelReceiving(_ sender: Any?) { if canCancelFromMenu { cancelLatest() } }

    private func finish(_ session: ImportSession) {
        if let stage = session.staging { cleanup(stage) }
        sessions.removeAll { $0.id == session.id }
        publish()
    }
    private func cleanup(_ stage: ImportStaging) {
        let id = UUID()
        cleanups[id] = Task { [weak self] in
            await ImportStagingPool.remove(stage)
            self?.cleanups.removeValue(forKey: id)
        }
    }
    private func publish() {
        onChange?()
        guard showsPanel else { return }
        let progress = rows
        if !progress.isEmpty, panel == nil { panel = ReceivingPanelController(cancel: { [weak self] in self?.cancel($0) }) }
        panel?.update(progress)
    }
    func shutdown() async {
        shuttingDown = true
        timer?.cancel()
        let current = sessions
        for session in current where session.state.phase != .saving { cancel(session.id) }
        for session in current {
            let created = try? await session.creation?.value
            _ = await session.preparation?.value
            if session.state.phase == .saving { await session.task?.value }
            if let stage = session.staging ?? created { cleanup(stage) }
        }
        await pool.shutdown()
        for task in Array(cleanups.values) { await task.value }
        cleanups.removeAll()
    }
}

extension ImportSessionManager: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { canCancelFromMenu }
}
