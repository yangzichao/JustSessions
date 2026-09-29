/// Catppuccin Latte for light and Mocha for dark, with the ANSI colors from catppuccin/palette 1.8.0.
extension AppThemeColors {
    static let catppuccinLatte = AppThemeColors(
        sidebarSurface: 0xE6E9EF,
        contentSurface: 0xEFF1F5,
        // A shade above base, which is the lightest color Latte has.
        raisedSurface: 0xF9FAFC,
        userMessageSurface: 0xDCE0E8,
        ink: 0x4C4F69,
        inkForeground: 0xEFF1F5,
        line: 0x4C4F69,
        terminal: TerminalColorScheme(
            foreground: 0x4C4F69,
            selectionBackground: 0xBCC0CC,
            selectionForeground: 0x4C4F69,
            ansiHexColors: [
                0x5C5F77, 0xD20F39, 0x40A02B, 0xDF8E1D,
                0x1E66F5, 0xEA76CB, 0x179299, 0xACB0BE,
                0x6C6F85, 0xDE293E, 0x49AF3D, 0xEEA02D,
                0x456EFF, 0xFE85D8, 0x2D9FA8, 0xBCC0CC,
            ]
        )
    )

    static let catppuccinMocha = AppThemeColors(
        sidebarSurface: 0x181825,
        contentSurface: 0x1E1E2E,
        raisedSurface: 0x313244,
        userMessageSurface: 0x313244,
        ink: 0xCDD6F4,
        inkForeground: 0x1E1E2E,
        line: 0xCDD6F4,
        terminal: TerminalColorScheme(
            foreground: 0xCDD6F4,
            selectionBackground: 0x585B70,
            selectionForeground: 0xCDD6F4,
            ansiHexColors: [
                0x45475A, 0xF38BA8, 0xA6E3A1, 0xF9E2AF,
                0x89B4FA, 0xF5C2E7, 0x94E2D5, 0xA6ADC8,
                0x585B70, 0xF37799, 0x89D88B, 0xEBD391,
                0x74A8FC, 0xF2AEDE, 0x6BD7CA, 0xBAC2DE,
            ]
        )
    )
}
