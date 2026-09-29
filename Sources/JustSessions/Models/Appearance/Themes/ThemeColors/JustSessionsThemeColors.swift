/// The app's own theme: warm neutrals in place of system gray and white, with the brand Ink. Its ANSI colors are
/// tuned separately for paper and charcoal so colored text stays readable on either.
extension AppThemeColors {
    static let justSessionsLight = AppThemeColors(
        sidebarSurface: 0xF3F1EC,
        contentSurface: 0xFCFBF8,
        raisedSurface: 0xFFFFFF,
        userMessageSurface: 0xF1EDE6,
        ink: 0x15171C,
        inkForeground: 0xFFFFFF,
        line: 0x15171C,
        terminal: TerminalColorScheme(
            foreground: 0x303139,
            selectionBackground: 0xD9E4EF,
            selectionForeground: 0x202733,
            ansiHexColors: [
                0x303139, 0xB43C42, 0x327348, 0x8A631B,
                0x365FA6, 0x87509D, 0x237479, 0xB6B2AA,
                0x6C6C74, 0xBE3941, 0x277640, 0x886000,
                0x315FAF, 0x9146A4, 0x12747B, 0xFCFBF8,
            ]
        )
    )

    static let justSessionsDark = AppThemeColors(
        sidebarSurface: 0x19191C,
        contentSurface: 0x1F1F23,
        raisedSurface: 0x2C2C31,
        userMessageSurface: 0x2A2A2F,
        ink: 0xECEAE5,
        inkForeground: 0x15171C,
        line: 0xFFFFFF,
        terminal: TerminalColorScheme(
            foreground: 0xECEAE5,
            selectionBackground: 0x3C4B62,
            selectionForeground: 0xFFFFFF,
            ansiHexColors: [
                0x292A30, 0xE88287, 0x96C89C, 0xDEC084,
                0x94B3EA, 0xC8A0D9, 0x87C8C8, 0xD2D0CA,
                0x8F9099, 0xF19A9E, 0xAEDBB3, 0xEAD29D,
                0xADC7F3, 0xD9B6E7, 0xA2DADA, 0xFCFBF8,
            ]
        )
    )
}
