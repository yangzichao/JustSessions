/// Everything a terminal draws with: a color scheme and the background it sits on.
struct TerminalPalette: Codable, Equatable, Sendable {
    let background: UInt32
    let scheme: TerminalColorScheme

    /// Whether text sits on a dark background, so the terminal's scroller and other native parts should be dark.
    var isDark: Bool {
        ThemeColorContrast.ratio(0xFFFFFF, background) > ThemeColorContrast.ratio(0x000000, background)
    }
}

extension AppThemeColors {
    /// An app theme's terminals sit on its content surface.
    var terminalPalette: TerminalPalette {
        TerminalPalette(background: contentSurface, scheme: terminal)
    }
}
