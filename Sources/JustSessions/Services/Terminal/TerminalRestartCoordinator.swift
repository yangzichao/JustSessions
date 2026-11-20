import Foundation

@MainActor
final class TerminalRestartCoordinator {
    private struct Cleanup {
        let tabID: UUID
        var resumes: [() -> Void] = []
    }
    private var cleanups: [String: Cleanup] = [:]

    func tabBeingCleanedUp(for conversationID: String) -> UUID? { cleanups[conversationID]?.tabID }

    func deferResume(for conversationID: String, _ resume: @escaping () -> Void) -> Bool {
        guard cleanups[conversationID] != nil else { return false }
        cleanups[conversationID]?.resumes.append(resume)
        return true
    }

    func replaceEndedTab(
        _ endedTab: TerminalSession,
        of conversationID: String,
        afterKillingItsTmuxSession killTmuxSession: @escaping @Sendable () -> Void,
        on tmuxCommandQueues: TmuxCommandQueues,
        with replaceEndedTab: @escaping @Sendable @MainActor () -> Void
    ) {
        guard cleanups[conversationID] == nil else { return }
        cleanups[conversationID] = Cleanup(tabID: endedTab.id)
        endedTab.close()
        tmuxCommandQueues.runAfterEarlierCommands(on: .thisMac) {
            killTmuxSession()
            Task { @MainActor in
                self.finishCleanup(for: conversationID, replacingEndedTab: replaceEndedTab)
            }
        }
    }

    private func finishCleanup(for conversationID: String, replacingEndedTab: () -> Void) {
        let resumes = cleanups.removeValue(forKey: conversationID)?.resumes ?? []
        replacingEndedTab()
        for resume in resumes { resume() }
    }
}
