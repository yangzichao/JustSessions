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
        store.setFontFamily(.named("Menlo"))
        store.setFontSize(19)

        let reopened = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        #expect(reopened.preferences == TerminalAppearancePreferences(mode: .dark, fontFamily: .named("Menlo"), fontSize: 19))

        reopened.restoreDefaults()
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences())
    }

    @Test func colorChoiceAndImportedColorsSurviveReopeningAndRestoreDefaultsClearsThem() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let importedColors = ImportedTerminalColors(sourceName: "iTerm2 · Work", variants: .single(.nord))
        store.useImportedColors(importedColors)
        #expect(store.preferences.colorChoice == .imported)
        store.setColorChoice(.preset(.dracula))

        let reopened = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        #expect(reopened.preferences.colorChoice == .preset(.dracula))
        #expect(reopened.preferences.importedColors == importedColors)
        reopened.setColorChoice(.imported)
        #expect(reopened.preferences.colorVariants(appTheme: ResolvedAppTheme(.justSessions)) == .single(.nord))

        reopened.restoreDefaults()
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences())
    }

    @Test func anUnknownSchemeOrMissingImportedColorsFallBackToTheAppTheme() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let key = TerminalAppearancePreferences.userDefaultsKey

        settings.userDefaults.set(Data(#"{"colorChoice":"monokai","mode":"dark"}"#.utf8), forKey: key)
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences(mode: .dark))

        settings.userDefaults.set(Data(#"{"colorChoice":"imported","fontSize":18}"#.utf8), forKey: key)
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences(fontSize: 18))
    }

    @Test func invalidSavedSettingsFallBackAndOversizedFontsAreClamped() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(Data("invalid".utf8), forKey: TerminalAppearancePreferences.userDefaultsKey)
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences())

        let oversized = TerminalAppearancePreferences(mode: .light, fontFamily: .named("Monaco"), fontSize: 500)
        settings.userDefaults.set(try JSONEncoder().encode(oversized), forKey: TerminalAppearancePreferences.userDefaultsKey)
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        #expect(store.preferences.fontSize == 24)
        #expect(store.preferences.mode == .light)
        store.setFontSize(.nan)
        #expect(store.preferences.fontSize == 13)
        store.setFontSize(-1)
        #expect(store.preferences.fontSize == 10)
    }

    @Test func aSavedValueThisVersionDoesNotKnowResetsOnlyThatSetting() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let key = TerminalAppearancePreferences.userDefaultsKey

        settings.userDefaults.set(Data(#"{"mode":"sepia","fontFamily":"menlo","fontSize":18}"#.utf8), forKey: key)
        #expect(TerminalAppearanceStore(userDefaults: settings.userDefaults).preferences
            == TerminalAppearancePreferences(mode: .matchApp, fontFamily: .named("Menlo"), fontSize: 18))

        settings.userDefaults.set(Data(#"{"mode":"dark","fontSize":"large"}"#.utf8), forKey: key)
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults) == TerminalAppearancePreferences(mode: .dark))
    }
}
