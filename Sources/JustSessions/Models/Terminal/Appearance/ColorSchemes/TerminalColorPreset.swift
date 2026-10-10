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
        case .justSessions: TerminalPaletteVariants(appTheme: ResolvedAppTheme(.justSessions))
        case .gitHub: TerminalPaletteVariants(appTheme: ResolvedAppTheme(.gitHub))
        case .atomOne: TerminalPaletteVariants(appTheme: ResolvedAppTheme(.atomOne))
        case .tokyoNight: TerminalPaletteVariants(appTheme: ResolvedAppTheme(.tokyoNight))
        case .catppuccin: TerminalPaletteVariants(appTheme: ResolvedAppTheme(.catppuccin))
        case .gruvbox: TerminalPaletteVariants(appTheme: ResolvedAppTheme(.gruvbox))
        case .dracula: .single(.dracula)
        case .nord: .single(.nord)
        }
    }
}
