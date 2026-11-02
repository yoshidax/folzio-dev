import FolzioCore
import Testing

@Suite("Toolbar Layout")
struct ToolbarLayoutTests {
    @Test("The default order lists the eight button sets in the approved order, followed by a flexible space")
    func defaultOrderMatchesApprovedOrder() {
        #expect(ToolbarLayout.defaultOrder == [
            "history", "paneLayout", "slideshow", "previewZoom",
            "mediaTypeFilter", "zipVisibility", "viewMode", "thumbnailSize",
            "NSToolbarFlexibleSpaceItem",
        ])
    }

    @Test("A valid saved order is kept as it is")
    func keepsValidOrder() {
        let saved = ["thumbnailSize", "history", "NSToolbarSpaceItem", "paneLayout", "NSToolbarFlexibleSpaceItem"]
        #expect(ToolbarLayout.normalized(saved: saved) == saved)
    }

    @Test("A set the user removed stays removed")
    func keepsRemovedSets() {
        let saved = ["history", "viewMode"]
        #expect(ToolbarLayout.normalized(saved: saved) == saved)
    }

    @Test("Space items may repeat")
    func keepsRepeatedSpaces() {
        let saved = ["history", "NSToolbarSpaceItem", "NSToolbarSpaceItem", "NSToolbarFlexibleSpaceItem", "viewMode"]
        #expect(ToolbarLayout.normalized(saved: saved) == saved)
    }

    @Test("Unknown identifiers are dropped")
    func dropsUnknownIdentifiers() {
        let saved = ["history", "futureItem", "viewMode"]
        #expect(ToolbarLayout.normalized(saved: saved) == ["history", "viewMode"])
    }

    @Test("A repeated button set keeps only its first occurrence")
    func dropsRepeatedSets() {
        let saved = ["history", "viewMode", "history", "viewMode"]
        #expect(ToolbarLayout.normalized(saved: saved) == ["history", "viewMode"])
    }

    @Test("An empty order, a missing value, and values of other types give the default order")
    func invalidValuesGiveDefaultOrder() {
        #expect(ToolbarLayout.normalized(saved: [String]()) == ToolbarLayout.defaultOrder)
        #expect(ToolbarLayout.normalized(saved: nil) == ToolbarLayout.defaultOrder)
        #expect(ToolbarLayout.normalized(saved: "history") == ToolbarLayout.defaultOrder)
        #expect(ToolbarLayout.normalized(saved: 42) == ToolbarLayout.defaultOrder)
        #expect(ToolbarLayout.normalized(saved: ["history", 1] as [Any]) == ToolbarLayout.defaultOrder)
    }

    @Test("An order with no allowed identifier gives the default order")
    func onlyUnknownIdentifiersGiveDefaultOrder() {
        #expect(ToolbarLayout.normalized(saved: ["a", "b"]) == ToolbarLayout.defaultOrder)
    }
}
