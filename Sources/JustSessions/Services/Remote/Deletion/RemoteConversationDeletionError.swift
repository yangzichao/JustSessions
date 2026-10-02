import Foundation

enum RemoteConversationDeletionError: LocalizedError {
    case couldNotRun(host: String)
    case sshFailed(host: String)
    case missingOnHost(host: String)
    case failed(host: String, details: String)
    /// Not attempted: an earlier session on the host failed to connect or timed out, so the rest of the host's
    /// sessions in the same deletion are skipped.
    case notAttempted(UnresponsiveSSHHost)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host): "Deleting the session on \(host) did not start or did not finish within a minute."
        case .sshFailed(let host): "Could not connect to \(host) to delete the session."
        case .missingOnHost(let host): "The session file is no longer on \(host). Refresh the conversation list."
        case .failed(let host, let details): "Could not delete the session on \(host): \(details)"
        case .notAttempted(let unresponsiveHost): "Not deleted because \(unresponsiveHost.explanation)."
        }
    }

    /// The host and why it is given up on, when the error means the rest of its sessions should not be tried.
    var unresponsiveHost: UnresponsiveSSHHost? {
        switch self {
        case .sshFailed(let host): .couldNotConnect(host: host)
        case .couldNotRun(let host): .didNotRespondInTime(host: host)
        case .notAttempted(let unresponsiveHost): unresponsiveHost
        case .missingOnHost, .failed: nil
        }
    }
}
