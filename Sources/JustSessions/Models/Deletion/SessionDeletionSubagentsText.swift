import Foundation

extension SessionDeletionConfirmationText {
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
