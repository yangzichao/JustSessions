import Foundation
import Testing
@testable import JustSessions

/// A refresh lists each tool's sessions on an SSH host as soon as that tool is copied, keeps the host's other tools'
/// sessions meanwhile, and gives up a tab waiting to reopen only once every tool is listed.
@MainActor
struct RemoteToolByToolListingTests {
    @Test func eachToolReplacesOnlyItsOwnSessions() throws {
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        let oldClaude = Conversation.fixture(provider: .claude, title: "Old Claude", host: .ssh("devbox"))
        let codex = Conversation.fixture(provider: .codex, title: "Codex", host: .ssh("devbox"))
        let newClaude = Conversation.fixture(provider: .claude, title: "New Claude", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [oldClaude, codex])

        store.applyRemoteHostConversations([newClaude], of: Self.step(.claude), host: "devbox")

        #expect(Set(store.conversations.map(\.id)) == [newClaude.id, codex.id])
    }

    /// The sandbox's store launches only Claude Code, so the tab that reopens is one; the Pi session is gone.
    @Test func aWaitingTabReopensOnceItsToolIsListedAndIsGivenUpOnlyAfterTheLastTool() throws {
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let local = sandbox.conversation(title: "Local")
        let remote = sandbox.conversation(title: "Remote", host: .ssh("devbox"))
        let gone = Conversation.fixture(provider: .pi, projectPath: "/srv/app", title: "Gone", host: .ssh("devbox"))
        store.beginReopening([.session(local, wasSelected: true), .session(remote), .session(gone)])
        store.replaceConversations(on: .thisMac, with: [local])
        #expect(store.pendingTabReopening.waitingTabs.count == 2)

        store.applyRemoteHostConversations([remote], of: Self.step(.claude), host: "devbox")
        #expect(store.terminalSessions.map(\.displayTitle) == ["Local", "Remote"])
        #expect(store.pendingTabReopening.waitingTabs.map(\.tab.conversationID) == [gone.id])

        for provider in [ConversationProvider.codex, .antigravity, .kiro, .opencode] {
            store.applyRemoteHostConversations([], of: Self.step(provider), host: "devbox")
        }
        #expect(store.pendingTabReopening.waitingTabs.map(\.tab.conversationID) == [gone.id])

        store.applyRemoteHostConversations([], of: Self.step(.pi), host: "devbox")
        #expect(store.pendingTabReopening.waitingTabs.isEmpty)
        #expect(store.terminalSessions.map(\.displayTitle) == ["Local", "Remote"])
    }

    private static func step(_ provider: ConversationProvider) -> RemoteSessionCopyStep {
        let providers = ConversationProvider.allCases
        return RemoteSessionCopyStep(provider: provider, number: providers.firstIndex(of: provider)! + 1, count: providers.count)
    }
}
