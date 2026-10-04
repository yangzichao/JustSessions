import Foundation
import Testing
@testable import JustSessions

@MainActor
struct AppThemeChooserTests {
    @Test func choosingAThemeGivesTerminalsItsColorsAndKeepsTheRestOfTheirSettings() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let appThemeStore = AppThemeStore(userDefaults: settings.userDefaults)
        let terminalAppearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let importedColors = ImportedTerminalColors(sourceName: "iTerm2 · Work", variants: .single(.nord))
        terminalAppearanceStore.useImportedColors(importedColors)
        terminalAppearanceStore.setColorChoice(.preset(.dracula))
        terminalAppearanceStore.setMode(.dark)
        terminalAppearanceStore.setFontSize(16)

        AppThemeChooser(appThemeStore: appThemeStore, terminalAppearanceStore: terminalAppearanceStore).choose(.gitHub)

        #expect(appThemeStore.theme == .gitHub)
        let preferences = terminalAppearanceStore.preferences
        #expect(preferences.colorChoice == .matchAppTheme)
        #expect(preferences.colorVariants(appTheme: appThemeStore.theme) == TerminalPaletteVariants(appTheme: .gitHub))
        #expect(preferences.importedColors == importedColors)
        #expect(preferences.mode == .dark)
        #expect(preferences.fontSize == 16)
    }

    @Test func choosingTheCurrentThemeAgainBringsBackItsTerminalColors() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let appThemeStore = AppThemeStore(userDefaults: settings.userDefaults)
        let terminalAppearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        terminalAppearanceStore.setColorChoice(.preset(.nord))

        AppThemeChooser(appThemeStore: appThemeStore, terminalAppearanceStore: terminalAppearanceStore).choose(appThemeStore.theme)

        #expect(terminalAppearanceStore.preferences.colorChoice == .matchAppTheme)
    }
}
