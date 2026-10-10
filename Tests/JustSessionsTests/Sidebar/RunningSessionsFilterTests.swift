import Foundation
import Testing
@testable import JustSessions

/// The Running filter lists sessions whose CLI runs in tmux with no tab open, on this Mac and on SSH hosts alike,
/// as the hosts' last refresh listed them.
@MainActor
struct RunningSessionsFilterTests {
    @Test func listsSessionsRunningInTmuxOnThisMacAndOnSSHHosts() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let running = Conversation.fixture(provider: .claude, title: "Running here")
        let ended = Conversation.fixture(provider: .claude, title: "Ended here")
        let runningOnDevbox = Conversation.fixture(provider: .codex, title: "Running on devbox", host: .ssh("devbox"))
        let endedOnDevbox = Conversation.fixture(provider: .codex, title: "Ended on devbox", host: .ssh("devbox"))
        let store = ConversationStore(
            adapters: [],
            userDefaults: isolatedUserDefaults.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
        store.remoteHostList = RemoteHostList(hosts: ["devbox"])
        store.replaceConversations(on: .thisMac, with: [running, ended])
        store.replaceConversations(on: .ssh("devbox"), with: [runningOnDevbox, endedOnDevbox])
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(running)]
        // The same session id on the host is another session, and a new session's temporary name names none yet.
        store.tmuxSessionNamesByHost[.ssh("devbox")] = [
            TmuxSessionName.forConversation(runningOnDevbox),
            TmuxSessionName.forSession(provider: .claude, sessionID: running.sessionID),
            TmuxSessionName.unique(for: .codex),
        ]

        let expectedRunningIDs: Set<String> = [
            running.id, runningOnDevbox.id, Conversation.id(provider: .claude, sessionID: running.sessionID, host: .ssh("devbox")),
        ]
        #expect(store.sessionsRunning == SessionsRunning(conversationIDs: expectedRunningIDs))
        let runningOnly = store.filteredSidebarProjection(
            providerFilter: .all, recencyFilter: .all, statusFilter: .running, searchText: ""
        )
        #expect(Set(runningOnly.projects.flatMap(\.conversations).map(\.id)) == [running.id, runningOnDevbox.id])
        // The count is of listed sessions, so the host's session this Mac does not list is left out.
        #expect(runningOnly.runningSessionCount == 2)
        #expect(runningOnly.allSessionCount == 4)
        let codexOnly = store.filteredSidebarProjection(
            providerFilter: .only(.codex), recencyFilter: .all, statusFilter: .running, searchText: ""
        )
        #expect(codexOnly.runningSessionCount == 1)

        // The host's next refresh lists the CLI as ended, and the session leaves the filter.
        store.setTmuxSessionNames([], on: .ssh("devbox"))
        let afterRefresh = store.filteredSidebarProjection(
            providerFilter: .all, recencyFilter: .all, statusFilter: .running, searchText: ""
        )
        #expect(afterRefresh.projects.flatMap(\.conversations).map(\.id) == [running.id])
        #expect(afterRefresh.runningSessionCount == 1)
    }
}
