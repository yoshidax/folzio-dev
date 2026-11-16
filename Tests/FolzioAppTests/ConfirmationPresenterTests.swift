import AppKit
import FolzioCore
import Testing
@testable import FolzioApp

@Suite("Confirmation presenter", .serialized)
@MainActor
struct ConfirmationPresenterTests {
    private static let source = URL(fileURLWithPath: "/tmp/folzio-confirm/a.jpg")
    private static let destination = URL(fileURLWithPath: "/tmp/folzio-confirm/dest", isDirectory: true)

    /// Runs the operation that `target` governs and returns whether a modal was shown.
    private func runOperation(
        _ target: ConfirmationTarget,
        on presenter: ConfirmationPresenter
    ) async -> Bool {
        switch target {
        case .copy:
            return await presenter.confirm(
                FileOperation(kind: .copy, sources: [Self.source], destination: Self.destination))
        case .move:
            return await presenter.confirm(
                FileOperation(kind: .move, sources: [Self.source], destination: Self.destination), origin: .tree)
        case .rename:
            return await presenter.confirm(
                FileOperation(kind: .rename(newName: "b.jpg"), sources: [Self.source]), origin: .tree)
        case .removeFavorite:
            return await presenter.confirmRemovingFavorite(named: "a", path: Self.destination.path)
        case .trash:
            return await presenter.confirm(FileOperation(kind: .trash, sources: [Self.source]))
        }
    }

    @Test("Turning off one operation skips only that operation's modal (SC-216)",
          arguments: ConfirmationTarget.allCases)
    func skipsOnlyTheTurnedOffOperation(_ turnedOff: ConfirmationTarget) async throws {
        try await withPresenter { settings, presenter, recorder in
            var options = ConfirmationOptions()
            options.setEnabled(false, for: turnedOff)
            settings.confirmation = options
            for target in ConfirmationTarget.allCases {
                recorder.alerts.removeAll()
                let confirmed = await runOperation(target, on: presenter)
                #expect(confirmed, "\(target)")
                #expect(recorder.alerts.count == (target == turnedOff ? 0 : 1), "\(turnedOff) off → \(target)")
            }
        }
    }

    @Test("Trash from the tree confirms with every setting off and has no \"Don't ask again\" (FR-079, US85-AS5)")
    func treeTrashAlwaysConfirms() async throws {
        try await withPresenter { settings, presenter, recorder in
            settings.confirmation = ConfirmationOptions(
                copy: false, move: false, rename: false, removeFavorite: false, trash: false)
            let confirmed = await presenter.confirm(
                FileOperation(kind: .trash, sources: [Self.source]), origin: .tree)
            #expect(confirmed)
            #expect(recorder.alerts.count == 1)
            #expect(recorder.alerts.first?.showsSuppressionButton == false)
        }
    }

    @Test("\"Don't ask again\" turns off only that operation (FR-395, SC-218)", arguments: ConfirmationTarget.allCases)
    func dontAskAgainTurnsOffOnlyThatOperation(_ target: ConfirmationTarget) async throws {
        try await withPresenter(checksSuppression: true) { settings, presenter, recorder in
            settings.confirmation = ConfirmationOptions()
            _ = await runOperation(target, on: presenter)
            #expect(recorder.alerts.first?.showsSuppressionButton == true)
            let options = settings.confirmation
            for other in ConfirmationTarget.allCases {
                #expect(options.isEnabled(other) == (other != target), "\(target) → \(other)")
            }
        }
    }

    @Test("\"Don't ask again\" also applies when the modal is cancelled (EC-262)")
    func dontAskAgainAppliesOnCancel() async throws {
        try await withPresenter(checksSuppression: true, response: .alertSecondButtonReturn) { settings, presenter, _ in
            let confirmed = await runOperation(.move, on: presenter)
            #expect(!confirmed)
            #expect(!settings.confirmation.move)
            #expect(settings.confirmation.copy)
        }
    }

    @Test("Without a window, move and rename still confirm when turned on; copy keeps continuing (EC-263)")
    func noWindowFallback() async throws {
        try await withPresenter { settings, presenter, recorder in
            presenter.fallbackWindow = { nil }
            var modals: [NSAlert] = []
            presenter.runModal = { alert in
                modals.append(alert)
                return .alertSecondButtonReturn
            }
            #expect(await !runOperation(.move, on: presenter))
            #expect(await !runOperation(.rename, on: presenter))
            #expect(await !presenter.confirm(FileOperation(kind: .trash, sources: [Self.source]), origin: .tree))
            #expect(modals.count == 3)
            #expect(await runOperation(.copy, on: presenter))
            #expect(modals.count == 3)
            #expect(recorder.alerts.isEmpty)

            settings.confirmation = ConfirmationOptions(move: false, rename: false)
            #expect(await runOperation(.move, on: presenter))
            #expect(await runOperation(.rename, on: presenter))
            #expect(modals.count == 3)
        }
    }

    private func withPresenter(
        checksSuppression: Bool = false,
        response: NSApplication.ModalResponse = .alertFirstButtonReturn,
        _ body: @MainActor (SettingsStore, ConfirmationPresenter, AlertRecorder) async throws -> Void
    ) async throws {
        _ = NSApplication.shared
        let suite = "Folzio.Confirmation.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        let presenter = ConfirmationPresenter(settings: settings)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        presenter.fallbackWindow = { window }
        presenter.runModal = { _ in
            Issue.record("An app-modal alert must not appear while a window is available")
            return .alertSecondButtonReturn
        }
        let recorder = AlertRecorder()
        presenter.presentSheet = { alert, _ in
            recorder.alerts.append(alert)
            if checksSuppression { alert.suppressionButton?.state = .on }
            return response
        }
        try await body(settings, presenter, recorder)
    }
}

@MainActor
private final class AlertRecorder {
    var alerts: [NSAlert] = []
}
