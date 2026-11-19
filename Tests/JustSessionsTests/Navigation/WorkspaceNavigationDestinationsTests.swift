import Foundation
import Testing

@testable import JustSessions

/// Back and Forward go only to tabs still open in the window and sessions the sidebar lists, named by their titles.
/// Unstarted terminals and private settings; no CLI processes or real sessions are touched.
@MainActor
struct WorkspaceNavigationDestinationsTests {
    @Test func backPassesOverClosedTabsAndSessionsTheSearchHides() throws {
        let settings = try IsolatedUserDefaults()
        let store = makeStore(userDefaults: settings.userDefaults)
        defer {
            store.closeAllTerminals()
            settings.removeSuite()
        }
        let listed = Conversation.fixture(title: "Listed session")
        let hidden = Conversation.fixture(title: "Hidden by the search")
        store.replaceConversations(on: .thisMac, with: [listed, hidden])
        let openTab = makeTab(titled: "Open tab")
        let closedTab = makeTab(titled: "Closed tab")
        store.openTerminal(openTab)
        store.openTerminal(closedTab)
        store.closeTerminal(closedTab.id)
        let listedConversationIDs =
            store
            .filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "listed")
            .listedConversationIDs
        #expect(listedConversationIDs == [listed.id])

        var history = WorkspaceNavigationHistory()
        let shownBefore: [WorkspaceLocation] = [
            .conversation(listed.id), .conversation(hidden.id), .tab(openTab.id), .tab(closedTab.id), .conversation(listed.id),
        ]
        for location in shownBefore { history.record(location) }
        var wentTo: [WorkspaceLocation] = []
        let navigation = WorkspaceNavigation(
            history: history,
            shown: .conversation(listed.id),
            store: store,
            listedConversationIDs: listedConversationIDs,
            go: { wentTo.append($0.location) }
        )

        #expect(navigation.backDestinations.map(\.entryIndex) == [2])
        #expect(navigation.backDestinations.map(\.title) == ["Open tab"])
        #expect(!navigation.canGoForward)
        navigation.goBack()
        navigation.goForward()
        #expect(wentTo == [.tab(openTab.id)])
    }

    @Test func aSubagentsSessionCanShowThoughTheSidebarListsOnlyTheSessionThatStartedIt() throws {
        let settings = try IsolatedUserDefaults()
        let store = makeStore(userDefaults: settings.userDefaults)
        defer { settings.removeSuite() }
        let parent = Conversation.fixture(provider: .pi, title: "Parent")
        let subagent = Conversation.fixture(provider: .pi, title: "Subagent", parentSessionID: parent.sessionID)
        store.replaceConversations(on: .thisMac, with: [parent, subagent])

        #expect(store.canShow(.conversation(subagent.id), listedConversationIDs: [parent.id]))
        #expect(store.title(of: .conversation(subagent.id)) == "Subagent")
        #expect(!store.canShow(.conversation(parent.id), listedConversationIDs: []))
        #expect(store.title(of: .tab(UUID())) == nil)
    }

    @Test func onlyTheTwoTabsOfOneSplitShareTheScreen() throws {
        let settings = try IsolatedUserDefaults()
        let store = makeStore(userDefaults: settings.userDefaults)
        defer {
            store.closeAllTerminals()
            settings.removeSuite()
        }
        let left = makeTab(titled: "Left")
        let right = makeTab(titled: "Right")
        let other = makeTab(titled: "Other")
        for tab in [left, right, other] { store.openTerminal(tab) }
        store.selectTerminal(left.id)
        store.splitSelectedTerminal(with: right.id)

        #expect(store.areTabsOfOneSplit(.tab(left.id), .tab(right.id)))
        #expect(store.areTabsOfOneSplit(.tab(right.id), .tab(left.id)))
        #expect(!store.areTabsOfOneSplit(.tab(left.id), .tab(other.id)))
        #expect(!store.areTabsOfOneSplit(.tab(left.id), .tab(left.id)))
        #expect(!store.areTabsOfOneSplit(nil, .tab(right.id)))
        #expect(!store.areTabsOfOneSplit(.conversation("claude:c"), .tab(right.id)))
    }

    private func makeStore(userDefaults: UserDefaults) -> ConversationStore {
        ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [], inheritedEnvironment: [:]),
            userDefaults: userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
    }

    private func makeTab(titled title: String) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: nil,
            provider: .codex,
            projectPath: "/tmp",
            action: .resume,
            displayTitle: title,
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: [])
        )
    }
}
