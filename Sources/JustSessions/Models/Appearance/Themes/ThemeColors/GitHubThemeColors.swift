/// GitHub Light and Dark, with the surfaces and ANSI colors from @primer/primitives 11.10.0. The sidebar is Primer's
/// inset background, raised controls its selected side-nav item, and your messages its muted background. Primer's
/// selection colors are translucent, so each is laid over its background here.
extension AppThemeColors {
    static let gitHubLight = AppThemeColors(
        sidebarSurface: 0xF6F8FA,
        contentSurface: 0xFFFFFF,
        // White like the content, as Primer's selected side-nav item is. Raised controls here also draw a hairline.
        raisedSurface: 0xFFFFFF,
        userMessageSurface: 0xF6F8FA,
        ink: 0x1F2328,
        inkForeground: 0xFFFFFF,
        line: 0x1F2328,
        terminal: TerminalColorScheme(
            foreground: 0x1F2328,
            selectionBackground: ThemeColorContrast.blend(0xFFFFFF, with: 0x0969DA, fraction: 0.2),
            selectionForeground: 0x1F2328,
            ansiHexColors: [
                0x1F2328, 0xCF222E, 0x116329, 0x4D2D00,
                0x0969DA, 0x8250DF, 0x1B7C83, 0x59636E,
                0x393F46, 0xA40E26, 0x1A7F37, 0x633C01,
                0x218BFF, 0xA475F9, 0x3192AA, 0x818B98,
            ]
        )
    )

    static let gitHubDark = AppThemeColors(
        sidebarSurface: 0x010409,
        contentSurface: 0x0D1117,
        raisedSurface: 0x212830,
        userMessageSurface: 0x151B23,
        ink: 0xF0F6FC,
        inkForeground: 0x0D1117,
        line: 0xF0F6FC,
        terminal: TerminalColorScheme(
            foreground: 0xF0F6FC,
            selectionBackground: ThemeColorContrast.blend(0x0D1117, with: 0x1F6FEB, fraction: 0.7),
            selectionForeground: 0xF0F6FC,
            ansiHexColors: [
                0x2F3742, 0xFF7B72, 0x3FB950, 0xD29922,
                0x58A6FF, 0xBE8FFF, 0x39C5CF, 0xF0F6FC,
                0x656C76, 0xFFA198, 0x56D364, 0xE3B341,
                0x79C0FF, 0xD2A8FF, 0x56D4DD, 0xFFFFFF,
            ]
        )
    )
}
