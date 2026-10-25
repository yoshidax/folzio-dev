import Foundation

public enum NameValidation: Sendable, Equatable {
    case ok
    case needsExtensionChangeConfirmation
    case invalid(reason: String)
}

/// `isDirectory` が true（フォルダの名前の変更）のときは、名前の `.` 以降を拡張子として扱わず、
/// 拡張子の変更の確認（`needsExtensionChangeConfirmation`）を返さない（research.md R32）。
/// パッケージになる名前（`.app` など）は、フォルダが見えなくなるため拒否する（EC-53、R57）
public func validateNewName(
    _ name: String,
    for file: URL,
    existingNames: Set<String>,
    isDirectory: Bool = false
) -> NameValidation {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .invalid(reason: "名前を入力してください")
    }
    guard !name.contains("/") && !name.contains(":") else {
        return .invalid(reason: "名前に「/」または「:」は使用できません")
    }
    guard !name.hasPrefix(".") else {
        return .invalid(reason: "名前の先頭に「.」は使用できません")
    }
    guard !existingNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
        return .invalid(reason: "同じ名前の項目がすでに存在します")
    }
    guard !(isDirectory && PackageName.isPackage(name)) else {
        return .invalid(reason: "この名前にするとフォルダがパッケージとして扱われ、表示されなくなります")
    }

    guard !isDirectory else { return .ok }

    let newExtension = (name as NSString).pathExtension
    guard newExtension.caseInsensitiveCompare(file.pathExtension) == .orderedSame else {
        return .needsExtensionChangeConfirmation
    }
    return .ok
}

public func uniqueName(for name: String, existingNames: Set<String>) -> String {
    let lowercasedNames = Set(existingNames.map { $0.lowercased() })
    let fileExtension = (name as NSString).pathExtension
    let stem = (name as NSString).deletingPathExtension

    var base = stem
    var counter = 2
    if let match = trailingCounter(in: stem) {
        base = match.base
        counter = match.number + 1
    }

    while true {
        let candidate = fileExtension.isEmpty
            ? "\(base) \(counter)"
            : "\(base) \(counter).\(fileExtension)"
        if !lowercasedNames.contains(candidate.lowercased()) {
            return candidate
        }
        counter += 1
    }
}

private func trailingCounter(in stem: String) -> (base: String, number: Int)? {
    guard let separator = stem.lastIndex(of: " ") else { return nil }
    let suffix = stem[stem.index(after: separator)...]
    guard !suffix.isEmpty, suffix.allSatisfy(\.isNumber), let number = Int(suffix) else {
        return nil
    }
    return (String(stem[..<separator]), number)
}
