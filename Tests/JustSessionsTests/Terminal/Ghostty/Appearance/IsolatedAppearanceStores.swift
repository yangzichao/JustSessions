import GhosttyTerminal

@testable import JustSessions

@MainActor
struct IsolatedAppearanceStores {
    let settings: IsolatedUserDefaults
    let appearance: TerminalAppearanceStore
    let theme: AppThemeStore
    let optionKey: TerminalOptionKeyStore

    init() throws {
        settings = try IsolatedUserDefaults()
        appearance = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        theme = AppThemeStore(userDefaults: settings.userDefaults)
        optionKey = TerminalOptionKeyStore(userDefaults: settings.userDefaults)
    }

    func controller() -> TerminalController {
        GhosttyTerminalControllers.shared.controller(appearanceStore: appearance, themeStore: theme, optionKeyStore: optionKey)
    }

    func remove() {
        settings.removeSuite()
    }
}
