import Foundation

enum OpenCodeConversationDeletionError: LocalizedError, Equatable {
    case failed(String)
    case didNotFinish
    case sessionStillPresent

    var errorDescription: String? {
        switch self {
        case .failed(let details): "OpenCode could not delete this session: \(details)"
        case .didNotFinish: "OpenCode did not finish deleting this session. Refresh and try again."
        case .sessionStillPresent: "OpenCode reported success, but the session is still in its database. Refresh and try again."
        }
    }
}
