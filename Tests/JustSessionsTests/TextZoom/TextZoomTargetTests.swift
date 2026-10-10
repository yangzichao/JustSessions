import Testing
@testable import JustSessions

@MainActor
struct TextZoomTargetTests {
    @Test func terminalZoomChangesEveryTerminalsSavedFontSizeAndLeavesTheConversationSize() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)

        TextZoomTarget.terminals.zoom(.zoomIn, terminalAppearanceStore: store, userDefaults: settings.userDefaults)
        TextZoomTarget.terminals.zoom(.zoomIn, terminalAppearanceStore: store, userDefaults: settings.userDefaults)
        #expect(store.preferences.fontSize == 15)
        #expect(TerminalAppearanceStore(userDefaults: settings.userDefaults).preferences.fontSize == 15)
        #expect(settings.userDefaults.object(forKey: TranscriptReadingTextSize.userDefaultsKey) == nil)

        TextZoomTarget.terminals.zoom(.zoomOut, terminalAppearanceStore: store, userDefaults: settings.userDefaults)
        #expect(store.preferences.fontSize == 14)
        TextZoomTarget.terminals.zoom(.actualSize, terminalAppearanceStore: store, userDefaults: settings.userDefaults)
        #expect(store.preferences.fontSize == TerminalAppearancePreferences.defaultFontSize)
    }

    @Test func terminalZoomStopsAtTheSettingsSliderEnds() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)

        store.setFontSize(24)
        store.zoomFont(.zoomIn)
        #expect(store.preferences.fontSize == 24)
        store.setFontSize(10)
        store.zoomFont(.zoomOut)
        #expect(store.preferences.fontSize == 10)
    }

    @Test func conversationZoomChangesTheSharedReadingSizeAndLeavesTheTerminals() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)

        TextZoomTarget.conversation.zoom(.zoomIn, terminalAppearanceStore: store, userDefaults: settings.userDefaults)
        #expect(TranscriptReadingTextSize.saved(in: settings.userDefaults) == 16)
        #expect(store.preferences.fontSize == TerminalAppearancePreferences.defaultFontSize)

        TextZoomTarget.conversation.zoom(.actualSize, terminalAppearanceStore: store, userDefaults: settings.userDefaults)
        #expect(TranscriptReadingTextSize.saved(in: settings.userDefaults) == TranscriptReadingTextSize.defaultSize)
    }
}
