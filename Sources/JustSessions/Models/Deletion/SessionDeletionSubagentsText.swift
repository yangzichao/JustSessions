import Foundation

extension SessionDeletionConfirmationText {
    /// How many subagent sessions go with the sessions being deleted, and how many stay on disk: a session's subagents
    /// are listed only under it, so deleting it could otherwise take them, or strand them, unannounced.
    static func subagentSentences(
        for plan: SessionDeletionPlan,
        language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> [String] {
        var sentences: [String] = []
        switch plan.deletedSubagentCount {
        case 0: break
        case 1: sentences.append(AppLocalization.string("This also deletes 1 subagent session.", language: language))
        case let count: sentences.append(AppLocalization.string("This also deletes \(count) subagent sessions.", language: language))
        }
        switch plan.keptSubagentCount {
        case 0: break
        case 1: sentences.append(AppLocalization.string("1 subagent session stays on disk.", language: language))
        case let count: sentences.append(AppLocalization.string("\(count) subagent sessions stay on disk.", language: language))
        }
        return sentences
    }
}
