import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SettingsStore")
struct SettingsStoreTests {
    @Test("未設定なら既定値になる")
    func usesDefaults() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            let view = store.viewSettings
            #expect(view.displayMode == .list)
            #expect(view.thumbnailSize == 128)
            #expect(view.sortOrder == SortOrder(column: .name, ascending: true))
            #expect(view.lastFolder == nil)
            #expect(store.playback.autoplay)
            #expect(store.playback.loop)
            #expect(store.confirmation.confirmBeforeFileOperations)
        }
    }

    @Test("保存した値が往復する")
    func roundTripsValues() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            let folder = URL(fileURLWithPath: "/tmp/example", isDirectory: true)

            store.viewSettings = ViewSettings(
                displayMode: .thumbnails,
                thumbnailSize: 256,
                sortOrder: SortOrder(column: .creationDate, ascending: false),
                lastFolder: folder
            )
            store.playback = PlaybackOptions(autoplay: false, loop: false)
            store.confirmation = ConfirmationOptions(confirmBeforeFileOperations: false)

            let view = store.viewSettings
            #expect(view.displayMode == .thumbnails)
            #expect(view.thumbnailSize == 256)
            #expect(view.sortOrder == SortOrder(column: .creationDate, ascending: false))
            #expect(view.lastFolder?.path == folder.path)
            #expect(!store.playback.autoplay)
            #expect(!store.playback.loop)
            #expect(!store.confirmation.confirmBeforeFileOperations)
        }
    }

    @Test("サムネイルサイズは 48〜512 に丸める")
    func clampsThumbnailSize() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)

            defaults.set(10.0, forKey: "view.thumbnailSize")
            #expect(store.viewSettings.thumbnailSize == 48)

            defaults.set(900.0, forKey: "view.thumbnailSize")
            #expect(store.viewSettings.thumbnailSize == 512)
        }
    }

    @Test("型が不正な値は既定値に戻る")
    func fallsBackForInvalidValues() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)

            defaults.set("large", forKey: "view.thumbnailSize")
            defaults.set("grid", forKey: "view.displayMode")
            defaults.set("size", forKey: "view.sort.column")
            defaults.set("yes", forKey: "view.sort.ascending")
            defaults.set("no", forKey: "playback.autoplay")

            let view = store.viewSettings
            #expect(view.thumbnailSize == 128)
            #expect(view.displayMode == .list)
            #expect(view.sortOrder.column == .name)
            #expect(view.sortOrder.ascending)
            #expect(store.playback.autoplay)
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
