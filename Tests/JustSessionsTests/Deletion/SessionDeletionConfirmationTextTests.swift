import Testing
@testable import JustSessions

struct SessionDeletionConfirmationTextTests {
    @Test(arguments: [
        (0, nil),
        (1, "1 session with an open terminal will be skipped."),
        (3, "3 sessions with open terminals will be skipped."),
    ] as [(Int, String?)])
    func namesOnlyTheSessionsThatAreSkipped(openTerminalCount: Int, expectedSentence: String?) {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: openTerminalCount)
        #expect(SessionDeletionConfirmationText.skippedSessionsSentence(for: plan) == expectedSentence)
    }

    @Test(arguments: [(1, "Delete 1 session"), (2, "Delete 2 sessions"), (12, "Delete 12 sessions")])
    func buttonCountsOnlyTheSessionsItDeletes(deletableCount: Int, expectedTitle: String) {
        let plan = SessionDeletionPlan(deletableConversations: (0..<deletableCount).map { _ in .fixture() }, openTerminalCount: 3)
        #expect(SessionDeletionConfirmationText.buttonTitle(for: plan) == expectedTitle)
    }

    @Test func projectOnThisMacMentionsTheTrash() {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: 1)
        let message = SessionDeletionConfirmationText.message(
            forDeletingProjectAt: ProjectLocation(host: .thisMac, path: "/Users/me/app"),
            plan: plan
        )
        #expect(message == "This affects all tools in /Users/me/app, including sessions hidden by the current filter. "
            + "The project will stay in the sidebar. "
            + "Claude Code, Antigravity, and Pi sessions move to the Trash; Codex, Kiro CLI, and OpenCode sessions are permanently deleted. "
            + "1 session with an open terminal will be skipped.")
    }

    @Test func projectOnAnSSHHostSaysEverySessionIsGoneForGood() {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture(), .fixture()], openTerminalCount: 0)
        let message = SessionDeletionConfirmationText.message(
            forDeletingProjectAt: ProjectLocation(host: .ssh("devbox"), path: "/srv/app"),
            plan: plan
        )
        #expect(message == "This affects all tools in devbox:/srv/app, including sessions hidden by the current filter. "
            + "The project will stay in the sidebar. "
            + "SSH hosts have no Trash, so every session is permanently deleted.")
    }

    @Test func projectRemovalSaysTheProjectIsArchived() {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture(), .fixture()], openTerminalCount: 1)
        let message = SessionDeletionConfirmationText.message(
            forDeletingProjectAt: ProjectLocation(host: .thisMac, path: "/Users/me/app"),
            plan: plan,
            removesProjectFromSidebar: true
        )
        #expect(message == "This affects all tools in /Users/me/app, including sessions hidden by the current filter. "
            + "The project will be archived; skipped sessions stay on disk and come back when it is restored. "
            + "Claude Code, Antigravity, and Pi sessions move to the Trash; Codex, Kiro CLI, and OpenCode sessions are permanently deleted. "
            + "1 session with an open terminal will be skipped.")
        #expect(SessionDeletionConfirmationText.projectRemovalButtonTitle(for: plan) == "Archive project and delete 2 sessions")
    }

    @Test func selectionMentionsSkippedSessionsOnlyWhenThereAreSome() {
        let everythingDeletable = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: 0)
        let someSkipped = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: 2)
        let intro = "Claude Code, Antigravity, and Pi sessions on this Mac move to the Trash. Codex, Kiro CLI, and OpenCode sessions and all sessions on SSH hosts are permanently deleted."

        #expect(SessionDeletionConfirmationText.message(forDeletingSelectionWith: everythingDeletable) == intro)
        #expect(SessionDeletionConfirmationText.message(forDeletingSelectionWith: someSkipped)
            == intro + " 2 sessions with open terminals will be skipped.")
    }

    @Test(arguments: [
        (ConversationProvider.claude, SessionHost.thisMac, "The Claude Code session file and its associated folder will move to the macOS Trash. This also removes its entry from Claude Code's local index."),
        (.codex, .thisMac, "Codex will permanently delete this session using its native CLI. This cannot be undone."),
        (.kiro, .thisMac, "Kiro CLI will permanently delete this session using its native CLI. This cannot be undone."),
        (.opencode, .thisMac, "OpenCode will permanently delete this session using its native CLI. This cannot be undone."),
        (.pi, .thisMac, "The Pi session file and its associated folder will move to the macOS Trash."),
        (.claude, .ssh("devbox"), "This session will be permanently deleted on devbox. SSH hosts have no Trash, so this cannot be undone."),
        (.codex, .ssh("me@build"), "This session will be permanently deleted on me@build. SSH hosts have no Trash, so this cannot be undone."),
        (.pi, .ssh("devbox"), "The Pi session file and its associated folder will be permanently deleted on devbox. SSH hosts have no Trash, so this cannot be undone."),
    ])
    func oneSessionSaysWhereItGoes(provider: ConversationProvider, host: SessionHost, expectedMessage: String) {
        let conversation = Conversation.fixture(provider: provider, host: host)
        #expect(SessionDeletionConfirmationText.message(forDeleting: conversation) == expectedMessage)
    }

    @Test func selectedProjectsRemovalSaysWhereTheirSessionsGoByHost() {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: 2)
        let onThisMac = [ProjectLocation(host: .thisMac, path: "/a"), ProjectLocation(host: .thisMac, path: "/b")]
        let onBoth = [ProjectLocation(host: .thisMac, path: "/a"), ProjectLocation(host: .ssh("devbox"), path: "/b")]
        let onSSHHosts = [ProjectLocation(host: .ssh("devbox"), path: "/a"), ProjectLocation(host: .ssh("build"), path: "/b")]
        let opening = "This affects all tools in 2 projects, including sessions hidden by the current filter. "
            + "The projects will be archived; skipped sessions stay on disk and come back when they are restored. "
        let closing = " 2 sessions with open terminals will be skipped."

        #expect(SessionDeletionConfirmationText.message(forRemovingSelectedProjectsAt: onThisMac, plan: plan) == opening
            + "Claude Code, Antigravity, and Pi sessions move to the Trash; Codex, Kiro CLI, and OpenCode sessions are permanently deleted."
            + closing)
        #expect(SessionDeletionConfirmationText.message(forRemovingSelectedProjectsAt: onBoth, plan: plan) == opening
            + "Claude Code, Antigravity, and Pi sessions on this Mac move to the Trash. Codex, Kiro CLI, and OpenCode sessions and all sessions on SSH hosts are permanently deleted."
            + closing)
        #expect(SessionDeletionConfirmationText.message(forRemovingSelectedProjectsAt: onSSHHosts, plan: plan) == opening
            + "SSH hosts have no Trash, so every session is permanently deleted."
            + closing)
        #expect(SessionDeletionConfirmationText.selectedProjectsRemovalButtonTitle(projectCount: 2, plan: plan)
            == "Archive 2 projects and delete 1 session")
    }

    /// The dialog used to say "Delete 1 sessions" and "0 with open terminals will be skipped." Every count is
    /// checked for zeros and for stray spaces.
    @Test func noMessageMentionsZeroSessionsOrHasStraySpaces() {
        let locations = [ProjectLocation(host: .thisMac, path: "/p"), ProjectLocation(host: .ssh("devbox"), path: "/p")]
        for openTerminalCount in 0...3 {
            let plan = SessionDeletionPlan(deletableConversations: [.fixture()], openTerminalCount: openTerminalCount)
            let messages = locations.map { SessionDeletionConfirmationText.message(forDeletingProjectAt: $0, plan: plan) }
                + [SessionDeletionConfirmationText.message(forDeletingSelectionWith: plan)]
                + [SessionDeletionConfirmationText.message(forRemovingSelectedProjectsAt: locations, plan: plan)]
            for message in messages {
                #expect(!message.contains(" 0 ") && !message.hasPrefix("0 "), "\(message)")
                #expect(!message.contains("  ") && message == message.trimmingCharacters(in: .whitespaces), "\(message)")
                #expect(!message.contains("1 sessions"), "\(message)")
            }
        }
    }
}
