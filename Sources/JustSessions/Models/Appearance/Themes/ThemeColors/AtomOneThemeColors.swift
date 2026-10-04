/// Atom's One Light and One Dark. The surfaces are the editor background and the One UI themes' tree view, button,
/// and highlight colors, and the ink is their active tab text, from atom/atom 1c3bd35 compiled with Less. The ANSI
/// colors are One Half's, the terminal port of One, from sonph/onehalf 75eb2e9's iTerm2 colors.
extension AppThemeColors {
    static let atomOneLight = AppThemeColors(
        sidebarSurface: 0xEAEAEB,
        contentSurface: 0xFAFAFA,
        raisedSurface: 0xFFFFFF,
        userMessageSurface: 0xE5E5E6,
        ink: 0x232324,
        inkForeground: 0xFAFAFA,
        line: 0x232324,
        terminal: TerminalColorScheme(
            foreground: 0x383A42,
            selectionBackground: 0xBFCEFF,
            selectionForeground: 0x383A42,
            ansiHexColors: [
                0x383A42, 0xE45649, 0x50A14F, 0xC18401,
                0x0184BC, 0xA626A4, 0x0997B3, 0xFAFAFA,
                0x4F525E, 0xE06C75, 0x98C379, 0xE5C07B,
                0x61AFEF, 0xC678DD, 0x56B6C2, 0xFFFFFF,
            ]
        )
    )

    static let atomOneDark = AppThemeColors(
        sidebarSurface: 0x21252B,
        contentSurface: 0x282C34,
        raisedSurface: 0x353B45,
        userMessageSurface: 0x31363F,
        ink: 0xD7DAE0,
        inkForeground: 0x282C34,
        line: 0xD7DAE0,
        terminal: TerminalColorScheme(
            foreground: 0xDCDFE4,
            selectionBackground: 0x474E5D,
            selectionForeground: 0xDCDFE4,
            ansiHexColors: [
                // The iTerm2 colors make bright black the background color, which hides dim text and hints, so
                // bright black comes from the same repository's kitty colors.
                0x282C34, 0xE06C75, 0x98C379, 0xE5C07B,
                0x61AFEF, 0xC678DD, 0x56B6C2, 0xDCDFE4,
                0x5D677A, 0xE06C75, 0x98C379, 0xE5C07B,
                0x61AFEF, 0xC678DD, 0x56B6C2, 0xDCDFE4,
            ]
        )
    )
}
