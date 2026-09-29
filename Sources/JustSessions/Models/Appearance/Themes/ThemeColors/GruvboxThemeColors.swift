/// morhetz's Gruvbox, from `gruvbox.vim`, with the terminal colors of gruvbox-contrib's iTerm2 themes.
extension AppThemeColors {
    static let gruvboxLight = AppThemeColors(
        sidebarSurface: 0xF2E5BC,
        contentSurface: 0xFBF1C7,
        raisedSurface: 0xF9F5D7,
        userMessageSurface: 0xEBDBB2,
        ink: 0x3C3836,
        inkForeground: 0xFBF1C7,
        line: 0x3C3836,
        terminal: TerminalColorScheme(
            foreground: 0x3C3836,
            selectionBackground: 0xD5C4A1,
            selectionForeground: 0x3C3836,
            ansiHexColors: [
                0xFBF1C7, 0xCC241D, 0x98971A, 0xD79921,
                0x458588, 0xB16286, 0x689D6A, 0x7C6F64,
                0x928374, 0x9D0006, 0x79740E, 0xB57614,
                0x076678, 0x8F3F71, 0x427B58, 0x3C3836,
            ]
        )
    )

    static let gruvboxDark = AppThemeColors(
        sidebarSurface: 0x1D2021,
        contentSurface: 0x282828,
        raisedSurface: 0x3C3836,
        userMessageSurface: 0x32302F,
        ink: 0xEBDBB2,
        inkForeground: 0x282828,
        line: 0xEBDBB2,
        terminal: TerminalColorScheme(
            foreground: 0xEBDBB2,
            selectionBackground: 0x504945,
            selectionForeground: 0xEBDBB2,
            ansiHexColors: [
                0x282828, 0xCC241D, 0x98971A, 0xD79921,
                0x458588, 0xB16286, 0x689D6A, 0xA89984,
                0x928374, 0xFB4934, 0xB8BB26, 0xFABD2F,
                0x83A598, 0xD3869B, 0x8EC07C, 0xEBDBB2,
            ]
        )
    )
}
