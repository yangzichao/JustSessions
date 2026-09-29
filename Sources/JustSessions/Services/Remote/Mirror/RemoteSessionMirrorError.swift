import Foundation

enum RemoteSessionMirrorError: LocalizedError {
    case couldNotRun(host: String)
    case sshFailed(host: String)
    case rsyncMissingOnHost(host: String)
    case rsyncFailed(host: String, output: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host):
            "Copying sessions from \(host) did not start or took longer than 10 minutes."
        case .sshFailed(let host):
            "Could not connect to \(host). Check that `ssh \(host)` works in Terminal without a password prompt "
                + "(use an SSH key or agent)."
        case .rsyncMissingOnHost(let host):
            "rsync is not installed on \(host). Install it there, then refresh."
        case .rsyncFailed(let host, let output):
            "Copying sessions from \(host) failed: \(output)"
        }
    }
}
