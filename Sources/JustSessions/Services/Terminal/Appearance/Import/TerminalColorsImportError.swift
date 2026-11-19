enum TerminalColorsImportError: Error, Equatable {
    case iTermSettingsNotFound
    case iTermDefaultProfileNotFound
    case unreadableFile
    case missingColors
}
