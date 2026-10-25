import Foundation
import Observation

/// App が持つ表示の状態（表示形式・サムネイルサイズ・ペインの表示状態）の読み書き（R74）
@MainActor
public protocol HistoryPresentationHost: AnyObject {
    var historyPresentation: HistoryPresentation { get }
    /// 記録せずに表示の状態を戻す。保存の対象（表示形式・サイズ）は保存する（FR-108）
    func applyHistoryPresentation(_ presentation: HistoryPresentation)
}

/// 戻る・進むの実行と、記録・取り除きの契機をまとめる（R72〜R76）
@MainActor
@Observable
public final class HistoryNavigator {
    public private(set) var history = NavigationHistory()
    public weak var presentationHost: (any HistoryPresentationHost)?

    @ObservationIgnored private let model: BrowserModel
    @ObservationIgnored private var pendingDirections: [HistoryDirection] = []
    @ObservationIgnored private var processingTask: Task<Void, Never>?
    @ObservationIgnored private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    /// 直前の `.navigated` で記録する前の履歴。`.notFound` のときに記録を取り消す（R75）
    @ObservationIgnored private var snapshot: NavigationHistory?
    @ObservationIgnored private var snapshotLocation: HistoryLocation?
    @ObservationIgnored private var snapshotVersion: Int?

    /// 検索結果の表示中は、戻る側の履歴がなくても「戻る」を使える（FR-113）
    public var canGoBack: Bool {
        model.isShowingSearchResults || history.canGoBack
    }

    /// 検索結果の表示中は「進む」を無効にする（FR-113）
    public var canGoForward: Bool {
        !model.isShowingSearchResults && history.canGoForward
    }

    /// `model.onLocationEvent` を自身に設定する
    public init(model: BrowserModel) {
        self.model = model
        model.onLocationEvent = { [weak self] event in
            self?.handleLocationEvent(event)
        }
    }

    public func goBack() {
        enqueue(.back)
    }

    public func goForward() {
        enqueue(.forward)
    }

    /// 要求のキューが空になるまで待つ（テスト用）
    public func waitUntilIdle() async {
        guard processingTask != nil || !pendingDirections.isEmpty else { return }
        await withCheckedContinuation { continuation in
            idleWaiters.append(continuation)
        }
    }

    /// 表示の変更を1件の履歴として記録する（FR-107 の（3））
    public func recordViewChange(_ kind: HistoryRecordKind) {
        guard !model.isShowingSearchResults,
              let location = model.historyLocation,
              let viewState = currentViewState() else { return }
        clearSnapshot()
        history.record(
            location: location,
            viewState: viewState,
            kind: kind,
            leavingFocus: model.selection.focused
        )
    }

    public func didRenameFolder(from oldURL: URL, to newURL: URL) {
        clearSnapshot()
        history.renameFolder(RenamedFolder(from: oldURL, to: newURL))
    }

    public func didRenameItem(from oldURL: URL, to newURL: URL) {
        clearSnapshot()
        history.removeEntries(within: [oldURL], keepingCurrent: false)
    }

    public func didRemoveItems(_ urls: [URL]) {
        clearSnapshot()
        history.removeEntries(within: urls, keepingCurrent: true)
    }

    public func handleFileSystemEvent(_ folders: Set<URL>) async {
        let targets = history.allEntries.enumerated().compactMap { index, entry -> (Int, URL, Bool)? in
            guard folders.contains(where: { entry.location.isWithin($0) }) else { return nil }
            if let archive = entry.location.archive {
                return (index, archive.archive, false)
            }
            return (index, entry.location.folder, true)
        }
        await removeMissingEntries(targets)
    }

    public func revalidateAll() async {
        let targets = history.allEntries.enumerated().map { index, entry -> (Int, URL, Bool) in
            if let archive = entry.location.archive {
                return (index, archive.archive, false)
            }
            return (index, entry.location.folder, true)
        }
        await removeMissingEntries(targets)
    }

    // MARK: - 記録

    private func handleLocationEvent(_ event: LocationEvent) {
        switch event {
        case let .navigated(leavingFocus):
            guard let location = model.historyLocation,
                  let viewState = currentViewState() else { return }
            if history.current?.location == location {
                history.updateCurrentViewState(viewState)
                clearSnapshot()
                return
            }

            snapshot = history
            snapshotLocation = location
            let recorded = history.record(
                location: location,
                viewState: viewState,
                kind: .navigation,
                leavingFocus: leavingFocus
            )
            if recorded {
                snapshotVersion = history.version
            } else {
                clearSnapshot()
            }

        case let .relocated(vanished):
            clearSnapshot()
            if let location = model.historyLocation {
                history.replaceCurrentLocation(location)
            }
            history.removeEntries(within: vanished, keepingCurrent: true)

        case let .notFound(location):
            if let snapshot,
               snapshotLocation == location,
               snapshotVersion == history.version {
                history = snapshot
                history.detachCurrent()
            } else if history.current?.location == location {
                history.removeCurrent()
            }
            clearSnapshot()
        }
    }

    private func currentViewState() -> HistoryViewState? {
        guard let presentationHost else { return nil }
        return HistoryViewState(
            presentation: presentationHost.historyPresentation,
            mediaTypeFilter: model.mediaTypeFilter,
            showsZipFiles: model.showsZipFiles
        )
    }

    private func clearSnapshot() {
        snapshot = nil
        snapshotLocation = nil
        snapshotVersion = nil
    }

    // MARK: - 戻る・進む

    private func enqueue(_ direction: HistoryDirection) {
        pendingDirections.append(direction)
        guard processingTask == nil else { return }
        processingTask = Task { [weak self] in
            await self?.processRequests()
        }
    }

    private func processRequests() async {
        while !pendingDirections.isEmpty {
            let direction = pendingDirections.removeFirst()
            await perform(direction)
        }
        processingTask = nil
        let waiters = idleWaiters
        idleWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func perform(_ direction: HistoryDirection) async {
        if model.isShowingSearchResults {
            guard direction == .back else { return }
            await model.selectFolder(model.listing.folder)
            return
        }

        while true {
            guard let candidate = history.candidate(direction) else { return }
            if let currentLocation = model.historyLocation, candidate.location == currentLocation {
                guard let moved = history.move(direction, leavingFocus: model.selection.focused) else { return }
                applyViewState(moved.viewState)
                return
            }

            let versionBefore = history.version
            let resolution = await model.resolveHistoryLocation(candidate.location)
            guard history.version == versionBefore else { return }

            switch resolution {
            case .superseded:
                return
            case .missing:
                history.dropCandidate(direction)
                continue
            case let .available(resolved):
                guard let moved = history.move(direction, leavingFocus: model.selection.focused) else { return }
                model.showHistoryLocation(resolved, focusing: moved.focusedItem)
                applyViewState(moved.viewState)
                return
            }
        }
    }

    private func applyViewState(_ viewState: HistoryViewState) {
        model.setMediaTypeFilter(viewState.mediaTypeFilter)
        model.setShowsZipFiles(viewState.showsZipFiles)
        presentationHost?.applyHistoryPresentation(viewState.presentation)
    }

    // MARK: - 存在の確認

    private func removeMissingEntries(_ targets: [(Int, URL, Bool)]) async {
        guard !targets.isEmpty else { return }
        let version = history.version

        var checks: [String: Bool] = [:]
        for (_, url, expectsDirectory) in targets {
            checks[url.path] = checks[url.path] ?? expectsDirectory
        }
        let missingPaths = await Task.detached(priority: .userInitiated) {
            Set(checks.compactMap { path, expectsDirectory -> String? in
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                guard exists, isDirectory.boolValue == expectsDirectory else { return path }
                return nil
            })
        }.value

        guard history.version == version, !missingPaths.isEmpty else { return }
        let positions = Set(targets.compactMap { index, url, _ in
            missingPaths.contains(url.path) ? index : nil
        })
        history.removeEntries(at: positions)
    }
}
