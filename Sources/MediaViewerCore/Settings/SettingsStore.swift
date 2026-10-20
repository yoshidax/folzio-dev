import Foundation

public struct SettingsStore {
    private enum Keys {
        static let displayMode = "view.displayMode"
        static let thumbnailSize = "view.thumbnailSize"
        static let sortColumn = "view.sort.column"
        static let sortAscending = "view.sort.ascending"
        static let lastFolderPath = "view.lastFolderPath"
        static let showsToolbar = "view.showsToolbar"
        static let autoplay = "playback.autoplay"
        static let loop = "playback.loop"
        static let confirmBeforeExecuting = "fileOps.confirmBeforeExecuting"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var viewSettings: ViewSettings {
        get {
            let displayMode = (defaults.object(forKey: Keys.displayMode) as? String)
                .flatMap(DisplayMode.init(rawValue:)) ?? .list
            let thumbnailSize = storedDouble(forKey: Keys.thumbnailSize)
                ?? ViewSettings.defaultThumbnailSize
            let column = (defaults.object(forKey: Keys.sortColumn) as? String)
                .flatMap(SortColumn.init(rawValue:)) ?? .name
            let ascending = storedBool(forKey: Keys.sortAscending) ?? true
            let lastFolder = (defaults.object(forKey: Keys.lastFolderPath) as? String)
                .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            let showsToolbar = storedBool(forKey: Keys.showsToolbar) ?? false

            return ViewSettings(
                displayMode: displayMode,
                thumbnailSize: thumbnailSize,
                sortOrder: SortOrder(column: column, ascending: ascending),
                lastFolder: lastFolder,
                showsToolbar: showsToolbar
            )
        }
        nonmutating set {
            defaults.set(newValue.displayMode.rawValue, forKey: Keys.displayMode)
            defaults.set(newValue.thumbnailSize, forKey: Keys.thumbnailSize)
            defaults.set(newValue.sortOrder.column.rawValue, forKey: Keys.sortColumn)
            defaults.set(newValue.sortOrder.ascending, forKey: Keys.sortAscending)
            if let lastFolder = newValue.lastFolder {
                defaults.set(lastFolder.path, forKey: Keys.lastFolderPath)
            } else {
                defaults.removeObject(forKey: Keys.lastFolderPath)
            }
            defaults.set(newValue.showsToolbar, forKey: Keys.showsToolbar)
        }
    }

    public var playback: PlaybackOptions {
        get {
            PlaybackOptions(
                autoplay: storedBool(forKey: Keys.autoplay) ?? true,
                loop: storedBool(forKey: Keys.loop) ?? true
            )
        }
        nonmutating set {
            defaults.set(newValue.autoplay, forKey: Keys.autoplay)
            defaults.set(newValue.loop, forKey: Keys.loop)
        }
    }

    public var confirmation: ConfirmationOptions {
        get {
            ConfirmationOptions(
                confirmBeforeFileOperations: storedBool(forKey: Keys.confirmBeforeExecuting) ?? true
            )
        }
        nonmutating set {
            defaults.set(
                newValue.confirmBeforeFileOperations,
                forKey: Keys.confirmBeforeExecuting
            )
        }
    }

    private func storedBool(forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    private func storedDouble(forKey key: String) -> Double? {
        guard let value = defaults.object(forKey: key) as? Double, value.isFinite else {
            return nil
        }
        return value
    }
}
