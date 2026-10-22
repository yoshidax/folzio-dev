import Foundation

/// 検索起点ディレクトリの入力が使えない理由（FR-081、research.md R35）。`message` を入力欄の下に出す
public enum SearchRootError: Error, Sendable, Equatable {
    case empty
    case notAbsolute
    case notFound
    case notAFolder
    case accessDenied

    public var message: String {
        switch self {
        case .empty:
            return "検索起点ディレクトリを入力してください"
        case .notAbsolute:
            return "/ または ~ で始まるパスを入力してください"
        case .notFound:
            return "フォルダが見つかりません"
        case .notAFolder:
            return "フォルダではありません"
        case .accessDenied:
            return "フォルダを読み取れません"
        }
    }
}

/// 検索起点ディレクトリの入力の解釈（`parse`。ディスクを読まない）と確認（`validate`。UI スレッドの外でディスクを読む）
public enum SearchRoot {
    /// 前後の空白を除き、`~` と `~/` をホームに置き換え、`.`・`..`・末尾の `/` を畳む。
    /// `/` でも `~` でも始まらない入力と `~user` の形は `.notAbsolute`
    public static func parse(_ input: String, home: URL) -> Result<URL, SearchRootError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        let path: String
        if trimmed == "~" {
            path = home.path
        } else if trimmed.hasPrefix("~/") {
            path = home.path + "/" + trimmed.dropFirst(2)
        } else if trimmed.hasPrefix("/") {
            path = trimmed
        } else {
            return .failure(.notAbsolute)
        }
        return .success(URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL)
    }

    /// 存在・フォルダであること（パッケージと zip ファイルを除く）・開けることを確かめる。
    /// 成功ならシンボリックリンクを解決した URL を返す
    public static func validate(_ url: URL) async -> Result<URL, SearchRootError> {
        await Task.detached(priority: .userInitiated) {
            let resolved = url.resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else {
                return .failure(.notFound)
            }
            guard isDirectory.boolValue else { return .failure(.notAFolder) }
            if (try? resolved.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true {
                return .failure(.notAFolder)
            }
            guard let directory = opendir(resolved.path) else { return .failure(.accessDenied) }
            closedir(directory)
            return .success(resolved)
        }.value
    }
}
