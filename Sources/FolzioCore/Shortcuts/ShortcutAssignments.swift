/// Why a key combination cannot be assigned to a command.
public enum ShortcutAssignmentError: Error, Equatable, Sendable {
    /// The combination has none of Command, Control, or Option.
    case missingModifier
    /// The combination belongs to the app or the system and cannot be reassigned.
    case reserved
    /// The combination is a context-dependent key that is not assignable.
    case fixed
    /// Another command already uses the combination.
    case conflict(ShortcutCommandID)
}

/// The current key of every command: the defaults plus the user's overrides.
///
/// Invariants: every command has one combination; no two commands share one; every combination has a required
/// modifier and is neither fixed nor reserved. Every mutation returns a new value and keeps the invariants.
public struct ShortcutAssignments: Equatable, Sendable {
    /// The combinations that differ from the default.
    public private(set) var overrides: [ShortcutCommandID: KeyCombination]

    /// Creates the default assignments.
    public init() {
        overrides = [:]
    }

    /// Restores assignments from stored text (command raw value → stored combination).
    ///
    /// Entries for unknown commands, unreadable text, or combinations that are not allowed are dropped. When two
    /// commands end up with the same combination, the override of the later command in `ShortcutCommands.all`
    /// returns to its default.
    public init(storedOverrides: [String: String]) {
        var accepted: [ShortcutCommandID: KeyCombination] = [:]
        for command in ShortcutCommands.all {
            guard let text = storedOverrides[command.id.rawValue],
                  let combination = KeyCombination(storedText: text),
                  Self.staticError(for: combination) == nil,
                  combination != command.defaultCombination else { continue }
            accepted[command.id] = combination
        }
        var result = ShortcutAssignments()
        result.overrides = accepted
        while let loser = result.firstOverrideInConflict() {
            result.overrides[loser] = nil
        }
        self = result
    }

    /// The text to store: only the overrides.
    public var storedOverrides: [String: String] {
        Dictionary(uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value.storedText) })
    }

    /// The command's current combination.
    public func combination(for id: ShortcutCommandID) -> KeyCombination {
        overrides[id] ?? ShortcutCommands.command(id).defaultCombination
    }

    /// Extra keys that currently work for the command. They work only while the command keeps its default key.
    public func activeAlternates(for id: ShortcutCommandID) -> [KeyCombination] {
        overrides[id] == nil ? ShortcutCommands.command(id).alternates : []
    }

    public func isOverridden(_ id: ShortcutCommandID) -> Bool {
        overrides[id] != nil
    }

    /// The command that uses the combination now (as its key or an active alternate), ignoring `excluded`.
    public func command(using combination: KeyCombination, excluding excluded: ShortcutCommandID? = nil) -> ShortcutCommandID? {
        for command in ShortcutCommands.all where command.id != excluded {
            if self.combination(for: command.id) == combination
                || activeAlternates(for: command.id).contains(combination) {
                return command.id
            }
        }
        return nil
    }

    /// Checks a candidate in this order: required modifier, reserved or fixed key, then conflict with another command.
    public func error(for candidate: KeyCombination, assigningTo id: ShortcutCommandID) -> ShortcutAssignmentError? {
        if let error = Self.staticError(for: candidate) { return error }
        if let other = command(using: candidate, excluding: id) { return .conflict(other) }
        return nil
    }

    /// Assigns a combination. The same combination as the current one succeeds without a change.
    public func assigning(
        _ candidate: KeyCombination,
        to id: ShortcutCommandID
    ) -> Result<ShortcutAssignments, ShortcutAssignmentError> {
        if candidate == combination(for: id) { return .success(self) }
        if let error = error(for: candidate, assigningTo: id) { return .failure(error) }
        var copy = self
        if candidate == ShortcutCommands.command(id).defaultCombination {
            copy.overrides[id] = nil
        } else {
            copy.overrides[id] = candidate
        }
        return .success(copy)
    }

    /// Returns the command to its default key, unless another command uses that key now.
    public func resetting(_ id: ShortcutCommandID) -> Result<ShortcutAssignments, ShortcutAssignmentError> {
        guard overrides[id] != nil else { return .success(self) }
        let defaultCombination = ShortcutCommands.command(id).defaultCombination
        if let other = command(using: defaultCombination, excluding: id) { return .failure(.conflict(other)) }
        var copy = self
        copy.overrides[id] = nil
        return .success(copy)
    }

    public func resettingAll() -> ShortcutAssignments {
        ShortcutAssignments()
    }

    private static func staticError(for combination: KeyCombination) -> ShortcutAssignmentError? {
        if !combination.hasRequiredModifier { return .missingModifier }
        if ReservedShortcutKeys.combinations.contains(combination) { return .reserved }
        if FixedShortcutKeys.combinations.contains(combination) { return .fixed }
        return nil
    }

    /// Finds an override that shares its combination with another command, preferring the later command.
    private func firstOverrideInConflict() -> ShortcutCommandID? {
        for command in ShortcutCommands.all.reversed() where overrides[command.id] != nil {
            if self.command(using: combination(for: command.id), excluding: command.id) != nil {
                return command.id
            }
        }
        return nil
    }
}
