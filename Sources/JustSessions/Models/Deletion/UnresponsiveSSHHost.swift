import Foundation

enum UnresponsiveSSHHost: Hashable, Sendable {
    case couldNotConnect(host: String, problem: SSHConnectionProblem)
    case didNotRespondInTime(host: String)

    var host: String {
        switch self {
        case .couldNotConnect(let host, _), .didNotRespondInTime(let host): host
        }
    }

    var explanation: String {
        switch self {
        case .couldNotConnect(let host, let problem):
            problem.explanation(host: host)
        case .didNotRespondInTime(let host):
            "Deleting on \(host) didn't start or didn't finish within a minute. Refresh to see whether the session being deleted is gone."
        }
    }

    var isLikelyTemporary: Bool {
        switch self {
        case .couldNotConnect(_, let problem): problem.isLikelyTemporary
        case .didNotRespondInTime: true
        }
    }
}
