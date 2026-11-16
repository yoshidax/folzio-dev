/// How a context click on the file list changes the selection, the same as in Finder's list and icon views (FR-397).
public enum ContextClickSelection {
    /// The selection to apply before the item menu opens.
    ///
    /// - Parameters:
    ///   - clicked: The index of the item under the pointer, or nil for the background.
    ///   - selected: The indices of the items selected now.
    ///   - itemCount: The number of items in the listing.
    /// - Returns: The new selection (only the clicked item), or nil to keep the current one. A click on the
    ///   background or outside the listing keeps it (FR-213), and so does a click on a selected item, so the menu
    ///   acts on the whole selection.
    public static func newSelection(clicked: Int?, selected: Set<Int>, itemCount: Int) -> Set<Int>? {
        guard let clicked, clicked >= 0, clicked < itemCount, !selected.contains(clicked) else { return nil }
        return [clicked]
    }
}
