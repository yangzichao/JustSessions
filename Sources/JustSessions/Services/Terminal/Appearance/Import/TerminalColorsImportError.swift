/// Why colors could not be read from iTerm2 or from a file.
enum TerminalColorsImportError: Error, Equatable {
    /// iTerm2 has no saved settings on this Mac.
    case iTermSettingsNotFound
    /// iTerm2's default profile is not among its saved profiles, as when it is a dynamic profile.
    case iTermDefaultProfileNotFound
    /// The file could not be read as an iTerm2 color preset.
    case unreadableFile
    /// The text color, the background, or both the normal and bright version of an ANSI color are missing.
    case missingColors
}
