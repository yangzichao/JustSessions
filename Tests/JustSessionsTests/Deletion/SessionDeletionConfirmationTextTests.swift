import Testing
@testable import JustSessions

struct SessionDeletionConfirmationTextTests {
    struct SkippedSessionsCase: Sendable, CustomTestStringConvertible {
        let openTerminalCount: Int
        let unsupportedCount: Int
        let expectedSentence: String?
        var testDescription: String { "\(openTerminalCount) open, \(unsupportedCount) Antigravity" }
    }

    static let skippedSessionsCases = [
        SkippedSessionsCase(openTerminalCount: 0, unsupportedCount: 0, expectedSentence: nil),
        SkippedSessionsCase(openTerminalCount: 1, unsupportedCount: 0, expectedSentence: "1 session with an open terminal will be skipped."),
        SkippedSessionsCase(openTerminalCount: 3, unsupportedCount: 0, expectedSentence: "3 sessions with open terminals will be skipped."),
        SkippedSessionsCase(openTerminalCount: 0, unsupportedCount: 1, expectedSentence: "1 Antigravity session will be skipped."),
        SkippedSessionsCase(openTerminalCount: 0, unsupportedCount: 2, expectedSentence: "2 Antigravity sessions will be skipped."),
        SkippedSessionsCase(
            openTerminalCount: 1,
            unsupportedCount: 1,
            expectedSentence: "1 session with an open terminal and 1 Antigravity session will be skipped."
        ),
        SkippedSessionsCase(
            openTerminalCount: 2,
            unsupportedCount: 4,
            expectedSentence: "2 sessions with open terminals and 4 Antigravity sessions will be skipped."
        ),
    ]

    @Test(arguments: skippedSessionsCases)
    func namesOnlyTheSessionsThatAreSkipped(_ skippedSessionsCase: SkippedSessionsCase) {
        let plan = SessionDeletionPlan(
            deletableConversations: [.fixture()],
            openTerminalCount: skippedSessionsCase.openTerminalCount,
            unsupportedCount: skippedSessionsCase.unsupportedCount
        )
        #expect(SessionDeletionConfirmationText.skippedSessionsSentence(for: plan) == skippedSessionsCase.expectedSentence)
    }

    @Test(arguments: [(1, "Delete 1 session"), (2, "Delete 2 sessions"), (12, "Delete 12 sessions")])
    func buttonCountsOnlyTheSessionsItDeletes(deletableCount: Int, expectedTitle: String) {
        let plan = SessionDeletionPlan(
            deletableConversations: (0..<deletableCount).map { _ in .fixture() },
            openTerminalCount: 3,
            unsupportedCount: 3
        )
        #expect(SessionDeletionConfirmationText.buttonTitle(for: plan) == expectedTitle)
    }

    @Test func projectOnThisMacMentionsTheTrash() {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: 1, unsupportedCount: 0)
        let message = SessionDeletionConfirmationText.message(
            forDeletingProjectAt: ProjectLocation(host: .thisMac, path: "/Users/me/app"),
            plan: plan
        )
        #expect(message == "This affects all tools in /Users/me/app, including sessions hidden by the current filter. "
            + "Claude Code sessions move to the Trash; Codex sessions are permanently deleted. "
            + "1 session with an open terminal will be skipped.")
    }

    @Test func projectOnAnSSHHostSaysEverySessionIsGoneForGood() {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture(), .fixture()], openTerminalCount: 0, unsupportedCount: 0)
        let message = SessionDeletionConfirmationText.message(
            forDeletingProjectAt: ProjectLocation(host: .ssh("devbox"), path: "/srv/app"),
            plan: plan
        )
        #expect(message == "This affects all tools in devbox:/srv/app, including sessions hidden by the current filter. "
            + "SSH hosts have no Trash, so every session is permanently deleted.")
    }

    @Test func selectionMentionsSkippedSessionsOnlyWhenThereAreSome() {
        let everythingDeletable = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: 0, unsupportedCount: 0)
        let someSkipped = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: 0, unsupportedCount: 2)
        let intro = "Claude Code sessions on this Mac move to the Trash; Codex sessions and sessions on SSH hosts are permanently deleted."

        #expect(SessionDeletionConfirmationText.message(forDeletingSelectionWith: everythingDeletable) == intro)
        #expect(SessionDeletionConfirmationText.message(forDeletingSelectionWith: someSkipped)
            == intro + " 2 Antigravity sessions will be skipped.")
    }

    @Test(arguments: [
        (ConversationProvider.claude, SessionHost.thisMac, "The Claude Code session file and its associated folder will move to the macOS Trash. This also removes its entry from Claude Code's local index."),
        (.codex, .thisMac, "Codex will permanently delete this session using its native CLI. This cannot be undone."),
        (.claude, .ssh("devbox"), "This session will be permanently deleted on devbox. SSH hosts have no Trash, so this cannot be undone."),
        (.codex, .ssh("me@build"), "This session will be permanently deleted on me@build. SSH hosts have no Trash, so this cannot be undone."),
    ])
    func oneSessionSaysWhereItGoes(provider: ConversationProvider, host: SessionHost, expectedMessage: String) {
        let conversation = Conversation.fixture(provider: provider, host: host)
        #expect(SessionDeletionConfirmationText.message(forDeleting: conversation) == expectedMessage)
    }

    /// The dialog used to say "Delete 1 sessions" and "0 with open terminals and 0 Antigravity sessions will be
    /// skipped." Every combination is checked for counts of zero and for stray spaces.
    @Test func noMessageMentionsZeroSessionsOrHasStraySpaces() {
        let locations = [ProjectLocation(host: .thisMac, path: "/p"), ProjectLocation(host: .ssh("devbox"), path: "/p")]
        for openTerminalCount in 0...3 {
            for unsupportedCount in 0...3 {
                let plan = SessionDeletionPlan(
                    deletableConversations: [.fixture()],
                    openTerminalCount: openTerminalCount,
                    unsupportedCount: unsupportedCount
                )
                let messages = locations.map { SessionDeletionConfirmationText.message(forDeletingProjectAt: $0, plan: plan) }
                    + [SessionDeletionConfirmationText.message(forDeletingSelectionWith: plan)]
                for message in messages {
                    #expect(!message.contains(" 0 ") && !message.hasPrefix("0 "), "\(message)")
                    #expect(!message.contains("  ") && message == message.trimmingCharacters(in: .whitespaces), "\(message)")
                    #expect(!message.contains("1 sessions"), "\(message)")
                }
            }
        }
    }
}
