/// Groups the shortcut reference by user intent, in display order.
public enum ShortcutSection: String, CaseIterable, Sendable {
    case panes
    case navigation
    case files
    case search
    case images
    case playback
    case application

    public var entries: [ShortcutEntry] {
        ShortcutCatalog.entries.filter { $0.section == self }
    }
}

/// Identifies a reference entry independently of its language and key glyphs.
public enum ShortcutID: String, CaseIterable, Sendable {
    case paneCycle
    case paneFocus
    case listOnly
    case previewOnly
    case toolbar
    case listStyle
    case thumbnailSize
    case imageFilter
    case movieFilter
    case zipVisibility
    case treeSelect
    case treeExpand
    case treeExpandAll
    case openContainer
    case enclosingFolder
    case history
    case favorites
    case addFavorite
    case selection
    case extendSelection
    case openDefault
    case quickLook
    case rename
    case copy
    case paste
    case copyPath
    case duplicate
    case newFolder
    case trash
    case find
    case searchSubmit
    case endSearch
    case imageZoom
    case imageFit
    case imageScroll
    case fullScreen
    case videoPlay
    case videoControls
    case videoSeek
    case slideshowStart
    case slideshowNavigate
    case slideshowStop
    case settings
    case cheatsheet
    case close
    case quit
}

/// Describes a shortcut without UI, translation, or command execution dependencies.
public struct ShortcutEntry: Equatable, Sendable {
    public let id: ShortcutID
    public let keys: String
    public let section: ShortcutSection
}

/// Provides the fixed shortcut reference. Context-specific uses of a key have separate entry IDs.
public enum ShortcutCatalog {
    public static let entries: [ShortcutEntry] = [
        ShortcutEntry(id: .paneCycle, keys: "Tab / ⇧Tab", section: .panes),
        ShortcutEntry(id: .paneFocus, keys: "⌥⌘1 / ⌥⌘2 / ⌥⌘3", section: .panes),
        ShortcutEntry(id: .listOnly, keys: "⌃⌘2", section: .panes),
        ShortcutEntry(id: .previewOnly, keys: "⌃⌘3", section: .panes),
        ShortcutEntry(id: .toolbar, keys: "⇧⌘T", section: .panes),
        ShortcutEntry(id: .listStyle, keys: "⌘1 / ⌘2", section: .panes),
        ShortcutEntry(id: .thumbnailSize, keys: "⌃⌘. / ⌃⌘,", section: .panes),
        ShortcutEntry(id: .imageFilter, keys: "⇧⌘I", section: .panes),
        ShortcutEntry(id: .movieFilter, keys: "⇧⌘M", section: .panes),
        ShortcutEntry(id: .zipVisibility, keys: "⌃⌘Z", section: .panes),
        ShortcutEntry(id: .treeSelect, keys: "↑ / ↓", section: .navigation),
        ShortcutEntry(id: .treeExpand, keys: "→ / ←", section: .navigation),
        ShortcutEntry(id: .treeExpandAll, keys: "⌥→ / ⌥←", section: .navigation),
        ShortcutEntry(id: .openContainer, keys: "⌘↓", section: .navigation),
        ShortcutEntry(id: .enclosingFolder, keys: "⌘↑", section: .navigation),
        ShortcutEntry(id: .history, keys: "⌘[ / ⌘]", section: .navigation),
        ShortcutEntry(id: .favorites, keys: "⇧⌘F", section: .navigation),
        ShortcutEntry(id: .addFavorite, keys: "⌃⌘T", section: .navigation),
        ShortcutEntry(id: .selection, keys: "↑ / ↓ / ← / →", section: .files),
        ShortcutEntry(id: .extendSelection, keys: "⇧↑ / ⇧↓ / ⇧← / ⇧→ / ⌘A", section: .files),
        ShortcutEntry(id: .openDefault, keys: "⌘O", section: .files),
        ShortcutEntry(id: .quickLook, keys: "Space", section: .files),
        ShortcutEntry(id: .rename, keys: "Return", section: .files),
        ShortcutEntry(id: .copy, keys: "⌘C", section: .files),
        ShortcutEntry(id: .paste, keys: "⌘V / ⌥⌘V", section: .files),
        ShortcutEntry(id: .copyPath, keys: "⌥⌘C", section: .files),
        ShortcutEntry(id: .duplicate, keys: "⌘D", section: .files),
        ShortcutEntry(id: .newFolder, keys: "⇧⌘N", section: .files),
        ShortcutEntry(id: .trash, keys: "⌘Delete", section: .files),
        ShortcutEntry(id: .find, keys: "⌘F", section: .search),
        ShortcutEntry(id: .searchSubmit, keys: "Return / Esc", section: .search),
        ShortcutEntry(id: .endSearch, keys: "Esc / ⌘[", section: .search),
        ShortcutEntry(id: .imageZoom, keys: "⌘+ / ⌘= / ⌘-", section: .images),
        ShortcutEntry(id: .imageFit, keys: "⌘0", section: .images),
        ShortcutEntry(id: .imageScroll, keys: "⌥↑ / ⌥↓ / ⌥← / ⌥→", section: .images),
        ShortcutEntry(id: .fullScreen, keys: "⌃⌘F", section: .images),
        ShortcutEntry(id: .videoPlay, keys: "Space", section: .playback),
        ShortcutEntry(id: .videoControls, keys: "← / → / ↑ / ↓", section: .playback),
        ShortcutEntry(id: .videoSeek, keys: "< / >", section: .playback),
        ShortcutEntry(id: .slideshowStart, keys: "⇧⌘S", section: .playback),
        ShortcutEntry(id: .slideshowNavigate, keys: "↑ / ↓ / ← / →", section: .playback),
        ShortcutEntry(id: .slideshowStop, keys: "Esc", section: .playback),
        ShortcutEntry(id: .settings, keys: "⌘,", section: .application),
        ShortcutEntry(id: .cheatsheet, keys: "⌘/", section: .application),
        ShortcutEntry(id: .close, keys: "⌘W", section: .application),
        ShortcutEntry(id: .quit, keys: "⌘Q", section: .application),
    ]
}
