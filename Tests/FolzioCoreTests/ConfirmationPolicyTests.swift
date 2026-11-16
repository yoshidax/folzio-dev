import Foundation
import Testing
@testable import FolzioCore

@Suite("ConfirmationPolicy")
struct ConfirmationPolicyTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let kind: FileOperation.Kind
        let origin: OperationOrigin
        let target: ConfirmationTarget
        let requiresModalWithoutWindow: Bool

        var testDescription: String { "\(kind) / \(origin) → \(target)" }
    }

    static let cases: [Case] = [
        Case(kind: .copy, origin: .fileList, target: .copy, requiresModalWithoutWindow: false),
        Case(kind: .copy, origin: .tree, target: .copy, requiresModalWithoutWindow: false),
        Case(kind: .trash, origin: .fileList, target: .trash, requiresModalWithoutWindow: false),
        Case(kind: .trash, origin: .tree, target: .trash, requiresModalWithoutWindow: true),
        Case(kind: .move, origin: .fileList, target: .move, requiresModalWithoutWindow: true),
        Case(kind: .move, origin: .tree, target: .move, requiresModalWithoutWindow: true),
        Case(kind: .rename(newName: "b"), origin: .fileList, target: .rename, requiresModalWithoutWindow: true),
        Case(kind: .rename(newName: "b"), origin: .tree, target: .rename, requiresModalWithoutWindow: true),
    ]

    @Test("Each operation follows its own setting; Trash from the tree follows the Trash setting (FR-024, FR-079)",
          arguments: cases)
    func target(_ testCase: Case) {
        #expect(ConfirmationPolicy.target(for: testCase.kind, origin: testCase.origin) == testCase.target)
    }

    @Test("Move, rename, and Trash from the tree are never run unconfirmed without a window (EC-263)", arguments: cases)
    func modalWithoutWindow(_ testCase: Case) {
        #expect(ConfirmationPolicy.requiresModalWithoutWindow(testCase.kind, origin: testCase.origin)
            == testCase.requiresModalWithoutWindow)
    }
}
