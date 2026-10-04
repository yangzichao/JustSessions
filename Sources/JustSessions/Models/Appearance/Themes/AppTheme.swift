import Foundation

/// A named set of colors for the whole app, terminals included. Each theme has a light and a dark version, and the
/// Appearance setting picks between them.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case justSessions
    case gitHub
    case atomOne
    case tokyoNight
    case catppuccin
    case gruvbox

    static let userDefaultsKey = "appTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justSessions: "JustSessions"
        case .gitHub: "GitHub"
        case .atomOne: "Atom One"
        case .tokyoNight: "Tokyo Night"
        case .catppuccin: "Catppuccin"
        case .gruvbox: "Gruvbox"
        }
    }

    func colors(isDark: Bool) -> AppThemeColors {
        switch self {
        case .justSessions: isDark ? .justSessionsDark : .justSessionsLight
        case .gitHub: isDark ? .gitHubDark : .gitHubLight
        case .atomOne: isDark ? .atomOneDark : .atomOneLight
        case .tokyoNight: isDark ? .tokyoNightNight : .tokyoNightDay
        case .catppuccin: isDark ? .catppuccinMocha : .catppuccinLatte
        case .gruvbox: isDark ? .gruvboxDark : .gruvboxLight
        }
    }

    /// The saved theme, or JustSessions when nothing is saved or the saved value is not a theme.
    static func load(from userDefaults: UserDefaults) -> Self {
        userDefaults.string(forKey: userDefaultsKey).flatMap(Self.init(rawValue:)) ?? .justSessions
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(rawValue, forKey: Self.userDefaultsKey)
    }
}
