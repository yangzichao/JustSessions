/// The color schemes terminals can use whatever the app theme is: each app theme's terminal colors, then schemes made
/// for terminals.
enum TerminalColorPreset: String, CaseIterable, Identifiable, Sendable {
    case justSessions
    case solarized
    case gruvbox
    case catppuccin
    case tokyoNight
    case rosePine
    case dracula
    case nord
    case oneHalf
    case gitHub

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justSessions: AppTheme.justSessions.displayName
        case .solarized: AppTheme.solarized.displayName
        case .gruvbox: AppTheme.gruvbox.displayName
        case .catppuccin: AppTheme.catppuccin.displayName
        case .tokyoNight: AppTheme.tokyoNight.displayName
        case .rosePine: AppTheme.rosePine.displayName
        case .dracula: "Dracula"
        case .nord: "Nord"
        case .oneHalf: "One Half"
        case .gitHub: "GitHub"
        }
    }

    var variants: TerminalPaletteVariants {
        switch self {
        case .justSessions: TerminalPaletteVariants(appTheme: .justSessions)
        case .solarized: TerminalPaletteVariants(appTheme: .solarized)
        case .gruvbox: TerminalPaletteVariants(appTheme: .gruvbox)
        case .catppuccin: TerminalPaletteVariants(appTheme: .catppuccin)
        case .tokyoNight: TerminalPaletteVariants(appTheme: .tokyoNight)
        case .rosePine: TerminalPaletteVariants(appTheme: .rosePine)
        case .dracula: .single(.dracula)
        case .nord: .single(.nord)
        case .oneHalf: .lightAndDark(light: .oneHalfLight, dark: .oneHalfDark)
        case .gitHub: .lightAndDark(light: .gitHubLight, dark: .gitHubDark)
        }
    }
}
