/// A terminal's colors apart from its background: its text, its selection, and the 16 ANSI colors. A
/// `TerminalPalette` puts a scheme on its background.
struct TerminalColorScheme: Codable, Equatable, Sendable {
    let foreground: UInt32
    let selectionBackground: UInt32
    let selectionForeground: UInt32
    /// Black, red, green, yellow, blue, magenta, cyan, and white, then the bright version of each.
    let ansiHexColors: [UInt32]
}
