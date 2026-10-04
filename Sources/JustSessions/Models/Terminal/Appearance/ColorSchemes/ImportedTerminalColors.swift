/// Colors copied once from iTerm2 or an .itermcolors file. They are saved with the terminal settings, so the source
/// is never read again.
struct ImportedTerminalColors: Codable, Equatable, Sendable {
    /// The iTerm2 profile or the file the colors came from, shown in Settings.
    let sourceName: String
    let variants: TerminalPaletteVariants
}
