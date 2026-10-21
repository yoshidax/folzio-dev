import AppKit
import MediaViewerCore

@MainActor
final class ConfirmationPresenter {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// `includesFolders` が true なら、フォルダは中身ごと操作する旨を添える（R32）
    func confirm(_ operation: FileOperation, includesFolders: Bool = false) async -> Bool {
        guard settings.confirmation.confirmBeforeFileOperations else {
            return true
        }
        return await present(
            messageText: messageText(for: operation.kind),
            informativeText: informativeText(for: operation, includesFolders: includesFolders),
            confirmTitle: "実行"
        )
    }

    func confirmRemovingFavorite(named name: String) async -> Bool {
        guard settings.confirmation.confirmBeforeFileOperations else {
            return true
        }
        return await present(
            messageText: "お気に入りから削除しますか？",
            informativeText: "対象: \(name)\n実際のフォルダは変更されません",
            confirmTitle: "削除"
        )
    }

    private func present(
        messageText: String,
        informativeText: String,
        confirmTitle: String
    ) async -> Bool {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.addButton(withTitle: confirmTitle)
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

    private func informativeText(for operation: FileOperation, includesFolders: Bool) -> String {
        let sources = operation.sources
        var lines = ["対象: \(sources.count) 件"]
        lines.append(contentsOf: sources.prefix(5).map { "・\($0.lastPathComponent)" })
        if sources.count > 5 {
            lines.append("ほか \(sources.count - 5) 件")
        }
        if includesFolders {
            switch operation.kind {
            case .trash:
                lines.append("フォルダは中身ごとゴミ箱に入ります")
            case .copy, .move, .rename:
                lines.append("フォルダは中身ごと操作します")
            }
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
