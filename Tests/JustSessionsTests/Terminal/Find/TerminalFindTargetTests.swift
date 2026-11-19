import AppKit
import Testing

@testable import JustSessions

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

    @Test func aCLITabNotLinkedYetFindsInTheTerminal() {
        #expect(TerminalFindTarget(tab: makeTab(provider: .claude, conversation: nil)) == .terminal)
    }
}
