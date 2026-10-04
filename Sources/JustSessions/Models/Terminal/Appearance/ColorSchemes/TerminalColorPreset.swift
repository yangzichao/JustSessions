/// The color schemes terminals can use whatever the app theme is: each app theme's terminal colors, then schemes made
/// for terminals.
enum TerminalColorPreset: String, CaseIterable, Identifiable, Sendable {
    case justSessions
    case gitHub
    case atomOne
    case tokyoNight
    case catppuccin
    case gruvbox
    case dracula
    case nord

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justSessions: AppTheme.justSessions.displayName
        case .gitHub: AppTheme.gitHub.displayName
        case .atomOne: AppTheme.atomOne.displayName
        case .tokyoNight: AppTheme.tokyoNight.displayName
        case .catppuccin: AppTheme.catppuccin.displayName
        case .gruvbox: AppTheme.gruvbox.displayName
        case .dracula: "Dracula"
        case .nord: "Nord"
        }
    }

    var variants: TerminalPaletteVariants {
        switch self {
        case .justSessions: TerminalPaletteVariants(appTheme: .justSessions)
        case .gitHub: TerminalPaletteVariants(appTheme: .gitHub)
        case .atomOne: TerminalPaletteVariants(appTheme: .atomOne)
        case .tokyoNight: TerminalPaletteVariants(appTheme: .tokyoNight)
        case .catppuccin: TerminalPaletteVariants(appTheme: .catppuccin)
        case .gruvbox: TerminalPaletteVariants(appTheme: .gruvbox)
        case .dracula: .single(.dracula)
        case .nord: .single(.nord)
        }
    }
}
