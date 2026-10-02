import Foundation

/// An SSH host a deletion gave up on, and why. The rest of its sessions in that deletion are not attempted.
enum UnresponsiveSSHHost: Hashable, Sendable {
    /// `ssh` could not connect, or the connection dropped, for the reason its output gave.
    case couldNotConnect(host: String, problem: SSHConnectionProblem)
    /// No result within the deletion's timeout: the command on the host was slow or hung, or `ssh` could not be
    /// started on this Mac.
    case didNotRespondInTime(host: String)

    var host: String {
        switch self {
        case .couldNotConnect(let host, _), .didNotRespondInTime(let host): host
        }
    }

    /// What happened and what to do about it.
    var explanation: String {
        switch self {
        case .couldNotConnect(let host, let problem):
            problem.explanation(host: host)
        case .didNotRespondInTime(let host):
            "Deleting on \(host) didn't start or didn't finish within a minute. Refresh to see whether the session being deleted is gone."
        }
    }

    /// Whether Try Again may work without changing anything first.
    var isLikelyTemporary: Bool {
        switch self {
        case .couldNotConnect(_, let problem): problem.isLikelyTemporary
        case .didNotRespondInTime: true
        }
    }
}
