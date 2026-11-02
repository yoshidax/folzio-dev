import FolzioCore
import Testing

@Suite("Shortcut Assignments")
struct ShortcutAssignmentsTests {
    private let optionCommandJ = KeyCombination(key: "j", modifiers: [.option, .command])

    @Test("Assigning a free combination overrides the default")
    func assignsFreeCombination() throws {
        let assignments = try ShortcutAssignments().assigning(optionCommandJ, to: .newFolder).get()
        #expect(assignments.combination(for: .newFolder) == optionCommandJ)
        #expect(assignments.isOverridden(.newFolder))
        #expect(assignments.storedOverrides == ["newFolder": "opt+cmd+j"])
    }

    @Test("A candidate without Command, Control, or Option is rejected")
    func rejectsMissingModifier() {
        for candidate in [
            KeyCombination(key: "a", modifiers: []),
            KeyCombination(key: "a", modifiers: [.shift]),
            KeyCombination(key: "return", modifiers: []),
        ] {
            #expect(ShortcutAssignments().assigning(candidate, to: .newFolder) == .failure(.missingModifier))
        }
    }

    @Test("Reserved keys are rejected as reserved")
    func rejectsReserved() {
        for candidate in [
            KeyCombination(key: "q", modifiers: [.command]),
            KeyCombination(key: "w", modifiers: [.command]),
            KeyCombination(key: ",", modifiers: [.command]),
            KeyCombination(key: "c", modifiers: [.command]),
        ] {
            #expect(ShortcutAssignments().assigning(candidate, to: .newFolder) == .failure(.reserved), "\(candidate)")
        }
    }

    @Test("Fixed keys are rejected as fixed, and Shift-only fixed keys fail the modifier rule first")
    func rejectsFixed() {
        for candidate in [
            KeyCombination(key: "right", modifiers: [.option]),
            KeyCombination(key: "up", modifiers: [.option]),
            KeyCombination(key: "a", modifiers: [.command]),
        ] {
            #expect(ShortcutAssignments().assigning(candidate, to: .newFolder) == .failure(.fixed), "\(candidate)")
        }
        #expect(
            ShortcutAssignments().assigning(KeyCombination(key: "tab", modifiers: [.shift]), to: .newFolder)
                == .failure(.missingModifier)
        )
    }

    @Test("The key of another command, even at its default, is a conflict")
    func rejectsConflict() {
        let result = ShortcutAssignments().assigning(KeyCombination(key: "f", modifiers: [.command]), to: .newFolder)
        #expect(result == .failure(.conflict(.find)))
    }

    @Test("The same combination as the current one succeeds without a change")
    func sameCombinationIsNotAConflict() throws {
        let current = ShortcutAssignments()
        let again = try current.assigning(KeyCombination(key: "n", modifiers: [.shift, .command]), to: .newFolder).get()
        #expect(again == current)
    }

    @Test("Validation order is modifier, then reserved or fixed, then conflict")
    func validationOrder() {
        let assignments = ShortcutAssignments()
        #expect(assignments.error(for: KeyCombination(key: "q", modifiers: []), assigningTo: .find) == .missingModifier)
        #expect(
            assignments.error(for: KeyCombination(key: "q", modifiers: [.command]), assigningTo: .find) == .reserved
        )
        #expect(
            assignments.error(for: KeyCombination(key: "n", modifiers: [.shift, .command]), assigningTo: .find)
                == .conflict(.newFolder)
        )
    }

    @Test("After a change, the old default key becomes free for another command")
    func freedKeyIsAssignable() throws {
        let moved = try ShortcutAssignments().assigning(optionCommandJ, to: .newFolder).get()
        let taken = try moved.assigning(KeyCombination(key: "n", modifiers: [.shift, .command]), to: .find).get()
        #expect(taken.combination(for: .find) == KeyCombination(key: "n", modifiers: [.shift, .command]))
    }

    @Test("Assigning a command its own default removes the override")
    func assigningDefaultClearsOverride() throws {
        let moved = try ShortcutAssignments().assigning(optionCommandJ, to: .newFolder).get()
        let back = try moved.assigning(KeyCombination(key: "n", modifiers: [.shift, .command]), to: .newFolder).get()
        #expect(back.overrides.isEmpty)
    }

    @Test("Resetting returns a command to its default unless another command uses that key")
    func resetting() throws {
        let moved = try ShortcutAssignments().assigning(optionCommandJ, to: .newFolder).get()
        #expect(try moved.resetting(.newFolder).get().overrides.isEmpty)
        let taken = try moved.assigning(KeyCombination(key: "n", modifiers: [.shift, .command]), to: .find).get()
        #expect(taken.resetting(.newFolder) == .failure(.conflict(.find)))
        #expect(try ShortcutAssignments().resetting(.newFolder).get() == ShortcutAssignments())
    }

    @Test("Resetting all removes every override")
    func resettingAll() throws {
        let changed = try ShortcutAssignments().assigning(optionCommandJ, to: .newFolder).get()
        #expect(changed.resettingAll().overrides.isEmpty)
    }

    @Test("Zoom in's alternate works only while it keeps its default key")
    func zoomAlternate() throws {
        let defaults = ShortcutAssignments()
        let equals = KeyCombination(key: "=", modifiers: [.command])
        #expect(defaults.activeAlternates(for: .zoomIn) == [equals])
        #expect(defaults.assigning(equals, to: .find) == .failure(.conflict(.zoomIn)))
        let moved = try defaults.assigning(optionCommandJ, to: .zoomIn).get()
        #expect(moved.activeAlternates(for: .zoomIn).isEmpty)
        #expect(try moved.assigning(equals, to: .find).get().combination(for: .find) == equals)
    }

    @Test("Stored overrides restore, and broken entries are dropped on their own")
    func loadsStoredOverrides() {
        let stored = [
            "newFolder": "opt+cmd+j",
            "find": "cmd+q",          // reserved
            "open": "x",              // unreadable
            "unknownCommand": "cmd+k", // not a command
            "duplicate": "j",         // no required modifier
        ]
        let assignments = ShortcutAssignments(storedOverrides: stored)
        #expect(assignments.overrides.count == 1)
        #expect(assignments.combination(for: .newFolder) == optionCommandJ)
        #expect(assignments.combination(for: .find) == KeyCombination(key: "f", modifiers: [.command]))
    }

    @Test("Of two stored values with the same key, the later command returns to its default")
    func loadsDuplicateStoredValues() {
        // newFolder comes before find in the command order, so find loses.
        let stored = ["find": "opt+cmd+j", "newFolder": "opt+cmd+j"]
        let assignments = ShortcutAssignments(storedOverrides: stored)
        #expect(assignments.combination(for: .newFolder) == optionCommandJ)
        #expect(assignments.combination(for: .find) == KeyCombination(key: "f", modifiers: [.command]))
    }

    @Test("A stored swap of two default keys is accepted when the result has no duplicate")
    func loadsSwap() {
        let stored = ["find": "shift+cmd+n", "newFolder": "cmd+f"]
        let assignments = ShortcutAssignments(storedOverrides: stored)
        #expect(assignments.combination(for: .find) == KeyCombination(key: "n", modifiers: [.shift, .command]))
        #expect(assignments.combination(for: .newFolder) == KeyCombination(key: "f", modifiers: [.command]))
    }

    @Test("A stored value that equals the default or an active alternate of another command is dropped")
    func loadsStoredValueEqualToDefault() {
        let assignments = ShortcutAssignments(storedOverrides: ["find": "cmd+f", "open": "cmd+="])
        #expect(assignments.overrides.isEmpty)
    }
}
