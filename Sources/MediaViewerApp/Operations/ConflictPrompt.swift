import AppKit
import MediaViewerCore

@MainActor
final class ConflictPrompt {
    struct Choice {
        let resolution: ConflictResolution
        let applyToAll: Bool
    }

    init() {}

    func resolve(conflictingNames: [String], destination: URL?) async -> Choice {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return Choice(resolution: .abort, applyToAll: false)
        }

        let alert = NSAlert()
        alert.messageText = "同じ名前の項目があります"
        alert.informativeText = informativeText(for: conflictingNames, destination: destination)
        alert.addButton(withTitle: "置き換える")
        alert.addButton(withTitle: "両方残す")
        alert.addButton(withTitle: "中止")
        alert.buttons[2].keyEquivalent = "\u{1b}"
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "残りすべてに適用"

        let response = await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: window) { response in
                continuation.resume(returning: response)
            }
        }

        let resolution: ConflictResolution
        switch response {
        case .alertFirstButtonReturn:
            resolution = .replace
        case .alertSecondButtonReturn:
            resolution = .keepBoth
        default:
            resolution = .abort
        }
        return Choice(resolution: resolution, applyToAll: alert.suppressionButton?.state == .on)
    }

    private func informativeText(for names: [String], destination: URL?) -> String {
        var lines = ["衝突する項目: \(names.count) 件"]
        lines.append(contentsOf: names.prefix(5).map { "・\($0)" })
        if names.count > 5 {
            lines.append("ほか \(names.count - 5) 件")
        }
        if let destination {
            lines.append("操作先: \(destination.path)")
        }
        return lines.joined(separator: "\n")
    }
}
