/// A terminal's colors apart from its background: its text, its selection, and the 16 ANSI colors. A
/// `TerminalPalette` puts a scheme on its background.
struct TerminalColorScheme: Codable, Equatable, Sendable {
    let foreground: UInt32
    let selectionBackground: UInt32
    let selectionForeground: UInt32
    /// Black, red, green, yellow, blue, magenta, cyan, and white, then the bright version of each.
    let ansiHexColors: [UInt32]

    /// The selection's text color, darkened or lightened until it is readable on the selection. The terminal draws
    /// selected text in this one color, without the minimum contrast it keeps for other text, and some schemes'
    /// own pair falls short: Tokyo Night Day's is 3.3, and imported colors can be anything.
    var readableSelectionForeground: UInt32 {
        ThemeColorContrast.readableText(selectionForeground, on: [selectionBackground])
    }
}
