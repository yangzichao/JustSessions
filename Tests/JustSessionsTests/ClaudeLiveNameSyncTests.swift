import Foundation
import Testing
@testable import JustSessions

@MainActor
struct ClaudeLiveNameSyncTests {
    private static let resumedSessionID = "11111111-1111-4111-8111-111111111111"
    private static let newSessionID = "22222222-2222-4222-8222-222222222222"
    private static let sessionIDAfterClear = "33333333-3333-4333-8333-333333333333"

    @Test func renameInsideResumedTabUpdatesTabAndSidebarEntry() async throws {
        let store = try await makeStore(discovering: [Self.conversation(sessionID: Self.resumedSessionID, title: "First prompt")])
        let session = makeSession(linkedTo: store.conversations.first, action: .resume, displayTitle: "First prompt")

        store.applyLiveName(from: Self.record(sessionID: Self.resumedSessionID, name: "Renamed live"), to: session)

        #expect(session.displayTitle == "Renamed live")
        #expect(store.conversations.first?.suggestedTitle == "Renamed live")
    }

    @Test func renameInsideNewTabRetitlesTheTabBeforeTheSessionIsDiscovered() async throws {
        let store = try await makeStore(discovering: [Self.conversation(sessionID: Self.resumedSessionID, title: "Unrelated")])
        let session = makeSession(linkedTo: nil, action: .new, displayTitle: "New Claude Code session")

        store.applyLiveName(from: Self.record(sessionID: Self.newSessionID, name: "Brand new name"), to: session)

        #expect(session.displayTitle == "Brand new name")
        #expect(store.conversations.map(\.suggestedTitle) == ["Unrelated"])
    }

    @Test func renameInsideNewTabUpdatesTheSidebarEntryOnceDiscovered() async throws {
        let store = try await makeStore(discovering: [Self.conversation(sessionID: Self.newSessionID, title: "Stale first prompt")])
        let session = makeSession(linkedTo: nil, action: .new, displayTitle: "New Claude Code session")

        store.applyLiveName(from: Self.record(sessionID: Self.newSessionID, name: "Brand new name"), to: session)

        #expect(session.displayTitle == "Brand new name")
        #expect(store.conversations.first?.suggestedTitle == "Brand new name")
    }

    @Test func tabKeepsItsTitleOnceItsCLIMovesToAnotherSession() async throws {
        let store = try await makeStore(discovering: [Self.conversation(sessionID: Self.resumedSessionID, title: "Original")])
        let session = makeSession(linkedTo: store.conversations.first, action: .resume, displayTitle: "Original")

        store.applyLiveName(from: Self.record(sessionID: Self.sessionIDAfterClear, name: "Cleared name"), to: session)

        #expect(session.displayTitle == "Original")
        #expect(store.conversations.first?.suggestedTitle == "Original")
    }

    @Test func namesTheUserDidNotChooseLeaveTitlesAlone() async throws {
        let store = try await makeStore(discovering: [Self.conversation(sessionID: Self.resumedSessionID, title: "First prompt")])
        let session = makeSession(linkedTo: store.conversations.first, action: .resume, displayTitle: "First prompt")

        store.applyLiveName(
            from: Self.record(sessionID: Self.resumedSessionID, name: "justsessions-03", nameSource: "derived"),
            to: session
        )

        #expect(session.displayTitle == "First prompt")
        #expect(store.conversations.first?.suggestedTitle == "First prompt")
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

    private func makeSession(linkedTo conversation: Conversation?, action: ConversationAction, displayTitle: String) -> TerminalSession {
        TerminalSession(
            conversation: conversation,
            provider: .claude,
            projectPath: "/tmp/live-name-project",
            action: action,
            displayTitle: displayTitle,
            command: NativeCLICommand(
                executablePath: "/usr/bin/true",
                arguments: [],
                workingDirectory: "/tmp/live-name-project",
                environment: []
            )
        )
    }

    private static func conversation(sessionID: String, title: String) -> Conversation {
        Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: "/tmp/live-name-project",
            suggestedTitle: title,
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/live-name-project/\(sessionID).jsonl")
        )
    }

    private static func record(sessionID: String, name: String, nameSource: String = "user") -> ClaudeLiveSessionRecord {
        let json = #"{"sessionId":"\#(sessionID)","name":"\#(name)","nameSource":"\#(nameSource)"}"#
        return ClaudeLiveSessionRecord(jsonData: Data(json.utf8))!
    }
}

struct StaticConversationAdapter: ConversationAdapter {
    let provider: ConversationProvider = .claude
    let discoveredConversations: [Conversation]

    func discover() throws -> [Conversation] { discoveredConversations }
    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}
