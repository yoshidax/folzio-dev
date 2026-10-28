import Foundation
import MediaViewerCore
import MediaViewerLocalization

extension Notification.Name {
    static let displayLanguageDidChange = Notification.Name("MediaViewer.displayLanguageDidChange")
}

/// アプリの設定に基づく表示言語を MainActor で共有する。
@MainActor
final class LocalizationState {
    static let shared = LocalizationState()

    private let store: SettingsStore
    private(set) var localizer: Localizer

    private init(store: SettingsStore = SettingsStore()) {
        self.store = store
        self.localizer = Localizer.forLanguage(store.displayLanguage.rawValue)
    }

    func select(_ language: DisplayLanguageSetting) {
        guard store.displayLanguage != language else { return }
        store.displayLanguage = language
        localizer = Localizer.forLanguage(language.rawValue)
        NotificationCenter.default.post(name: .displayLanguageDidChange, object: nil)
    }
}

@MainActor
var l10n: Localizer { LocalizationState.shared.localizer }
