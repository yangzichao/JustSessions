import Foundation

extension SessionDeletionConfirmationText {
    /// Keep each count combination a complete sentence, so translators can reorder both counts and nouns.
    static func skippedSessionsSentence(
        for plan: SessionDeletionPlan,
        language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String? {
        let openCount = plan.openTerminalCount
        let unsupportedCount = plan.unsupportedCount
        switch (openCount, unsupportedCount) {
        case (0, 0): return nil
        case (1, 0):
            return AppLocalization.string("1 session with an open terminal will be skipped.", language: language)
        case (_, 0):
            return AppLocalization.string("\(openCount) sessions with open terminals will be skipped.", language: language)
        case (0, 1):
            return AppLocalization.string("1 session from tools JustSessions can't delete will be skipped.", language: language)
        case (0, _):
            return AppLocalization.string("\(unsupportedCount) sessions from tools JustSessions can't delete will be skipped.", language: language)
        case (1, 1):
            return AppLocalization.string("1 session with an open terminal and 1 session from tools JustSessions can't delete will be skipped.", language: language)
        case (1, _):
            return AppLocalization.string("1 session with an open terminal and \(unsupportedCount) sessions from tools JustSessions can't delete will be skipped.", language: language)
        case (_, 1):
            return AppLocalization.string("\(openCount) sessions with open terminals and 1 session from tools JustSessions can't delete will be skipped.", language: language)
        default:
            return AppLocalization.string("\(openCount) sessions with open terminals and \(unsupportedCount) sessions from tools JustSessions can't delete will be skipped.", language: language)
        }
    }
}
