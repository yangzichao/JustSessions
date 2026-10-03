import Foundation

extension SessionDeletionConfirmationText {
    static func skippedSessionsSentence(
        for plan: SessionDeletionPlan,
        language: AppInterfaceLanguage = AppLocalization.developmentLanguage
    ) -> String? {
        let openCount = plan.openTerminalCount
        switch openCount {
        case 0: return nil
        case 1: return AppLocalization.string("1 session with an open terminal will be skipped.", language: language)
        default: return AppLocalization.string("\(openCount) sessions with open terminals will be skipped.", language: language)
        }
    }
}
