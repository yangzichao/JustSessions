/// Ethan Schoonover's Solarized, with the terminal colors from its README's 16-color table. The one change: Solarized
/// puts its dark background in bright black, which many CLIs use for hints and dim text, so dark uses base01 there.
extension AppThemeColors {
    private static let solarizedANSIColors: [UInt32] = [
        0x073642, 0xDC322F, 0x859900, 0xB58900,
        0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
        0x002B36, 0xCB4B16, 0x586E75, 0x657B83,
        0x839496, 0x6C71C4, 0x93A1A1, 0xFDF6E3,
    ]

    static let solarizedLight = AppThemeColors(
        sidebarSurface: 0xEEE8D5,
        contentSurface: 0xFDF6E3,
        // A shade above base3, which is the lightest color Solarized has.
        raisedSurface: 0xFFFBF0,
        userMessageSurface: 0xEEE8D5,
        ink: 0x073642,
        inkForeground: 0xFDF6E3,
        line: 0x073642,
        terminal: TerminalColorScheme(
            foreground: 0x657B83,
            selectionBackground: 0xEEE8D5,
            selectionForeground: 0x586E75,
            ansiHexColors: solarizedANSIColors
        )
    )

    static let solarizedDark = AppThemeColors(
        // A shade below base03, which is the darkest color Solarized has.
        sidebarSurface: 0x00252F,
        contentSurface: 0x002B36,
        raisedSurface: 0x073642,
        userMessageSurface: 0x073642,
        ink: 0xEEE8D5,
        inkForeground: 0x002B36,
        line: 0x93A1A1,
        terminal: TerminalColorScheme(
            foreground: 0x839496,
            selectionBackground: 0x073642,
            selectionForeground: 0x93A1A1,
            ansiHexColors: solarizedANSIColors.enumerated().map { index, hexValue in index == 8 ? 0x586E75 : hexValue }
        )
    )
}
