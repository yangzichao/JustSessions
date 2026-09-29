import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TerminalAppearancePreferencesTests {
    @Test func settingsSurviveReopeningAndRestoreDefaultsPersists() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        store.setMode(.dark)
        store.setFontFamily(.menlo)
        store.setFontSize(19)

        let reopened = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        #expect(reopened.preferences == TerminalAppearancePreferences(mode: .dark, fontFamily: .menlo, fontSize: 19))

        reopened.restoreDefaults()
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences())
    }

    @Test func invalidSavedSettingsFallBackAndOversizedFontsAreClamped() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(Data("invalid".utf8), forKey: TerminalAppearancePreferences.userDefaultsKey)
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences())

        let oversized = TerminalAppearancePreferences(mode: .light, fontFamily: .monaco, fontSize: 500)
        settings.userDefaults.set(try JSONEncoder().encode(oversized), forKey: TerminalAppearancePreferences.userDefaultsKey)
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        #expect(store.preferences.fontSize == 24)
        #expect(store.preferences.mode == .light)
        store.setFontSize(.nan)
        #expect(store.preferences.fontSize == 13)
        store.setFontSize(-1)
        #expect(store.preferences.fontSize == 10)
    }
}
