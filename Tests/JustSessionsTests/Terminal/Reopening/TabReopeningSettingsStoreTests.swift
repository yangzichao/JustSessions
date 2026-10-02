import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TabReopeningSettingsStoreTests {
    @Test func reopensTabsUntilTurnedOff() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        let store = TabReopeningSettingsStore(userDefaults: settings.userDefaults)
        #expect(store.reopensTabsAtLaunch)

        store.setReopensTabsAtLaunch(false)
        #expect(!TabReopeningSettingsStore(userDefaults: settings.userDefaults).reopensTabsAtLaunch)
    }
}
