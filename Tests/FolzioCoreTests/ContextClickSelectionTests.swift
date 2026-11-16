import FolzioCore
import Testing

@Suite("Context click selection")
struct ContextClickSelectionTests {
    @Test("A context click on an unselected item selects only that item (FR-397)",
          arguments: [Set<Int>(), [0], [0, 2, 3]])
    func unselectedItemBecomesTheSelection(_ selected: Set<Int>) {
        #expect(ContextClickSelection.newSelection(clicked: 1, selected: selected, itemCount: 5) == [1])
    }

    @Test("A context click on a selected item keeps the selection (SC-220)", arguments: [Set<Int>([1]), [0, 1, 2]])
    func selectedItemKeepsTheSelection(_ selected: Set<Int>) {
        #expect(ContextClickSelection.newSelection(clicked: 1, selected: selected, itemCount: 5) == nil)
    }

    @Test("A context click on the background keeps the selection (FR-213)")
    func backgroundKeepsTheSelection() {
        #expect(ContextClickSelection.newSelection(clicked: nil, selected: [0], itemCount: 5) == nil)
        #expect(ContextClickSelection.newSelection(clicked: nil, selected: [], itemCount: 5) == nil)
    }

    @Test("An index outside the listing keeps the selection", arguments: [-1, 5, 9])
    func outOfRangeKeepsTheSelection(_ clicked: Int) {
        #expect(ContextClickSelection.newSelection(clicked: clicked, selected: [0], itemCount: 5) == nil)
    }
}
