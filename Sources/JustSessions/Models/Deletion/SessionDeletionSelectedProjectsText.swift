import Foundation

/// The wording of the dialog that confirms archiving the projects selected in the sidebar and deleting their sessions.
extension SessionDeletionConfirmationText {
    static func selectedProjectsRemovalButtonTitle(
        projectCount: Int,
        plan: SessionDeletionPlan,
        language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String {
        let count = plan.deletableConversations.count
        return AppLocalization.string(
            count == 1
                ? "Archive \(projectCount) projects and delete 1 session"
                : "Archive \(projectCount) projects and delete \(count) sessions",
            language: language
        )
    }

    static func message(
        forRemovingSelectedProjectsAt locations: [ProjectLocation],
        plan: SessionDeletionPlan,
        language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String {
        let hosts = Set(locations.map(\.host))
        let deletionSentence: String
        if hosts == [.thisMac] {
            deletionSentence = AppLocalization.string("Claude Code, Antigravity, and Pi sessions move to the Trash; Codex, Kiro CLI, and OpenCode sessions are permanently deleted.", language: language)
        } else if hosts.contains(.thisMac) {
            deletionSentence = AppLocalization.string("Claude Code, Antigravity, and Pi sessions on this Mac move to the Trash. Codex, Kiro CLI, and OpenCode sessions and all sessions on SSH hosts are permanently deleted.", language: language)
        } else {
            deletionSentence = AppLocalization.string("SSH hosts have no Trash, so every session is permanently deleted.", language: language)
        }
        let sentences: [String?] = [
            AppLocalization.string("This affects all tools in \(locations.count) projects, including sessions hidden by the current filter.", language: language),
            AppLocalization.string("The projects will be archived; skipped sessions stay on disk and come back when they are restored.", language: language),
            deletionSentence,
        ] + subagentSentences(for: plan, language: language) + [
            skippedSessionsSentence(for: plan, language: language),
        ]
        return sentences.compactMap { $0 }.joined(separator: " ")
    }
}
