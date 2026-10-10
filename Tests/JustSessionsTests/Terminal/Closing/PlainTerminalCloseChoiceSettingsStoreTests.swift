import Foundation
import Testing
@testable import JustSessions

@MainActor
struct PlainTerminalCloseChoiceSettingsStoreTests {
    @Test func asksEachTimeUntilClosingWithoutAskingIsSaved() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        let store = PlainTerminalCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(store.choice == .askEachTime)

        store.setChoice(.closeWithoutAsking)
        let reopenedStore = PlainTerminalCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(reopenedStore.choice == .closeWithoutAsking)

        reopenedStore.setChoice(.askEachTime)
        #expect(PlainTerminalCloseChoiceSettingsStore(userDefaults: settings.userDefaults).choice == .askEachTime)
    }

    @Test func anUnknownSavedChoiceAsksEachTime() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        settings.userDefaults.set("keepRunning", forKey: PlainTerminalCloseChoiceSettingsStore.userDefaultsKey)
        #expect(PlainTerminalCloseChoiceSettingsStore(userDefaults: settings.userDefaults).choice == .askEachTime)
    }
}
