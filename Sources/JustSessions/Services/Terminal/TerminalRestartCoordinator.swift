import Foundation

/// A failed pane is removed before any window can start another CLI under its session name. A second Resume waits
/// for that cleanup instead of queuing another kill that could arrive after the replacement started. Requests retain
/// their windows weakly, and the queued cleanup keeps this coordinator alive even if the first window closes.
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

    func beginCleanup(for conversationID: String, tabID: UUID) -> Bool {
        guard cleanups[conversationID] == nil else { return false }
        cleanups[conversationID] = Cleanup(tabID: tabID)
        return true
    }

    func finishCleanup(for conversationID: String, replacingEndedTab: () -> Void) {
        let resumes = cleanups.removeValue(forKey: conversationID)?.resumes ?? []
        replacingEndedTab()
        for resume in resumes { resume() }
    }
}
