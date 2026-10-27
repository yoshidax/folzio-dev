import Foundation

/// 標準パネルの初期位置を決められない理由。表示・読み上げに使う（data-model.md 2）
public enum SearchFolderInitialLocationError: Error, Sendable, Equatable {
    case noAvailableFolder

    public var message: String {
        "利用できるフォルダが見つかりません"
    }
}

/// 標準パネルの初期位置を、現在入力 → 開始時既定 → ホームの順に解決する（FR-143、data-model.md 2）。
///
/// 各候補は `SearchRoot.validate` と同じ条件で確認する。隠しフォルダは許可し、ファイル・zip・
/// パッケージ・読み取り不能なフォルダは飛ばす。検証処理はテストから注入できる
public enum SearchFolderInitialLocation {
    public typealias Validator = @Sendable (URL) async -> Result<URL, SearchRootError>

    public static func resolve(
        input: SearchRootInput,
        defaultPath: String?,
        home: URL,
        validate: Validator = { await SearchRoot.validate($0) }
    ) async -> Result<URL, SearchFolderInitialLocationError> {
        var candidates: [URL] = []
        if case let .success(url) = input.resolvedInput(home: home) {
            candidates.append(url)
        }
        if let defaultPath, defaultPath.hasPrefix("/"), !defaultPath.isEmpty {
            candidates.append(URL(fileURLWithPath: defaultPath, isDirectory: true))
        }
        candidates.append(home)

        var seen: Set<String> = []
        for candidate in candidates {
            guard seen.insert(SearchPath.normalized(candidate)).inserted else { continue }
            if case let .success(url) = await validate(candidate) {
                return .success(url)
            }
        }
        return .failure(.noAvailableFolder)
    }
}
