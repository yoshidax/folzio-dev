import AppKit
import MediaViewerCore

@MainActor
final class FileOperationCoordinator {
    private let model: BrowserModel
    private let service: any FileOperating
    private let confirmation: ConfirmationPresenter
    private let conflictPrompt: ConflictPrompt

    /// 操作が終わったときに、影響したフォルダ（対象の親フォルダと操作先）を渡す。ツリーが FSEvents を待たずに反映する（FR-027、R32）
    var onFoldersChanged: ((Set<URL>) -> Void)?

    init(model: BrowserModel, service: any FileOperating, settings: SettingsStore) {
        self.model = model
        self.service = service
        self.confirmation = ConfirmationPresenter(settings: settings)
        self.conflictPrompt = ConflictPrompt()
    }

    func copy(_ urls: [URL], to destination: URL) async {
        await transfer(urls, to: destination, kind: .copy)
    }

    func move(_ urls: [URL], to destination: URL) async {
        await transfer(urls, to: destination, kind: .move)
    }

    func duplicate(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        let operation = FileOperation(kind: .copy, sources: urls)
        guard await confirmation.confirm(operation, includesFolders: await containsFolder(urls)) else { return }

        var result = FileOperationResult()
        for source in urls {
            let copyOperation = FileOperation(
                kind: .copy,
                sources: [source],
                destination: source.deletingLastPathComponent()
            )
            let partial = await service.execute(copyOperation, resolution: .keepBoth)
            result.merge(partial)
        }
        await presentFailures(result)
        await model.reloadCurrentFolder()
        notifyFoldersChanged(sources: urls, destination: nil)
    }

    func trash(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        let operation = FileOperation(kind: .trash, sources: urls)
        guard await confirmation.confirm(operation, includesFolders: await containsFolder(urls)) else { return }

        let result = await service.execute(operation, resolution: .abort)
        await presentFailures(result)
        // ツリーへ先に知らせ、親の一覧の読み込みを待たずにゴミ箱に入れた行を消す（FR-027）
        notifyFoldersChanged(sources: urls, destination: nil)
        // result.succeeded はゴミ箱の中の URL のため使わず、失敗しなかった元の場所を渡す
        let failedPaths = Set(result.failed.map { $0.url.standardizedFileURL.path })
        let trashedSources = urls.filter { !failedPaths.contains($0.standardizedFileURL.path) }
        // 表示中のフォルダやその祖先を入れたときだけ親へ移る（FR-079）。ファイルリストからのゴミ箱は
        // それらを対象にしないため false になり、従来どおり読み直す。移ったときに読み直すと
        // 消えたフォルダの「フォルダが見つかりません」が一瞬出るため、false のときだけ呼ぶ
        if await !model.leaveTrashedFolders(trashedSources) {
            await model.reloadCurrentFolder()
        }
    }

    func paste(into destination: URL, move: Bool) async {
        let urls = pasteboardFileURLs()
        guard !urls.isEmpty else { return }
        if move {
            await self.move(urls, to: destination)
        } else {
            await self.copy(urls, to: destination)
        }
    }

    func rename(_ file: URL, to newName: String) async {
        let parent = file.deletingLastPathComponent()
        let existingNames = await siblingNames(in: parent).subtracting([file.lastPathComponent])

        let isDirectory = await containsFolder([file])
        switch validateNewName(newName, for: file, existingNames: existingNames, isDirectory: isDirectory) {
        case .invalid(let reason):
            await showError(message: "名前を変更できません", detail: reason)
            return
        case .needsExtensionChangeConfirmation:
            guard await confirmExtensionChange(for: file, to: newName) else { return }
        case .ok:
            break
        }

        let operation = FileOperation(kind: .rename(newName: newName), sources: [file])
        guard await confirmation.confirm(operation, includesFolders: isDirectory) else { return }

        let result = await service.execute(operation, resolution: .abort)
        await presentFailures(result)
        await model.reloadCurrentFolder()
        notifyFoldersChanged(sources: [file], destination: nil)
    }

    private func transfer(_ urls: [URL], to destination: URL, kind: FileOperation.Kind) async {
        guard !urls.isEmpty else { return }
        let operation = FileOperation(kind: kind, sources: urls, destination: destination)
        guard await confirmation.confirm(operation, includesFolders: await containsFolder(urls)) else { return }

        var result = FileOperationResult()
        var sharedResolution: ConflictResolution?

        for source in urls {
            let itemOperation = FileOperation(
                kind: kind,
                sources: [source],
                destination: destination
            )
            let resolution: ConflictResolution
            if let sharedResolution {
                resolution = sharedResolution
            } else {
                let conflicts = service.conflicts(for: itemOperation)
                if conflicts.isEmpty {
                    resolution = .keepBoth
                } else {
                    let choice = await conflictPrompt.resolve(
                        conflictingNames: conflicts.map(\.lastPathComponent),
                        destination: destination
                    )
                    if choice.applyToAll {
                        sharedResolution = choice.resolution
                    }
                    resolution = choice.resolution
                }
            }

            if case .abort = resolution {
                continue
            }
            let partial = await service.execute(itemOperation, resolution: resolution)
            result.merge(partial)
        }

        await presentFailures(result)
        await model.reloadCurrentFolder()
        notifyFoldersChanged(sources: urls, destination: destination)
    }

    /// 対象にフォルダが含まれるか。stat は UI スレッドで行わない
    private func containsFolder(_ urls: [URL]) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            urls.contains { url in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
            }
        }.value
    }

    private func notifyFoldersChanged(sources: [URL], destination: URL?) {
        var folders = Set(sources.map { $0.deletingLastPathComponent().standardizedFileURL })
        if let destination {
            folders.insert(destination.standardizedFileURL)
        }
        onFoldersChanged?(folders)
    }

    private func pasteboardFileURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [NSURL]
        return (objects ?? []).map { $0 as URL }
    }

    private func siblingNames(in folder: URL) async -> Set<String> {
        await Task.detached(priority: .userInitiated) {
            Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        }.value
    }

    private func confirmExtensionChange(for file: URL, to newName: String) async -> Bool {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return true }

        let alert = NSAlert()
        alert.messageText = "拡張子が変わります"
        alert.informativeText = "「\(file.lastPathComponent)」の拡張子を「\((newName as NSString).pathExtension)」に変更します。続けますか？"
        alert.addButton(withTitle: "変更")
        alert.addButton(withTitle: "キャンセル")
        alert.buttons[1].keyEquivalent = "\u{1b}"

        let response = await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: window) { response in
                continuation.resume(returning: response)
            }
        }
        return response == .alertFirstButtonReturn
    }

    private func presentFailures(_ result: FileOperationResult) async {
        guard !result.failed.isEmpty else { return }

        var lines = result.failed.prefix(10).map { failure in
            "\(failure.url.lastPathComponent): \(failure.reason)"
        }
        if result.failed.count > 10 {
            lines.append("ほか \(result.failed.count - 10) 件")
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "操作を完了できませんでした"
        alert.informativeText = """
        成功 \(result.succeeded.count) 件 / 失敗 \(result.failed.count) 件

        \(lines.joined(separator: "\n"))
        """
        alert.addButton(withTitle: "OK")
        _ = await runSheet(alert)
    }

    private func showError(message: String, detail: String) async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        _ = await runSheet(alert)
    }

    private func runSheet(_ alert: NSAlert) async -> NSApplication.ModalResponse? {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: window) { response in
                continuation.resume(returning: response)
            }
        }
    }
}

private extension FileOperationResult {
    mutating func merge(_ other: FileOperationResult) {
        succeeded.append(contentsOf: other.succeeded)
        failed.append(contentsOf: other.failed)
    }
}
