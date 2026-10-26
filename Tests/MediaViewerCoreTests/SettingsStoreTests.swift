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

    @Test("お気に入りの表示名が往復し、favorites.displayNames に書かれる（R49）")
    func favoriteDisplayNamesRoundTrip() {
        withDefaults { defaults in
            let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
            let b = URL(fileURLWithPath: "/tmp/fav/b", isDirectory: true)
            let favorites = FavoriteFolders(urls: [a, b], customNames: [b.path: "2025（バックアップ）"])
            SettingsStore(defaults: defaults).favorites = favorites

            #expect(SettingsStore(defaults: defaults).favorites == favorites)
            #expect(
                defaults.dictionary(forKey: "favorites.displayNames") as? [String: String]
                    == [b.path: "2025（バックアップ）"]
            )
        }
    }

    @Test("旧形式（favorites.paths だけ）は登録順のまま全件表示名なしで読む（EC-45）")
    func favoritesLegacyFormatHasNoDisplayNames() {
        withDefaults { defaults in
            defaults.set(["/tmp/fav/b", "/tmp/fav/a"], forKey: "favorites.paths")
            let favorites = SettingsStore(defaults: defaults).favorites
            let b = URL(fileURLWithPath: "/tmp/fav/b", isDirectory: true)
            let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
            #expect(favorites.urls == [b, a])
            #expect(favorites.customName(for: a) == nil)
            #expect(favorites.customName(for: b) == nil)
            #expect(favorites.customNamesByPath.isEmpty)
        }
    }

    @Test("favorites.displayNames が辞書でなければ表示名なしで、登録は失われない")
    func favoriteDisplayNamesIgnoredWhenNotDictionary() {
        withDefaults { defaults in
            let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
            defaults.set(["/tmp/fav/a"], forKey: "favorites.paths")

            defaults.set("one", forKey: "favorites.displayNames")
            #expect(SettingsStore(defaults: defaults).favorites.urls == [a])
            #expect(SettingsStore(defaults: defaults).favorites.customNamesByPath.isEmpty)

            defaults.set(["one"], forKey: "favorites.displayNames")
            #expect(SettingsStore(defaults: defaults).favorites.urls == [a])
            #expect(SettingsStore(defaults: defaults).favorites.customNamesByPath.isEmpty)
        }
    }

    @Test("表示名の不正な項目（文字列でない値・未登録のパス・空白だけ）を捨て、改行は除く")
    func favoriteDisplayNamesDropInvalidEntries() {
        withDefaults { defaults in
            defaults.set(["/tmp/fav/a", "/tmp/fav/b", "/tmp/fav/c", "/tmp/fav/d"], forKey: "favorites.paths")
            defaults.set(
                [
                    "/tmp/fav/a": 3,
                    "/tmp/fav/b": "  ",
                    "/tmp/fav/c": "o\nne",
                    "/tmp/fav/x": "unregistered",
                    "/tmp/fav/d": "ok",
                ] as [String: Any],
                forKey: "favorites.displayNames"
            )
            #expect(
                SettingsStore(defaults: defaults).favorites.customNamesByPath
                    == ["/tmp/fav/c": "one", "/tmp/fav/d": "ok"]
            )
        }
    }

    @Test("300 文字の保存値は 255 文字に丸めて読む")
    func favoriteDisplayNamesAreTruncatedOnRead() {
        withDefaults { defaults in
            defaults.set(["/tmp/fav/a"], forKey: "favorites.paths")
            defaults.set(
                ["/tmp/fav/a": String(repeating: "x", count: 300)],
                forKey: "favorites.displayNames"
            )
            #expect(
                SettingsStore(defaults: defaults).favorites.customNamesByPath
                    == ["/tmp/fav/a": String(repeating: "x", count: 255)]
            )
        }
    }

    @Test("表示名が1つもなければ favorites.displayNames のキーを消す")
    func favoriteDisplayNamesKeyRemovedWhenEmpty() {
        withDefaults { defaults in
            let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
            let store = SettingsStore(defaults: defaults)
            store.favorites = FavoriteFolders(urls: [a], customNames: [a.path: "one"])
            #expect(defaults.object(forKey: "favorites.displayNames") != nil)

            store.favorites = FavoriteFolders(urls: [a])
            #expect(defaults.object(forKey: "favorites.displayNames") == nil)
        }
    }

    @Test("削除した登録の表示名は書き込まれない")
    func removedFavoriteDisplayNameIsNotWritten() {
        withDefaults { defaults in
            let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
            let b = URL(fileURLWithPath: "/tmp/fav/b", isDirectory: true)
            var favorites = FavoriteFolders(urls: [a, b], customNames: [a.path: "one", b.path: "two"])
            favorites.remove(b)
            let store = SettingsStore(defaults: defaults)
            store.favorites = favorites

            #expect(
                defaults.dictionary(forKey: "favorites.displayNames") as? [String: String]
                    == [a.path: "one"]
            )
            #expect(defaults.array(forKey: "favorites.paths") as? [String] == ["/tmp/fav/a"])
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

    // MARK: - zip ファイルの表示（view.showsZipFiles）

    @Test("zip ファイルの表示は未設定なら false（初回起動は非表示）")
    func showsZipFilesDefaultsToFalse() {
        withDefaults { defaults in
            #expect(defaults.object(forKey: "view.showsZipFiles") == nil)
            #expect(SettingsStore(defaults: defaults).viewSettings.showsZipFiles == false)
        }
    }

    @Test("zip ファイルの表示が Bool でない値なら false")
    func showsZipFilesFallsBackForInvalidValue() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            defaults.set("yes", forKey: "view.showsZipFiles")
            #expect(store.viewSettings.showsZipFiles == false)
            defaults.set(1.5, forKey: "view.showsZipFiles")
            #expect(store.viewSettings.showsZipFiles == false)
        }
    }

    @Test("zip ファイルの表示は書き戻して読み直せる")
    func showsZipFilesRoundTrips() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)

            var view = store.viewSettings
            view.showsZipFiles = true
            store.viewSettings = view
            #expect(defaults.object(forKey: "view.showsZipFiles") as? Bool == true)
            #expect(SettingsStore(defaults: defaults).viewSettings.showsZipFiles == true)

            view.showsZipFiles = false
            store.viewSettings = view
            #expect(defaults.object(forKey: "view.showsZipFiles") as? Bool == false)
            #expect(SettingsStore(defaults: defaults).viewSettings.showsZipFiles == false)
        }
    }

    @Test("zip ファイルの表示だけを変えても他の表示設定は変わらない")
    func togglingZipVisibilityKeepsOtherViewSettings() {
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

            var updated = store.viewSettings
            updated.showsZipFiles = true
            store.viewSettings = updated

            let view = store.viewSettings
            #expect(view.showsZipFiles)
            #expect(view.displayMode == .thumbnails)
            #expect(view.thumbnailSize == 200)
            #expect(view.sortOrder == SortOrder(column: .kind, ascending: false))
            #expect(view.lastFolder?.path == folder.path)
            #expect(view.showsToolbar)
        }
    }

    @Test("ViewSettings の showsZipFiles は既定が false で、イニシャライザで指定できる")
    func viewSettingsInitializerHandlesZipVisibility() {
        #expect(ViewSettings().showsZipFiles == false)
        #expect(ViewSettings(showsZipFiles: true).showsZipFiles == true)
    }

    // MARK: - スライドショー（slideshow.*）

    @Test("スライドショーは未設定なら既定値（3 秒・繰り返す・効果なし）")
    func slideshowDefaults() {
        withDefaults { defaults in
            let options = SettingsStore(defaults: defaults).slideshow
            #expect(options == SlideshowOptions.defaults)
            #expect(options.intervalSeconds == 3)
            #expect(options.repeats)
            #expect(options.transition == .none)
            #expect(options.interval == .seconds(3))
        }
    }

    @Test("スライドショーの設定が往復し、専用キーに書かれる")
    func slideshowRoundTrips() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            let options = SlideshowOptions(intervalSeconds: 10, repeats: false, transition: .crossfade)
            store.slideshow = options

            #expect(SettingsStore(defaults: defaults).slideshow == options)
            #expect(defaults.object(forKey: "slideshow.intervalSeconds") as? Int == 10)
            #expect(defaults.object(forKey: "slideshow.repeats") as? Bool == false)
            #expect(defaults.string(forKey: "slideshow.transition") == "crossfade")

            for effect in SlideshowTransitionEffect.allCases {
                store.slideshow = SlideshowOptions(intervalSeconds: 1, repeats: true, transition: effect)
                #expect(store.slideshow.transition == effect)
            }
            store.slideshow = SlideshowOptions(intervalSeconds: 3600)
            #expect(store.slideshow.intervalSeconds == 3600)
        }
    }

    @Test("範囲外の間隔で初期化すると 3 秒になる")
    func slideshowOptionsInitializerRejectsOutOfRangeInterval() {
        #expect(SlideshowOptions(intervalSeconds: 0).intervalSeconds == 3)
        #expect(SlideshowOptions(intervalSeconds: 3601).intervalSeconds == 3)
        #expect(SlideshowOptions(intervalSeconds: -5).intervalSeconds == 3)
        #expect(SlideshowOptions.intervalRange == 1...3600)
    }

    @Test("初期化後に間隔を変更しても範囲外の値を持たない")
    func slideshowOptionsMutationValidatesInterval() {
        var options = SlideshowOptions(intervalSeconds: 10, repeats: false, transition: .zoom)
        for value in [0, -1, 3601, Int.min, Int.max] {
            options.intervalSeconds = value
            #expect(options.intervalSeconds == 3)
            #expect(options.interval == .seconds(3))
            #expect(!options.repeats)
            #expect(options.transition == .zoom)
        }
        for value in [1, 10, 3600] {
            options.intervalSeconds = value
            #expect(options.intervalSeconds == value)
            #expect(options.interval == .seconds(value))
        }
    }

    @Test("スライドショーの間隔の不正値は 3 秒に戻り、他の項目は保存値のまま")
    func slideshowInvalidIntervalFallsBackOnly() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            defaults.set(false, forKey: "slideshow.repeats")
            defaults.set("zoom", forKey: "slideshow.transition")

            let invalid: [Any] = [0, 3601, -1, 3.5, "10", true, Double.nan, 1e300]
            for value in invalid {
                defaults.set(value, forKey: "slideshow.intervalSeconds")
                let options = store.slideshow
                #expect(options.intervalSeconds == 3, "value: \(value)")
                #expect(!options.repeats)
                #expect(options.transition == .zoom)
            }

            defaults.set(5.0, forKey: "slideshow.intervalSeconds")
            #expect(store.slideshow.intervalSeconds == 5)
        }
    }

    @Test("スライドショーの繰り返しの不正値は true に戻り、他の項目は保存値のまま")
    func slideshowInvalidRepeatsFallsBackOnly() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            defaults.set(20, forKey: "slideshow.intervalSeconds")
            defaults.set("slide", forKey: "slideshow.transition")
            for value in ["no", "yes", 1] as [Any] {
                defaults.set(value, forKey: "slideshow.repeats")
                let options = store.slideshow
                #expect(options.repeats)
                #expect(options.intervalSeconds == 20)
                #expect(options.transition == .slide)
            }
        }
    }

    @Test("スライドショーの効果の不正値は none に戻り、他の項目は保存値のまま")
    func slideshowInvalidTransitionFallsBackOnly() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            defaults.set(20, forKey: "slideshow.intervalSeconds")
            defaults.set(false, forKey: "slideshow.repeats")

            for value in ["fade", "", "Crossfade", 3] as [Any] {
                defaults.set(value, forKey: "slideshow.transition")
                let options = store.slideshow
                #expect(options.transition == .none, "value: \(value)")
                #expect(options.intervalSeconds == 20)
                #expect(!options.repeats)
            }
        }
    }

    @Test("スライドショーを保存しても既存のキーは変わらない")
    func savingSlideshowKeepsOtherSettings() {
        withDefaults { defaults in
            let store = SettingsStore(defaults: defaults)
            store.viewSettings = ViewSettings(displayMode: .thumbnails, thumbnailSize: 200, showsToolbar: true)
            store.playback = PlaybackOptions(autoplay: false, loop: false)
            store.confirmation = ConfirmationOptions(confirmBeforeFileOperations: false)
            let a = URL(fileURLWithPath: "/tmp/fav/a", isDirectory: true)
            store.favorites = FavoriteFolders(urls: [a], customNames: [a.path: "one"])

            store.slideshow = SlideshowOptions(intervalSeconds: 7, repeats: false, transition: .slide)

            #expect(store.viewSettings.displayMode == .thumbnails)
            #expect(store.viewSettings.thumbnailSize == 200)
            #expect(store.viewSettings.showsToolbar)
            #expect(store.playback == PlaybackOptions(autoplay: false, loop: false))
            #expect(!store.confirmation.confirmBeforeFileOperations)
            #expect(store.favorites.urls == [a])
            #expect(store.favorites.customName(for: a) == "one")
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
