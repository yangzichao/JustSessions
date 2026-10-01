import Foundation
import Testing
@testable import JustSessions

/// Kiro CLI, OpenCode, and Pi say nothing about the session a new tab starts, so on this Mac its tab takes the first
/// session that appears in its project after it started.
@MainActor
struct ThisMacAppearingSessionTests {
    @Test(arguments: [ConversationProvider.kiro, .opencode, .pi])
    func newTabLinksToTheSessionThatAppearsInItsProject(provider: ConversationProvider) throws {
        let store = ConversationStore(adapters: [])
        let existing = conversation(provider, project: "/Users/me/app", updatedAt: .now.addingTimeInterval(-3_600))
        store.replaceConversations(on: .thisMac, with: [existing])
        let tab = newSessionTab(provider, project: "/Users/me/app", store: store)
        store.openTerminal(tab)
        #expect(tab.isWaitingForAppearingSession)
        #expect(tab.sessionIDsKnownAtLaunch == [existing.sessionID])

        let notListedYetButOlder = conversation(provider, project: "/Users/me/app", updatedAt: tab.launchedAt.addingTimeInterval(-60))
        let otherProject = conversation(provider, project: "/Users/me/api", updatedAt: .now)
        store.replaceConversations(on: .thisMac, with: [existing, notListedYetButOlder, otherProject])
        store.linkWaitingTabsByAppearance(on: .thisMac)
        #expect(tab.conversation == nil)

        let created = conversation(provider, project: "/Users/me/app", updatedAt: .now)
        store.replaceConversations(on: .thisMac, with: [existing, notListedYetButOlder, otherProject, created])
        store.linkWaitingTabsByAppearance(on: .thisMac)
        #expect(tab.conversation?.id == created.id)
        store.closeAllTerminals()
    }

    @Test func toolsThatNameTheirSessionDoNotLinkByAppearance() {
        let store = ConversationStore(adapters: [])
        store.replaceConversations(on: .thisMac, with: [conversation(.codex, project: "/Users/me/app", updatedAt: .now)])
        let tab = newSessionTab(.codex, project: "/Users/me/app", store: store)

        #expect(!tab.isWaitingForAppearingSession)
        #expect(tab.sessionIDsKnownAtLaunch.isEmpty)
    }

    private func newSessionTab(_ provider: ConversationProvider, project: String, store: ConversationStore) -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: provider,
            projectPath: project,
            action: .new,
            displayTitle: provider.newSessionTabTitle,
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            sessionIDsKnownAtLaunch: store.sessionIDsKnownAtLaunch(of: provider, on: .thisMac)
        )
    }

    private func conversation(_ provider: ConversationProvider, project: String, updatedAt: Date) -> Conversation {
        Conversation.fixture(
            provider: provider,
            sessionID: provider == .opencode ? "ses_" + UUID().uuidString.replacingOccurrences(of: "-", with: "") : UUID().uuidString,
            projectPath: project,
            updatedAt: updatedAt
        )
    }
}
