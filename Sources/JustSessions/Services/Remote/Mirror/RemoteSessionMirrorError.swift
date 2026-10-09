import Foundation

enum RemoteSessionMirrorError: LocalizedError, Equatable {
    case couldNotRun(host: String)
    /// `ssh` could not connect, or lost the connection, for the reason its output gave.
    case sshFailed(host: String, problem: SSHConnectionProblem)
    case rsyncMissingOnHost(host: String)
    case rsyncFailed(host: String, output: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host):
            "Copying sessions from \(host) did not start or took longer than 10 minutes."
        case .sshFailed(let host, let problem):
            problem.explanation(host: host)
        case .rsyncMissingOnHost(let host):
            "rsync is not installed on \(host). Install it there, then refresh."
        case .rsyncFailed(let host, let output):
            "Copying sessions from \(host) failed: \(output)"
        }
    }
}
