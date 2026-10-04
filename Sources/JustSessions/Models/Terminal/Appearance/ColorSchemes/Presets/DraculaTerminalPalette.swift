/// Dracula has only a dark version. Colors from dracula/ghostty b0e6459, which follows the Dracula spec.
extension TerminalPalette {
    static let dracula = TerminalPalette(
        background: 0x282A36,
        scheme: TerminalColorScheme(
            foreground: 0xF8F8F2,
            selectionBackground: 0x44475A,
            selectionForeground: 0xF8F8F2,
            ansiHexColors: [
                0x21222C, 0xFF5555, 0x50FA7B, 0xF1FA8C,
                0xBD93F9, 0xFF79C6, 0x8BE9FD, 0xF8F8F2,
                0x6272A4, 0xFF6E6E, 0x69FF94, 0xFFFFA5,
                0xD6ACFF, 0xFF92DF, 0xA4FFFF, 0xFFFFFF,
            ]
        )
    )
}
