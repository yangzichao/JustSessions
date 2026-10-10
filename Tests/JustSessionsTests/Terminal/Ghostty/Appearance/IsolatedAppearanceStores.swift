import GhosttyTerminal
@testable import JustSessions

/// Appearance and theme stores on their own settings, and the Ghostty controller that follows them.
@MainActor
struct IsolatedAppearanceStores {
    let settings: IsolatedUserDefaults
    let appearance: TerminalAppearanceStore
    let theme: AppThemeStore

    init() throws {
        settings = try IsolatedUserDefaults()
        appearance = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        theme = AppThemeStore(userDefaults: settings.userDefaults)
    }

    func controller() -> TerminalController {
        GhosttyTerminalControllers.shared.controller(appearanceStore: appearance, themeStore: theme)
    }

    func remove() {
        settings.removeSuite()
    }
}
