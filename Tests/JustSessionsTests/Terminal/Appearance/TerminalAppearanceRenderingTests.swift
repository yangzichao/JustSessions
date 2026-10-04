import AppKit
import SwiftTerm
import Testing
@testable import JustSessions

@MainActor
struct TerminalAppearanceRenderingTests {
    @Test func changingThemeUpdatesEveryTerminalWithoutDiscardingOutputOrSelection() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        store.setMode(.light)
        let first = makeTerminal(store: store, themeStore: themeStore)
        let second = makeTerminal(store: store, themeStore: themeStore)
        let originalEngine = first.getTerminal()
        first.feed(text: "Existing output\r\n\u{1B}[38;2;12;34;56mRGB text\u{1B}[0m")
        first.selectAll()
        let selectedOutput = first.getSelection()
        let originalFont = first.font

        store.setMode(.dark)

        #expect(first.getTerminal() === originalEngine)
        #expect(first.font == originalFont)
        #expect(first.selectionActive)
        #expect(first.getSelection() == selectedOutput)
        #expect(first.getTerminal().getCharData(col: 0, row: 1)?.attribute.fg == .trueColor(red: 12, green: 34, blue: 56))
        for terminalView in [first, second, makeTerminal(store: store, themeStore: themeStore)] {
            #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsDark.contentSurface))
            #expect(terminalView.nativeForegroundColor == NSColor(hexValue: AppThemeColors.justSessionsDark.terminal.foreground))
            #expect(terminalView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        }
    }

    @Test func changingFontResizesExistingTerminalAndKeepsText() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let terminalView = makeTerminal(store: store, themeStore: AppThemeStore(userDefaults: settings.userDefaults))
        terminalView.feed(text: "Keep this output")
        let originalColumnCount = terminalView.getTerminal().cols

        store.setFontFamily(.menlo)
        store.setFontSize(22)

        #expect(terminalView.font.pointSize == 22)
        #expect(terminalView.font.fontName == "Menlo-Regular")
        #expect(terminalView.getTerminal().cols < originalColumnCount)
        terminalView.selectAll()
        #expect(terminalView.getSelection()?.contains("Keep this output") == true)
    }

    @Test func matchingTheAppRemovesOverrideAndRespondsToParentAppearance() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        parent.appearance = NSAppearance(named: .darkAqua)
        let terminalView = makeTerminal(store: store, themeStore: AppThemeStore(userDefaults: settings.userDefaults))
        parent.addSubview(terminalView)

        store.setMode(.light)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsLight.contentSurface))
        store.setMode(.matchApp)
        #expect(terminalView.appearance == nil)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsDark.contentSurface))

        parent.appearance = NSAppearance(named: .aqua)
        // Deliver AppKit's appearance callback explicitly because this view is not in an onscreen window.
        terminalView.viewDidChangeEffectiveAppearance()
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsLight.contentSurface))
    }

    @Test func choosingAThemeRestylesOpenTerminalsInItsLightOrDarkColors() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        store.setMode(.dark)
        let terminalView = makeTerminal(store: store, themeStore: themeStore)
        terminalView.feed(text: "Keep this output")

        themeStore.setTheme(.gruvbox)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.gruvboxDark.contentSurface))
        #expect(terminalView.nativeForegroundColor == NSColor(hexValue: AppThemeColors.gruvboxDark.terminal.foreground))
        #expect(terminalView.selectedTextBackgroundColor == NSColor(hexValue: AppThemeColors.gruvboxDark.terminal.selectionBackground))

        store.setMode(.light)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.gruvboxLight.contentSurface))
        #expect(terminalView.nativeForegroundColor == NSColor(hexValue: AppThemeColors.gruvboxLight.terminal.foreground))
        terminalView.selectAll()
        #expect(terminalView.getSelection()?.contains("Keep this output") == true)
    }

    @Test func aPresetGivesTerminalsItsOwnColorsWhateverTheAppTheme() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        store.setMode(.light)
        let terminalView = makeTerminal(store: store, themeStore: themeStore)
        terminalView.feed(text: "Keep this output")

        store.setColorChoice(.preset(.gitHub))
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.gitHubLight.contentSurface))
        themeStore.setTheme(.gruvbox)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.gitHubLight.contentSurface))

        store.setMode(.dark)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.gitHubDark.contentSurface))
        #expect(terminalView.nativeForegroundColor == NSColor(hexValue: AppThemeColors.gitHubDark.terminal.foreground))
        #expect(terminalView.selectedTextBackgroundColor == NSColor(hexValue: AppThemeColors.gitHubDark.terminal.selectionBackground))
        terminalView.selectAll()
        #expect(terminalView.getSelection()?.contains("Keep this output") == true)
    }

    @Test func aSchemeWithOnlyADarkVersionKeepsTheTerminalDarkWhenLightIsSet() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        store.setMode(.light)
        store.setColorChoice(.preset(.dracula))
        let terminalView = makeTerminal(store: store, themeStore: AppThemeStore(userDefaults: settings.userDefaults))

        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: TerminalPalette.dracula.background))
        #expect(terminalView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)

        store.setColorChoice(.matchAppTheme)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsLight.contentSurface))
        #expect(terminalView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)
    }

    private func makeTerminal(store: TerminalAppearanceStore, themeStore: AppThemeStore) -> SelectableTerminalView {
        SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), appearanceStore: store, themeStore: themeStore)
    }
}
