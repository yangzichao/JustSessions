import Testing
@testable import JustSessions

struct ConversationDeletionFailureTests {
    @Test func oneSessionShowsTheReasonAlone() {
        let failure = ConversationDeletionFailure(conversation: .fixture(title: "Refactor"), reason: "Codex exited with code 1")
        #expect(ConversationDeletionFailure.messageAfterDeletingOneSession([failure]) == "Codex exited with code 1")
    }

    @Test func severalSessionsNameEachFailedSessionAndItsTool() {
        let failures = [
            ConversationDeletionFailure(conversation: .fixture(provider: .claude, title: "Refactor"), reason: "Permission denied"),
            ConversationDeletionFailure(conversation: .fixture(provider: .codex, title: "Fix tests"), reason: "Exit code 7"),
        ]
        #expect(ConversationDeletionFailure.messageAfterDeletingSeveralSessions(failures) == """
            Some sessions could not be deleted:
            Claude Code · Refactor: Permission denied
            Codex · Fix tests: Exit code 7
            """)
    }
}
