/// A terminal's colors in one theme: its text, its selection, and the 16 ANSI colors. Terminals sit on the theme's
/// content surface, so the background comes from there.
struct TerminalColorScheme: Equatable, Sendable {
    let foreground: UInt32
    let selectionBackground: UInt32
    let selectionForeground: UInt32
    /// Black, red, green, yellow, blue, magenta, cyan, and white, then the bright version of each.
    let ansiHexColors: [UInt32]
}
