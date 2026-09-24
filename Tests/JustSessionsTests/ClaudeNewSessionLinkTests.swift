import Foundation
import Testing
@testable import JustSessions

@MainActor
struct ClaudeNewSessionLinkTests {
    private static let discoveredSessionID = "44444444-4444-4444-8444-444444444444"
    private static let undiscoveredSessionID = "55555555-5555-4555-8555-555555555555"

    @Test func newTabLinksToItsConversationOnceDiscovered() async throws {
        let store = try await makeStore(discovering: [Self.conversation(sessionID: Self.discoveredSessionID)])
        let session = makeNewSession()

        let didLink = store.linkNewSession(session, toClaudeRecord: Self.record(sessionID: Self.discoveredSessionID))

        #expect(didLink)
        #expect(session.conversation?.sessionID == Self.discoveredSessionID)
        #expect(session.displayTitle == "First prompt")
    }

    @Test func newTabStaysUnlinkedWhileItsSessionIsNotDiscoveredYet() async throws {
        let store = try await makeStore(discovering: [Self.conversation(sessionID: Self.discoveredSessionID)])
        let session = makeNewSession()

        let didLink = store.linkNewSession(session, toClaudeRecord: Self.record(sessionID: Self.undiscoveredSessionID))

        #expect(!didLink)
        #expect(session.conversation == nil)
        #expect(session.displayTitle == "New Claude Code session")
    }

    private func makeStore(discovering conversations: [Conversation]) async throws -> ConversationStore {
        let store = ConversationStore(adapters: [StaticConversationAdapter(discoveredConversations: conversations)])
        store.refresh()
        for _ in 0..<100 where store.isLoading || store.conversations.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.conversations.count == conversations.count)
        return store
    }

    private func makeNewSession() -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: .claude,
            projectPath: "/tmp/new-session-link-project",
            action: .new,
            displayTitle: "New Claude Code session",
            command: NativeCLICommand(
                executablePath: "/usr/bin/true",
                arguments: [],
                workingDirectory: "/tmp/new-session-link-project",
                environment: []
            )
        )
    }

    private static func conversation(sessionID: String) -> Conversation {
        Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: "/tmp/new-session-link-project",
            suggestedTitle: "First prompt",
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/new-session-link-project/\(sessionID).jsonl")
        )
    }

    private static func record(sessionID: String) -> ClaudeLiveSessionRecord {
        ClaudeLiveSessionRecord(jsonData: Data(#"{"sessionId":"\#(sessionID)"}"#.utf8))!
    }
}
