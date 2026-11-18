import Foundation

/// Shared folder menu order and targets. Uses only the current in-memory listing (FR-401–404).
public struct FolderContextMenu: Sendable {
    public let items: [MediaFile]
    public let hasMissingTargets: Bool
    public let isBrowsingArchive: Bool
    public let containsRoot: Bool

    public init(files: [MediaFile], targets: Set<URL>, isBrowsingArchive: Bool, roots: [URL]) {
        items = files.filter { targets.contains($0.url) }
        hasMissingTargets = items.count != targets.count
        self.isBrowsingArchive = isBrowsingArchive
        let rootPaths = Set(roots.map { $0.standardizedFileURL.path })
        containsRoot = items.contains { $0.kind == .folder && rootPaths.contains($0.url.standardizedFileURL.path) }
    }

    public var containsFolder: Bool { items.contains { $0.kind == .folder } }
    public var onlyFolders: Bool {
        !isBrowsingArchive && !hasMissingTargets && !items.isEmpty && items.allSatisfy { $0.kind == .folder }
    }
    public var singleFolder: URL? { onlyFolders && items.count == 1 ? items[0].url : nil }

    /// A failed or ambiguous item target must never fall back to the displayed folder (FR-403).
    public func pasteDestination(isItemMenu: Bool, displayedFolder: URL, isShowingSearchResults: Bool) -> URL? {
        guard !isBrowsingArchive else { return nil }
        if isItemMenu && (containsFolder || hasMissingTargets) { return singleFolder }
        return isShowingSearchResults ? nil : displayedFolder
    }

    public static func items(allowsModification: Bool) -> [TreeContextMenuItem] {
        var result: [TreeContextMenuItem] = [.pasteHere, .movePasteHere, .separator]
        if allowsModification { result += [.moveToTrash, .separator, .renameFolder] }
        result += [.duplicate, .separator, .copy, .copyPathname, .separator, .addToFavorites, .separator, .revealInFinder]
        return result
    }
}
