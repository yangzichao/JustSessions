import Foundation

/// The wording of the dialog that confirms deleting sessions: one session, a selection, or a whole project.
enum SessionDeletionConfirmationText {
    static let oneSessionButtonTitle = "Delete session"

    static func buttonTitle(for plan: SessionDeletionPlan) -> String {
        "Delete \(CountedNoun.phrase(count: plan.deletableConversations.count, singular: "session"))"
    }

    static func message(forDeleting conversation: Conversation) -> String {
        if let sshDestination = conversation.host.sshDestination {
            return "This session will be permanently deleted on \(sshDestination). SSH hosts have no Trash, so this cannot be undone."
        }
        switch conversation.provider {
        case .codex, .kiro:
            return "\(conversation.provider.rawValue) will permanently delete this session using its native CLI. This cannot be undone."
        case .claude:
            return "The Claude Code session file and its associated folder will move to the macOS Trash. This also removes its entry from Claude Code's local index."
        case .antigravity, .opencode, .pi:
            return "JustSessions can't delete \(conversation.provider.rawValue) sessions yet."
        }
    }

    static func message(forDeletingSelectionWith plan: SessionDeletionPlan) -> String {
        joined([
            "Claude Code sessions on this Mac move to the Trash. Codex and Kiro CLI sessions and all sessions on SSH hosts are permanently deleted.",
            skippedSessionsSentence(for: plan),
        ])
    }

    static func message(forDeletingProjectAt location: ProjectLocation, plan: SessionDeletionPlan) -> String {
        joined([
            "This affects all tools in \(location.copyablePath), including sessions hidden by the current filter.",
            "The project will stay in the sidebar.",
            location.host == .thisMac
                ? "Claude Code sessions move to the Trash; Codex and Kiro CLI sessions are permanently deleted."
                : "SSH hosts have no Trash, so every session is permanently deleted.",
            skippedSessionsSentence(for: plan),
        ])
    }

    /// Names what the deletion leaves alone, or nil when it deletes every candidate.
    static func skippedSessionsSentence(for plan: SessionDeletionPlan) -> String? {
        var skippedParts: [String] = []
        if plan.openTerminalCount > 0 {
            skippedParts.append(plan.openTerminalCount == 1
                ? "1 session with an open terminal"
                : "\(plan.openTerminalCount) sessions with open terminals")
        }
        if plan.unsupportedCount > 0 {
            skippedParts.append(CountedNoun.phrase(count: plan.unsupportedCount, singular: "session") + " from tools JustSessions can't delete")
        }
        guard !skippedParts.isEmpty else { return nil }
        return skippedParts.joined(separator: " and ") + " will be skipped."
    }

    private static func joined(_ sentences: [String?]) -> String {
        sentences.compactMap { $0 }.joined(separator: " ")
    }
}
