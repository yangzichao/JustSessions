import Foundation

enum KiroConversationDeletionError: LocalizedError, Equatable {
    case failed(String)
    case didNotFinish
    case sourceStillPresent

    var errorDescription: String? {
        switch self {
        case .failed(let details): "Kiro CLI could not delete this session: \(details)"
        case .didNotFinish: "Kiro CLI did not finish deleting this session. Refresh and try again."
        case .sourceStillPresent: "Kiro CLI reported success, but the session files are still present. Refresh and try again."
        }
    }
}
