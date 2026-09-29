/// Rosé Pine Dawn for light and the main variant for dark, with the colors of rose-pine/alacritty.
extension AppThemeColors {
    static let rosePineDawn = AppThemeColors(
        sidebarSurface: 0xF2E9E1,
        contentSurface: 0xFAF4ED,
        raisedSurface: 0xFFFAF3,
        userMessageSurface: 0xF2E9E1,
        ink: 0x575279,
        inkForeground: 0xFAF4ED,
        line: 0x575279,
        terminal: TerminalColorScheme(
            foreground: 0x575279,
            selectionBackground: 0xDFDAD9,
            selectionForeground: 0x575279,
            ansiHexColors: [
                0xF2E9E1, 0xB4637A, 0x286983, 0xEA9D34,
                0x56949F, 0x907AA9, 0xD7827E, 0x575279,
                0x9893A5, 0xB4637A, 0x286983, 0xEA9D34,
                0x56949F, 0x907AA9, 0xD7827E, 0x575279,
            ]
        )
    )

    static let rosePineMain = AppThemeColors(
        // A shade below base, which is the darkest color Rosé Pine has.
        sidebarSurface: 0x13111D,
        contentSurface: 0x191724,
        raisedSurface: 0x26233A,
        userMessageSurface: 0x26233A,
        ink: 0xE0DEF4,
        inkForeground: 0x191724,
        line: 0xE0DEF4,
        terminal: TerminalColorScheme(
            foreground: 0xE0DEF4,
            selectionBackground: 0x403D52,
            selectionForeground: 0xE0DEF4,
            ansiHexColors: [
                0x26233A, 0xEB6F92, 0x31748F, 0xF6C177,
                0x9CCFD8, 0xC4A7E7, 0xEBBCBA, 0xE0DEF4,
                0x6E6A86, 0xEB6F92, 0x31748F, 0xF6C177,
                0x9CCFD8, 0xC4A7E7, 0xEBBCBA, 0xE0DEF4,
            ]
        )
    )
}
