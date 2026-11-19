import Testing

@testable import JustSessions

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
