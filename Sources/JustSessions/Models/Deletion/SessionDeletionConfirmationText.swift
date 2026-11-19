import Foundation

enum SessionDeletionConfirmationText {
    static let oneSessionButtonTitle = "Delete session"

    static func buttonTitle(for plan: SessionDeletionPlan, language: AppInterfaceLanguage = AppLocalization.developmentLanguage) -> String {
        let count = plan.deletableConversations.count
        if plan.cliEndingCount > 0 {
            return AppLocalization.string(
                count == 1 ? "Close and delete 1 session" : "Close and delete \(count) sessions", language: language)
        }
        return AppLocalization.string(count == 1 ? "Delete 1 session" : "Delete \(count) sessions", language: language)
    }

    static func projectRemovalButtonTitle(
        for plan: SessionDeletionPlan, language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String {
        let count = plan.deletableConversations.count
        return AppLocalization.string(
            count == 1 ? "Archive project and delete 1 session" : "Archive project and delete \(count) sessions",
            language: language
        )
    }

    static func message(
        forDeleting conversation: Conversation,
        plan: SessionDeletionPlan? = nil,
        cliEnding: SessionCLIEndingBeforeDeletion? = nil,
        language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String {
        joined(
            [cliEnding.map { cliEndingSentence($0, host: conversation.host, language: language) }]
                + [oneSessionSentence(forDeleting: conversation, language: language)]
                + (plan.map { subagentSentences(for: $0, language: language) } ?? []))
    }

    private static func cliEndingSentence(_ cliEnding: SessionCLIEndingBeforeDeletion, host: SessionHost, language: AppInterfaceLanguage)
        -> String
    {
        switch cliEnding {
        case .closingTab:
            AppLocalization.string("Its tab closes and its CLI ends first.", language: language)
        case .endingCLIInTmux:
            AppLocalization.string("Its CLI, still running on \(host.nameInSentence), ends first.", language: language)
        }
    }

    static func cliEndingSentence(for plan: SessionDeletionPlan, language: AppInterfaceLanguage) -> String? {
        switch plan.cliEndingCount {
        case 0: nil
        case 1: AppLocalization.string("1 session is still running: its tab closes and its CLI ends first.", language: language)
        default:
            AppLocalization.string(
                "\(plan.cliEndingCount) sessions are still running: their tabs close and their CLIs end first.", language: language)
        }
    }

    private static func oneSessionSentence(forDeleting conversation: Conversation, language: AppInterfaceLanguage) -> String {
        if let sshDestination = conversation.host.sshDestination {
            // The folder beside a Pi session holds subagent runs and forks that are never mirrored or listed.
            if conversation.provider == .pi {
                return AppLocalization.string(
                    "The Pi session file and its associated folder will be permanently deleted on \(sshDestination). SSH hosts have no Trash, so this cannot be undone.",
                    language: language)
            }
            return AppLocalization.string(
                "This session will be permanently deleted on \(sshDestination). SSH hosts have no Trash, so this cannot be undone.",
                language: language)
        }
        switch conversation.provider {
        case .codex, .kiro, .opencode:
            return AppLocalization.string(
                "\(conversation.provider.rawValue) will permanently delete this session using its native CLI. This cannot be undone.",
                language: language)
        case .claude:
            return AppLocalization.string(
                "The Claude Code session file and its associated folder will move to the macOS Trash. This also removes its entry from Claude Code's local index.",
                language: language)
        case .antigravity:
            return AppLocalization.string(
                "The Antigravity session database, associated folder, and annotations will move to the macOS Trash. This also removes its entry from Antigravity's local index.",
                language: language)
        case .pi:
            return AppLocalization.string("The Pi session file and its associated folder will move to the macOS Trash.", language: language)
        }
    }

    static func message(
        forDeletingSelectionWith plan: SessionDeletionPlan, language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String {
        joined(
            [
                cliEndingSentence(for: plan, language: language),
                AppLocalization.string(
                    "Claude Code, Antigravity, and Pi sessions on this Mac move to the Trash. Codex, Kiro CLI, and OpenCode sessions and all sessions on SSH hosts are permanently deleted.",
                    language: language),
            ] + subagentSentences(for: plan, language: language) + [
                skippedSessionsSentence(for: plan, language: language)
            ])
    }

    static func message(
        forDeletingProjectAt location: ProjectLocation,
        plan: SessionDeletionPlan,
        removesProjectFromSidebar: Bool = false,
        language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String {
        joined(
            [
                AppLocalization.string(
                    "This affects all tools in \(location.copyablePath), including sessions hidden by the current filter.",
                    language: language),
                cliEndingSentence(for: plan, language: language),
                removesProjectFromSidebar
                    ? AppLocalization.string(
                        "The project will be archived; skipped sessions stay on disk and come back when it is restored.", language: language
                    )
                    : AppLocalization.string("The project will stay in the sidebar.", language: language),
                location.host == .thisMac
                    ? AppLocalization.string(
                        "Claude Code, Antigravity, and Pi sessions move to the Trash; Codex, Kiro CLI, and OpenCode sessions are permanently deleted.",
                        language: language)
                    : AppLocalization.string("SSH hosts have no Trash, so every session is permanently deleted.", language: language),
            ] + subagentSentences(for: plan, language: language) + [
                skippedSessionsSentence(for: plan, language: language)
            ])
    }

    private static func joined(_ sentences: [String?]) -> String {
        sentences.compactMap { $0 }.joined(separator: " ")
    }
}
