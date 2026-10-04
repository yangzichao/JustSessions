import Foundation

/// Copies the colors of iTerm2's default profile. It reads iTerm2's settings only when asked, and reads nothing else.
enum ITermProfileColorsImporter {
    private static let preferencesDomain = "com.googlecode.iterm2"

    static func importDefaultProfile() throws -> ImportedTerminalColors {
        CFPreferencesAppSynchronize(preferencesDomain as CFString)
        return try importDefaultProfile(
            defaultProfileGuid: CFPreferencesCopyAppValue("Default Bookmark Guid" as CFString, preferencesDomain as CFString) as? String,
            profiles: CFPreferencesCopyAppValue("New Bookmarks" as CFString, preferencesDomain as CFString) as? [[String: Any]]
        )
    }

    static func importDefaultProfile(defaultProfileGuid: String?, profiles: [[String: Any]]?) throws -> ImportedTerminalColors {
        guard let profiles, !profiles.isEmpty else { throw TerminalColorsImportError.iTermSettingsNotFound }
        guard let profile = profiles.first(where: { $0["Guid"] as? String == defaultProfileGuid }) else {
            throw TerminalColorsImportError.iTermDefaultProfileNotFound
        }
        let variants = try ITermColorsReader.variants(
            from: profile,
            usesSeparateLightAndDarkColors: profile["Use Separate Colors for Light and Dark Mode"] as? Bool ?? false
        )
        let profileName = (profile["Name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return ImportedTerminalColors(sourceName: profileName.map { "iTerm2 · \($0)" } ?? "iTerm2", variants: variants)
    }
}
