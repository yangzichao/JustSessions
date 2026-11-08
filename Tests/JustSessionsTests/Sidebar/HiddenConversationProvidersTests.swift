import Foundation
import Testing
@testable import JustSessions

/// A CLI unticked under **Show sessions from** in Settings → General is treated as not installed: its sessions leave
/// the sidebar, its counts, search, and filter menu, and New session stops offering it, in every window.
@MainActor
struct HiddenConversationProvidersTests {
    @Test func aHiddenCLIsSessionsLeaveTheSidebarAndComeBackWhenShownAgain() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        let claudeSession = Conversation.fixture(provider: .claude, projectPath: "/work/app", updatedAt: .now)
        let kiroSession = Conversation.fixture(provider: .kiro, projectPath: "/work/app", updatedAt: .now - 10)
        let kiroOnlySession = Conversation.fixture(provider: .kiro, projectPath: "/work/kiro-only", updatedAt: .now - 20)
        store.replaceConversations(on: .thisMac, with: [claudeSession, kiroSession, kiroOnlySession])
        #expect(store.sidebarProjectGroups.map(\.projectPath) == ["/work/app", "/work/kiro-only"])

        store.setHidden(true, provider: .kiro)

        #expect(store.sidebarConversations.map(\.id) == [claudeSession.id])
        // The project only Kiro CLI worked in leaves too, rather than staying as an empty project.
        #expect(store.sidebarProjectGroups.map(\.projectPath) == ["/work/app"])
        #expect(store.sidebarProjectGroups.first?.conversations.map(\.id) == [claudeSession.id])
        let filtered = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "")
        #expect(filtered.allSessionCount == 1)
        #expect(filtered.listedConversationIDs == [claudeSession.id])
        #expect(!store.filterableProviders.contains(.kiro))
        // The session itself is still known, so an open tab on it keeps its title and link.
        #expect(store.conversation(withID: kiroSession.id)?.id == kiroSession.id)

        store.setHidden(false, provider: .kiro)

        #expect(store.sidebarConversations.map(\.id) == [claudeSession.id, kiroSession.id, kiroOnlySession.id])
        #expect(store.sidebarProjectGroups.map(\.projectPath) == ["/work/app", "/work/kiro-only"])
        #expect(store.filterableProviders.contains(.kiro))
    }

    @Test func aProjectWithNoSessionsStaysListedWhileACLIIsHidden() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.showProjectInSidebar("/work/empty")

        store.setHidden(true, provider: .codex)

        #expect(store.sidebarProjectGroups.map(\.projectPath) == ["/work/empty"])
    }

    @Test func newSessionsNeverOfferAHiddenCLI() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.setHidden(true, provider: .kiro)

        #expect(store.newSessionProviders(on: .thisMac) == ConversationProvider.allCases.filter { $0 != .kiro })

        store.setInstalledProviders([.claude, .kiro], on: .thisMac)

        #expect(store.newSessionProviders(on: .thisMac) == [.claude])
        #expect(store.newSessionProvidersByHost == [.thisMac: [.claude]])
        #expect(store.filterableProviders == [.claude])
    }

    @Test func hidingACLIIsSavedAndShowsInEveryWindow() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let registry = WorkspaceWindowRegistry()
        let firstWindow = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, windowRegistry: registry, startsBackgroundPolling: false
        )
        let secondWindow = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, windowRegistry: registry, startsBackgroundPolling: false
        )

        firstWindow.setHidden(true, provider: .opencode)

        #expect(secondWindow.hiddenConversationProviders.providers == [.opencode])
        let reopened = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        #expect(reopened.hiddenConversationProviders.providers == [.opencode])
    }

    @Test func savedNamesAreSortedAndUnknownOnesAreDropped() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        HiddenConversationProviders(providers: [.pi, .codex]).save(to: settings.userDefaults)
        #expect(settings.userDefaults.stringArray(forKey: HiddenConversationProviders.userDefaultsKey) == ["Codex", "Pi"])

        settings.userDefaults.set(["Pi", "Some Future CLI"], forKey: HiddenConversationProviders.userDefaultsKey)

        #expect(HiddenConversationProviders.load(from: settings.userDefaults).providers == [.pi])
    }

    @Test func aHiddenCLIInTmuxWithNoTabDoesNotNotify() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let notifier = RecordingSessionNotifier()
        let store = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, sessionNotifier: notifier, startsBackgroundPolling: false
        )
        let kiroSession = Conversation.fixture(provider: .kiro, projectPath: "/work/app")
        store.replaceConversations(on: .thisMac, with: [kiroSession])
        let event = SessionAttentionEvent(source: .detachedTmux(conversationID: kiroSession.id), reason: .finishedTurn)
        store.notifyOfSessionsWantingAttention([event])
        #expect(notifier.notifications.count == 1)

        store.setHidden(true, provider: .kiro)
        store.notifyOfSessionsWantingAttention([event])

        #expect(notifier.notifications.count == 1)
    }
}
