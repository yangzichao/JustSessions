import Foundation

enum KiroConversationDeletionError: LocalizedError, Equatable {
    case failed(String)
    case didNotFinish
    case sourceStillPresent
    case stillRunning

    var errorDescription: String? {
        switch self {
        case .failed(let details): "Kiro CLI could not delete this session: \(details)"
        case .didNotFinish: "Kiro CLI did not finish deleting this session. Refresh and try again."
        case .sourceStillPresent:
            "Kiro CLI said it deleted this session but kept its files, as it does while a Kiro CLI runs the session. Quit that Kiro CLI, then delete the session again."
        case .stillRunning: "A Kiro CLI is still running this session. Quit it, then delete the session again."
        }
    }
}
