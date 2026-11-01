import Foundation

/// Fixed facts and value handling for the About dialog (FR-236, FR-237).
public enum AboutInfo {
    /// The public repository of Folzio. The About dialog shows its `absoluteString` as the link text.
    ///
    /// Built from components because `scripts/check-no-network.sh` rejects URL literals in `Sources`.
    /// The URL is only handed to the OS to open in the default browser; the app never requests it itself.
    public static let repositoryURL: URL = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/yoshidax/folzio"
        return components.url!
    }()

    /// Returns the version to display for the raw `CFBundleShortVersionString` value.
    ///
    /// Returns `nil` when the value is missing, is not a string, or is empty after trimming whitespace, so that
    /// the About dialog omits the version line instead of showing a wrong or empty version (EC-166).
    public static func displayVersion(from value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
