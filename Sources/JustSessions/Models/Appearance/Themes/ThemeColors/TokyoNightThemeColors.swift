/// Tokyo Night's Day and Night styles, with the colors of the terminal themes in folke/tokyonight.nvim's extras.
extension AppThemeColors {
    static let tokyoNightDay = AppThemeColors(
        sidebarSurface: 0xD0D5E3,
        contentSurface: 0xE1E2E7,
        // A shade above bg, which is the lightest color Day has.
        raisedSurface: 0xECEDF1,
        userMessageSurface: 0xD0D5E3,
        ink: 0x3760BF,
        inkForeground: 0xE1E2E7,
        line: 0x3760BF,
        terminal: TerminalColorScheme(
            foreground: 0x3760BF,
            selectionBackground: 0xB7C1E3,
            selectionForeground: 0x3760BF,
            ansiHexColors: [
                0xB4B5B9, 0xF52A65, 0x587539, 0x8C6C3E,
                0x2E7DE9, 0x9854F1, 0x007197, 0x6172B0,
                0xA1A6C5, 0xFF4774, 0x5C8524, 0xA27629,
                0x358AFF, 0xA463FF, 0x007EA8, 0x3760BF,
            ]
        )
    )

    static let tokyoNightNight = AppThemeColors(
        sidebarSurface: 0x16161E,
        contentSurface: 0x1A1B26,
        raisedSurface: 0x292E42,
        userMessageSurface: 0x292E42,
        ink: 0xC0CAF5,
        inkForeground: 0x1A1B26,
        line: 0xC0CAF5,
        terminal: TerminalColorScheme(
            foreground: 0xC0CAF5,
            selectionBackground: 0x283457,
            selectionForeground: 0xC0CAF5,
            ansiHexColors: [
                0x15161E, 0xF7768E, 0x9ECE6A, 0xE0AF68,
                0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xA9B1D6,
                0x414868, 0xFF899D, 0x9FE044, 0xFABA4A,
                0x8DB0FF, 0xC7A9FF, 0xA4DAFF, 0xC0CAF5,
            ]
        )
    )
}
