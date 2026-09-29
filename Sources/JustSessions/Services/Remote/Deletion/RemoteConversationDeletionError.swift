import Foundation

enum RemoteConversationDeletionError: LocalizedError {
    case couldNotRun(host: String)
    case sshFailed(host: String)
    case missingOnHost(host: String)
    case failed(host: String, details: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host): "Deleting the session on \(host) did not start or did not finish within a minute."
        case .sshFailed(let host): "Could not connect to \(host) to delete the session."
        case .missingOnHost(let host): "The session file is no longer on \(host). Refresh the conversation list."
        case .failed(let host, let details): "Could not delete the session on \(host): \(details)"
        }
    }
}
