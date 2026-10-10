import Combine
import GhosttyTerminal

/// The Ghostty controller a tab's Ghostty terminal draws with. Ghostty keeps its configuration on a controller and
/// applies it to every terminal on it, so terminals that follow the same appearance settings share one controller.
/// A controller also has one light or dark color scheme, which the last of its terminals to change appearance sets,
/// so every terminal view on a controller must present the same light or dark appearance.
@MainActor
final class GhosttyTerminalControllers {
    static let shared = GhosttyTerminalControllers()

    private var followers: [AppearanceFollower] = []

    /// The controller whose configuration follows these stores' terminal appearance and app theme.
    func controller(appearanceStore: TerminalAppearanceStore, themeStore: AppThemeStore) -> TerminalController {
        followers.removeAll { $0.appearanceStore == nil || $0.themeStore == nil }
        if let follower = followers.first(where: { $0.appearanceStore === appearanceStore && $0.themeStore === themeStore }) {
            return follower.controller
        }
        let follower = AppearanceFollower(appearanceStore: appearanceStore, themeStore: themeStore)
        followers.append(follower)
        return follower.controller
    }
}

/// A controller that takes on the stores' appearance settings now and whenever they change. It holds the stores weakly,
/// so the controllers of stores that are gone can be let go.
@MainActor
private final class AppearanceFollower {
    weak var appearanceStore: TerminalAppearanceStore?
    weak var themeStore: AppThemeStore?
    let controller: TerminalController
    private var subscription: AnyCancellable?

    init(appearanceStore: TerminalAppearanceStore, themeStore: AppThemeStore) {
        self.appearanceStore = appearanceStore
        self.themeStore = themeStore
        let configuration = GhosttyAppearanceConfiguration(preferences: appearanceStore.preferences, appTheme: themeStore.terminalTheme)
        // A base of only a comment rather than libghostty-spm's default configuration, which thickens the font and
        // would sit under every reload. Ghostty logs an error for an empty file. The theme replaces libghostty-spm's
        // default theme, which would otherwise override the colors.
        controller = TerminalController(
            configSource: .generated(Self.baseConfiguration),
            theme: configuration.theme,
            terminalConfiguration: configuration.terminalConfiguration
        )
        // The stores publish before their values change, so take the values from the publishers.
        subscription = appearanceStore.$preferences.combineLatest(themeStore.$terminalTheme)
            .dropFirst()
            .sink { [controller] preferences, appTheme in
                // Each reloads and redraws every terminal on the controller, and does nothing for an unchanged value.
                let configuration = GhosttyAppearanceConfiguration(preferences: preferences, appTheme: appTheme)
                controller.setTerminalConfiguration(configuration.terminalConfiguration)
                controller.setTheme(configuration.theme)
            }
    }

    private static let baseConfiguration = "# JustSessions terminal appearance"
}
