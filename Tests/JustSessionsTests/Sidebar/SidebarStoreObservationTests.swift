import Combine
import Testing
@testable import JustSessions

@MainActor
struct SidebarStoreObservationTests {
    @Test func identicalRefreshAndTabSelectionDoNotPublishButChangedTitlesDo() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(), startsBackgroundPolling: false)
        let first = Conversation.fixture()
        let other = Conversation.fixture()
        store.replaceConversations(on: .thisMac, with: [first, other])
        var publications = 0
        let subscription = store.$conversations.dropFirst().sink { _ in publications += 1 }
        var selections = 0
        let selectionSubscription = store.$selectedTerminalID.dropFirst().sink { _ in selections += 1 }
        store.selectTerminal(nil)
        #expect(selections == 0)
        store.replaceConversations(on: .thisMac, with: [first, other])
        #expect(publications == 0)
        store.replaceConversations(on: .thisMac, with: [first.withSuggestedTitle("Changed"), other])
        #expect(publications == 1)
        withExtendedLifetime((subscription, selectionSubscription)) {}
    }
}
