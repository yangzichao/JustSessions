import AppKit
import Testing

@testable import JustSessions

/// What ⌘F searches in a tab: the conversation of a tab linked to a session, the terminal otherwise.
@MainActor
struct TerminalFindTargetTests {
    private func makeTab(provider: ConversationProvider?, conversation: Conversation?) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: conversation,
            provider: provider,
            projectPath: "/tmp/terminal-find",
            action: provider == nil ? nil : .resume,
            displayTitle: "Find target",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: [])
        )
    }

    @Test func aTabLinkedToASessionFindsInItsConversation() {
        let conversation = TranscriptScrollViewFixture.conversation("linked-tab")
        #expect(TerminalFindTarget(tab: makeTab(provider: .codex, conversation: conversation)) == .conversation(conversation))
    }

    @Test func aPlainTerminalFindsInTheTerminal() {
        #expect(TerminalFindTarget(tab: makeTab(provider: nil, conversation: nil)) == .terminal)
    }

    /// A new session's tab finds its session once the CLI writes it; until then only the terminal has its output.
    @Test func aCLITabNotLinkedYetFindsInTheTerminal() {
        #expect(TerminalFindTarget(tab: makeTab(provider: .claude, conversation: nil)) == .terminal)
    }
}
