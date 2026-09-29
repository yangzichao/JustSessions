import Foundation

/// A named set of colors for the whole app, terminals included. Each theme has a light and a dark version, and the
/// Appearance setting picks between them.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case justSessions
    case solarized
    case gruvbox
    case catppuccin
    case tokyoNight
    case rosePine

    static let userDefaultsKey = "appTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justSessions: "JustSessions"
        case .solarized: "Solarized"
        case .gruvbox: "Gruvbox"
        case .catppuccin: "Catppuccin"
        case .tokyoNight: "Tokyo Night"
        case .rosePine: "Rosé Pine"
        }
    }

    func colors(isDark: Bool) -> AppThemeColors {
        switch self {
        case .justSessions: isDark ? .justSessionsDark : .justSessionsLight
        case .solarized: isDark ? .solarizedDark : .solarizedLight
        case .gruvbox: isDark ? .gruvboxDark : .gruvboxLight
        case .catppuccin: isDark ? .catppuccinMocha : .catppuccinLatte
        case .tokyoNight: isDark ? .tokyoNightNight : .tokyoNightDay
        case .rosePine: isDark ? .rosePineMain : .rosePineDawn
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
