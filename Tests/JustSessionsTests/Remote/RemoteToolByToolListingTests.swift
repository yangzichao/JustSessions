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

    /// Most copies find what the last one did; listing them again would sort and publish the whole list for nothing.
    @Test func aToolCopiedWithNoChangeIsNotListedAgain() throws {
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        let claude = Conversation.fixture(provider: .claude, title: "Claude", updatedAt: .now - 10, host: .ssh("devbox"))
        let codex = Conversation.fixture(provider: .codex, title: "Codex", updatedAt: .now - 20, host: .ssh("devbox"))
        let laterCodex = Conversation.fixture(provider: .codex, title: "Later Codex", host: .ssh("devbox"))
        let codexSubagent = Conversation.fixture(provider: .codex, title: "Helper", host: .ssh("devbox"), parentSessionID: codex.sessionID)
        store.replaceConversations(on: .ssh("devbox"), with: [claude, codex, laterCodex, codexSubagent])
        let changes = StoreChangeCounter(store)
        defer { changes.cancel() }
        let revision = store.conversationsRevision

        store.applyRemoteHostConversations([claude], of: Self.step(.claude), host: "devbox")
        store.applyRemoteHostConversations([codexSubagent, codex, laterCodex], of: Self.step(.codex), host: "devbox")
        for provider in [ConversationProvider.antigravity, .kiro, .opencode, .pi] {
            store.applyRemoteHostConversations([], of: Self.step(provider), host: "devbox")
        }
        #expect(changes.count == 0)
        #expect(store.conversationsRevision == revision)

        store.applyRemoteHostConversations([codex.withSuggestedTitle("Renamed"), laterCodex], of: Self.step(.codex), host: "devbox")
        #expect(changes.count > 0)
        #expect(store.conversations.map(\.suggestedTitle) == ["Later Codex", "Claude", "Renamed"])
        #expect(store.subagentConversations.isEmpty)
    }

    /// The tab's session was never listed, so no tool's copy changes anything; the last still gives it up.
    @Test func aWaitingTabIsGivenUpAfterTheLastToolEvenWhenNoCopyChangedAnything() throws {
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let listed = sandbox.conversation(title: "Listed", host: .ssh("devbox"))
        let gone = Conversation.fixture(provider: .pi, projectPath: "/srv/app", title: "Gone", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [listed])
        store.beginReopening([.session(gone)])

        for provider in ConversationProvider.allCases.dropLast() {
            store.applyRemoteHostConversations(provider == .claude ? [listed] : [], of: Self.step(provider), host: "devbox")
        }
        #expect(store.pendingTabReopening.waitingTabs.map(\.tab.conversationID) == [gone.id])

        store.applyRemoteHostConversations([], of: Self.step(ConversationProvider.allCases.last!), host: "devbox")
        #expect(store.pendingTabReopening.waitingTabs.isEmpty)
        #expect(store.conversations.map(\.id) == [listed.id])
    }

    private static func step(_ provider: ConversationProvider) -> RemoteSessionCopyStep {
        let providers = ConversationProvider.allCases
        return RemoteSessionCopyStep(provider: provider, number: providers.firstIndex(of: provider)! + 1, count: providers.count)
    }
}
