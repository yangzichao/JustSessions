import AppKit
import Testing
@testable import JustSessions

/// A terminal tells its tab when its colors turn light or dark and no program in it subscribes to hear about it.
@MainActor
struct UnheardLightDarkChangeTests {
    @Test func passesOnEachLightDarkChangeNoProgramHears() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let (appearanceStore, themeStore, terminalView) = makeTerminal(settings: settings)
        var changeCount = 0
        terminalView.onUnheardLightDarkChange = { changeCount += 1 }

        appearanceStore.setMode(.dark)
        #expect(changeCount == 1)
        // Another dark theme leaves the terminal dark.
        themeStore.setTheme(.tokyoNight)
        #expect(changeCount == 1)
        appearanceStore.setMode(.light)
        #expect(changeCount == 2)
    }

    @Test func aSubscribedProgramHearsTheChangeItself() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let (appearanceStore, _, terminalView) = makeTerminal(settings: settings)
        var changeCount = 0
        terminalView.onUnheardLightDarkChange = { changeCount += 1 }

        terminalView.dataReceived(slice: Array("\u{1B}[?2031h".utf8)[...])
        appearanceStore.setMode(.dark)

        #expect(changeCount == 0)
    }

    private func makeTerminal(
        settings: IsolatedUserDefaults
    ) -> (TerminalAppearanceStore, AppThemeStore, SelectableTerminalView) {
        let appearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        appearanceStore.setMode(.light)
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 400), appearanceStore: appearanceStore, themeStore: themeStore
        )
        return (appearanceStore, themeStore, terminalView)
    }
}
