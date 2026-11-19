import Foundation

enum RemoteConversationDeletionError: LocalizedError {
    case couldNotRun(host: String)
    case sshFailed(host: String, details: String)
    case failed(host: String, details: String)
    case notAttempted(UnresponsiveSSHHost)

    var errorDescription: String? {
        switch self {
        case .couldNotRun, .sshFailed: unresponsiveHost?.explanation
        case .failed(let host, let details): "Could not delete the session on \(host): \(details)"
        case .notAttempted(let unresponsiveHost): "Not attempted. \(unresponsiveHost.explanation)"
        }
    }

    var unresponsiveHost: UnresponsiveSSHHost? {
        switch self {
        case .sshFailed(let host, let details): .couldNotConnect(host: host, problem: SSHConnectionProblem(sshMessage: details))
        case .couldNotRun(let host): .didNotRespondInTime(host: host)
        case .notAttempted(let unresponsiveHost): unresponsiveHost
        case .failed: nil
        }
    }
}
