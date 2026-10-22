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
            #expect(!view.showsToolbar)
            #expect(store.playback.autoplay)
            #expect(store.playback.loop)
            #expect(store.confirmation.confirmBeforeFileOperations)
            #expect(store.favorites.urls.isEmpty)
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
                lastFolder: folder,
                showsToolbar: true
            )
            store.playback = PlaybackOptions(autoplay: false, loop: false)
            store.confirmation = ConfirmationOptions(confirmBeforeFileOperations: false)

            let view = store.viewSettings
            #expect(view.displayMode == .thumbnails)
            #expect(view.thumbnailSize == 256)
            #expect(view.sortOrder == SortOrder(column: .creationDate, ascending: false))
            #expect(view.lastFolder?.path == folder.path)
            #expect(view.showsToolbar)
            #expect(!store.playback.autoplay)
            #expect(!store.playback.loop)
            #expect(!store.confirmation.confirmBeforeFileOperations)

            var hidden = store.viewSettings
            hidden.showsToolbar = false
            store.viewSettings = hidden
            #expect(!store.viewSettings.showsToolbar)
        }
    }

    @Test("ツールバーの表示状態だけを変えても他の表示設定は変わらない")
    func togglingToolbarKeepsOtherViewSettings() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            let folder = URL(fileURLWithPath: "/tmp/example", isDirectory: true)
            store.viewSettings = ViewSettings(
                displayMode: .thumbnails,
                thumbnailSize: 200,
                sortOrder: SortOrder(column: .kind, ascending: false),
                lastFolder: folder
            )

            var updated = store.viewSettings
            updated.showsToolbar = true
            store.viewSettings = updated

            let view = store.viewSettings
            #expect(view.showsToolbar)
            #expect(view.displayMode == .thumbnails)
            #expect(view.thumbnailSize == 200)
            #expect(view.sortOrder == SortOrder(column: .kind, ascending: false))
            #expect(view.lastFolder?.path == folder.path)
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
            defaults.set("yes", forKey: "view.showsToolbar")

            let view = store.viewSettings
            #expect(view.thumbnailSize == 128)
            #expect(view.displayMode == .list)
            #expect(view.sortOrder.column == .name)
            #expect(view.sortOrder.ascending)
            #expect(!view.showsToolbar)
            #expect(store.playback.autoplay)
        }
    }

    // MARK: - favorites

    @Test("お気に入りは未保存なら空")
    func favoritesDefaultToEmpty() {
        withDefaults { defaults in
            #expect(SettingsStore(defaults: defaults).favorites == FavoriteFolders())
        }
    }

    @Test("お気に入りは登録順のまま絶対パスの配列で往復する")
    func favoritesRoundTrip() {
        withDefaults { defaults in
            let b = URL(fileURLWithPath: "/tmp/fav/b", isDirectory: true)
            let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
            SettingsStore(defaults: defaults).favorites = FavoriteFolders(urls: [b, a])

            #expect(SettingsStore(defaults: defaults).favorites.urls == [b, a])
            #expect(
                defaults.array(forKey: "favorites.paths") as? [String] == ["/tmp/fav/b", "/tmp/fav/a"]
            )
        }
    }

    @Test("お気に入りの不正値は捨てる")
    func favoritesDropInvalidValues() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)

            defaults.set("/tmp/fav/a", forKey: "favorites.paths")
            #expect(store.favorites.urls.isEmpty)

            defaults.set(
                ["/tmp/fav/a", 3, "", "relative/path", "/tmp/fav/a"] as [Any],
                forKey: "favorites.paths"
            )
            #expect(store.favorites.urls == [URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)])
        }
    }

    @Test("お気に入りを保存してもほかの設定は変わらない")
    func savingFavoritesKeepsOtherSettings() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            let folder = URL(fileURLWithPath: "/tmp/example", isDirectory: true)
            store.viewSettings = ViewSettings(
                displayMode: .thumbnails,
                thumbnailSize: 200,
                sortOrder: SortOrder(column: .kind, ascending: false),
                lastFolder: folder,
                showsToolbar: true
            )
            store.playback = PlaybackOptions(autoplay: false, loop: false)
            store.confirmation = ConfirmationOptions(confirmBeforeFileOperations: false)

            store.favorites = FavoriteFolders(urls: [URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)])

            let view = store.viewSettings
            #expect(view.displayMode == .thumbnails)
            #expect(view.thumbnailSize == 200)
            #expect(view.sortOrder == SortOrder(column: .kind, ascending: false))
            #expect(view.lastFolder?.path == folder.path)
            #expect(view.showsToolbar)
            #expect(store.playback == PlaybackOptions(autoplay: false, loop: false))
            #expect(!store.confirmation.confirmBeforeFileOperations)
        }
    }

    @Test("並べ替えの「場所」は保存せず、ほかの表示設定は書く。保存値の location は名前として読む")
    func locationSortIsNotPersisted() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            var view = store.viewSettings
            view.sortOrder = SortOrder(column: .kind, ascending: true)
            store.viewSettings = view

            view.sortOrder = SortOrder(column: .location, ascending: false)
            view.displayMode = .thumbnails
            store.viewSettings = view

            #expect(defaults.string(forKey: "view.sort.column") == "kind")
            #expect(defaults.object(forKey: "view.sort.ascending") as? Bool == true)
            #expect(store.viewSettings.displayMode == .thumbnails)
            #expect(store.viewSettings.sortOrder == SortOrder(column: .kind, ascending: true))

            defaults.set("location", forKey: "view.sort.column")
            #expect(store.viewSettings.sortOrder.column == .name)
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
