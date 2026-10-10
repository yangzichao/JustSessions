/// A color scheme in one version, or in a light and a dark version that the terminal's Appearance setting picks between.
enum TerminalPaletteVariants: Codable, Equatable, Sendable {
    case single(TerminalPalette)
    case lightAndDark(light: TerminalPalette, dark: TerminalPalette)

    init(appTheme: ResolvedAppTheme) {
        self = .lightAndDark(light: appTheme.colors(isDark: false).terminalPalette, dark: appTheme.colors(isDark: true).terminalPalette)
    }

    var hasLightAndDarkVersions: Bool {
        if case .lightAndDark = self { return true }
        return false
    }

    func palette(usesDarkColors: Bool) -> TerminalPalette {
        switch self {
        case .single(let palette): palette
        case .lightAndDark(let light, let dark): usesDarkColors ? dark : light
        }
    }
}
