import Foundation
import Testing
@testable import JustSessions

@MainActor
struct AppThemeStoreTests {
    @Test func chosenThemeSurvivesReopening() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        #expect(store.theme == .justSessions)

        store.setTheme(.tokyoNight)

        #expect(store.theme == .tokyoNight)
        #expect(AppThemeStore(userDefaults: settings.userDefaults).theme == .tokyoNight)
    }

    @Test func unknownSavedThemeFallsBackToJustSessions() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set("dracula", forKey: AppTheme.userDefaultsKey)

        #expect(AppThemeStore(userDefaults: settings.userDefaults).theme == .justSessions)
    }
}
