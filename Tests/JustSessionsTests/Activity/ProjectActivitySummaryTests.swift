import Foundation
import Testing
@testable import JustSessions

@MainActor
struct ProjectActivitySummaryTests {
    @Test func countsOnlyTheProjectsSessionsRunningInTmuxWithNoTab() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let working = Conversation.fixture(projectPath: "/tmp/justsessions-tests/app")
        let notRunning = Conversation.fixture(projectPath: "/tmp/justsessions-tests/app")
        let elsewhere = Conversation.fixture(projectPath: "/tmp/justsessions-tests/other")
        let store = ConversationStore(
            adapters: [],
            userDefaults: isolatedUserDefaults.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
        store.replaceConversations(on: .thisMac, with: [working, notRunning, elsewhere])
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(working), TmuxSessionName.forConversation(elsewhere)]
        store.detachedCLIActivities = [working.id: .working, elsewhere.id: .idle]

        #expect(store.activitySummary(forProjectDirectoryKey: working.projectDirectoryKey).summary == "1 working")
        #expect(store.activitySummary(forProjectDirectoryKey: elsewhere.projectDirectoryKey).summary == "1 idle")
        #expect(store.activitySummary(forProjectDirectoryKey: "/tmp/justsessions-tests/none").runningCount == 0)
    }
}
