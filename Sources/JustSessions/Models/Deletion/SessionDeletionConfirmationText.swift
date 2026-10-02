import Foundation

/// The wording of the dialog that confirms deleting sessions: one session, a selection, or a whole project.
enum SessionDeletionConfirmationText {
    static let oneSessionButtonTitle = "Delete session"

    static func buttonTitle(for plan: SessionDeletionPlan, language: AppInterfaceLanguage = AppLocalization.developmentLanguage) -> String {
        let count = plan.deletableConversations.count
        return AppLocalization.string(count == 1 ? "Delete 1 session" : "Delete \(count) sessions", language: language)
    }

    static func message(forDeleting conversation: Conversation, language: AppInterfaceLanguage = AppLocalization.developmentLanguage) -> String {
        if let sshDestination = conversation.host.sshDestination {
            // The folder beside a Pi session holds subagent runs and forks that are never mirrored or listed.
            if conversation.provider == .pi {
                return AppLocalization.string("The Pi session file and its associated folder will be permanently deleted on \(sshDestination). SSH hosts have no Trash, so this cannot be undone.", language: language)
            }
            return AppLocalization.string("This session will be permanently deleted on \(sshDestination). SSH hosts have no Trash, so this cannot be undone.", language: language)
        }
        switch conversation.provider {
        case .codex, .kiro:
            return AppLocalization.string("\(conversation.provider.rawValue) will permanently delete this session using its native CLI. This cannot be undone.", language: language)
        case .claude:
            return AppLocalization.string("The Claude Code session file and its associated folder will move to the macOS Trash. This also removes its entry from Claude Code's local index.", language: language)
        case .antigravity:
            return AppLocalization.string("The Antigravity session database, associated folder, and annotations will move to the macOS Trash. This also removes its entry from Antigravity's local index.", language: language)
        case .pi:
            return AppLocalization.string("The Pi session file and its associated folder will move to the macOS Trash.", language: language)
        case .opencode:
            return AppLocalization.string("JustSessions can't delete \(conversation.provider.rawValue) sessions yet.", language: language)
        }
    }

    static func message(forDeletingSelectionWith plan: SessionDeletionPlan, language: AppInterfaceLanguage = AppLocalization.developmentLanguage) -> String {
        joined([
            AppLocalization.string("Claude Code, Antigravity, and Pi sessions on this Mac move to the Trash. Codex and Kiro CLI sessions and all sessions on SSH hosts are permanently deleted.", language: language),
            skippedSessionsSentence(for: plan, language: language),
        ])
    }

    static func message(forDeletingProjectAt location: ProjectLocation, plan: SessionDeletionPlan, language: AppInterfaceLanguage = AppLocalization.developmentLanguage) -> String {
        joined([
            AppLocalization.string("This affects all tools in \(location.copyablePath), including sessions hidden by the current filter.", language: language),
            AppLocalization.string("The project will stay in the sidebar.", language: language),
            location.host == .thisMac
                ? AppLocalization.string("Claude Code, Antigravity, and Pi sessions move to the Trash; Codex and Kiro CLI sessions are permanently deleted.", language: language)
                : AppLocalization.string("SSH hosts have no Trash, so every session is permanently deleted.", language: language),
            skippedSessionsSentence(for: plan, language: language),
        ])
    }

    private static func joined(_ sentences: [String?]) -> String {
        sentences.compactMap { $0 }.joined(separator: " ")
    }
}
