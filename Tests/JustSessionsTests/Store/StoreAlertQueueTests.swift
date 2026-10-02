import Testing
@testable import JustSessions

/// The store shows one alert at a time; one that comes meanwhile waits, and dismissing an alert never dismisses
/// a newer one.
@MainActor
struct StoreAlertQueueTests {
    @Test func anAlertThatComesWhileOneIsShownWaitsForIt() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = makeStore(isolatedUserDefaults)

        store.showError("First")
        store.showError("Second")
        #expect(store.alert?.message == "First")

        store.dismissError()
        #expect(store.alert?.message == "Second")
        store.dismissError()
        #expect(store.alert == nil)
    }

    /// As when an alert's closing reports after a newer alert was set.
    @Test func dismissingAnAlertThatAlreadyWentLeavesTheNewerOne() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = makeStore(isolatedUserDefaults)

        store.showError("First")
        let first = try #require(store.alert)
        store.dismissAlert(first)
        store.showError("Second")
        store.dismissAlert(first)

        #expect(store.alert?.message == "Second")
    }

    private func makeStore(_ isolatedUserDefaults: IsolatedUserDefaults) -> ConversationStore {
        ConversationStore(
            adapters: [],
            userDefaults: isolatedUserDefaults.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
    }
}
