struct TerminalPalette: Codable, Equatable, Sendable {
    let background: UInt32
    let scheme: TerminalColorScheme

    var isDark: Bool {
        ThemeColorContrast.ratio(0xFFFFFF, background) > ThemeColorContrast.ratio(0x000000, background)
    }
}

extension AppThemeColors {
    var terminalPalette: TerminalPalette {
        TerminalPalette(background: contentSurface, scheme: terminal)
    }
}
