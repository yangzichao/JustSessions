import Foundation

enum KiroConversationDeletionError: LocalizedError, Equatable {
    case failed(String)
    case didNotFinish
    case sourceStillPresent
    /// A Kiro CLI still runs the session (`KiroSessionLock`).
    case stillRunning

    var errorDescription: String? {
        switch self {
        case .failed(let details): "Kiro CLI could not delete this session: \(details)"
        case .didNotFinish: "Kiro CLI did not finish deleting this session. Refresh and try again."
        // Kiro CLI 2.34.0 keeps a session a CLI still runs, and says it deleted it.
        case .sourceStillPresent:
            "Kiro CLI said it deleted this session but kept its files, as it does while a Kiro CLI runs the session. Quit that Kiro CLI, then delete the session again."
        case .stillRunning: "A Kiro CLI is still running this session. Quit it, then delete the session again."
        }
    }
}
