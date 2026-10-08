import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TabCloseChoiceSettingsStoreTests {
    @Test func asksEachTimeUntilAChoiceIsSaved() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        let store = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(store.choice == .askEachTime)
        #expect(store.choice.endsTmuxSessionWithoutAsking == nil)

        store.setChoice(.keepRunning)
        let reopenedStore = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(reopenedStore.choice == .keepRunning)
        #expect(reopenedStore.choice.endsTmuxSessionWithoutAsking == false)

        reopenedStore.setChoice(.endSession)
        #expect(TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults).choice.endsTmuxSessionWithoutAsking == true)
    }

    @Test func anUnknownSavedChoiceAsksEachTime() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        settings.userDefaults.set("closeQuietly", forKey: TabCloseChoiceSettingsStore.userDefaultsKey)
        #expect(TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults).choice == .askEachTime)
    }
}
