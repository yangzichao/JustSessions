import Foundation

enum RemoteConversationDeletionError: LocalizedError {
    /// No result within the timeout.
    case couldNotRun(host: String)
    /// `ssh` exited with 255; `details` is the line of its output that tells why.
    case sshFailed(host: String, details: String)
    case failed(host: String, details: String)
    /// Not attempted: an earlier session on the host failed to connect or timed out, so the rest of the host's
    /// sessions in the same deletion are skipped.
    case notAttempted(UnresponsiveSSHHost)

    var errorDescription: String? {
        switch self {
        case .couldNotRun, .sshFailed: unresponsiveHost?.explanation
        case .failed(let host, let details): "Could not delete the session on \(host): \(details)"
        case .notAttempted(let unresponsiveHost): "Not attempted. \(unresponsiveHost.explanation)"
        }
    }

    /// The host and why it is given up on, when the error means the rest of its sessions should not be tried.
    var unresponsiveHost: UnresponsiveSSHHost? {
        switch self {
        case .sshFailed(let host, let details): .couldNotConnect(host: host, problem: SSHConnectionProblem(sshMessage: details))
        case .couldNotRun(let host): .didNotRespondInTime(host: host)
        case .notAttempted(let unresponsiveHost): unresponsiveHost
        case .failed: nil
        }
    }
}
