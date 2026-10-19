import AppKit
import MediaViewerCore

@MainActor
final class ConfirmationPresenter {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func confirm(_ operation: FileOperation) async -> Bool {
        guard settings.confirmation.confirmBeforeFileOperations else {
            return true
        }
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = messageText(for: operation.kind)
        alert.informativeText = informativeText(for: operation)
        alert.addButton(withTitle: "実行")
        alert.addButton(withTitle: "キャンセル")
        alert.buttons[1].keyEquivalent = "\u{1b}"
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "今後この確認を表示しない"

        let response = await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: window) { response in
                continuation.resume(returning: response)
            }
        }

        if alert.suppressionButton?.state == .on {
            settings.confirmation = ConfirmationOptions(confirmBeforeFileOperations: false)
        }

        return response == .alertFirstButtonReturn
    }

    private func messageText(for kind: FileOperation.Kind) -> String {
        switch kind {
        case .copy:
            return "コピーしますか？"
        case .move:
            return "移動しますか？"
        case .rename:
            return "名前を変更しますか？"
        case .trash:
            return "ゴミ箱に入れますか？"
        }
    }

    private func informativeText(for operation: FileOperation) -> String {
        let sources = operation.sources
        var lines = ["対象: \(sources.count) 件"]
        lines.append(contentsOf: sources.prefix(5).map { "・\($0.lastPathComponent)" })
        if sources.count > 5 {
            lines.append("ほか \(sources.count - 5) 件")
        }
        switch operation.kind {
        case .copy, .move:
            if let destination = operation.destination {
                lines.append("操作先: \(destination.path)")
            }
        case .rename, .trash:
            break
        }
        return lines.joined(separator: "\n")
    }
}
