import Foundation

/// An SSH host a deletion gave up on, and why. The rest of its sessions in that deletion are not attempted.
enum UnresponsiveSSHHost: Hashable, Sendable {
    /// `ssh` could not connect, or the connection dropped.
    case couldNotConnect(host: String)
    /// No result within the deletion's timeout. The host may have answered too slowly rather than not at all.
    case didNotRespondInTime(host: String)

    var host: String {
        switch self {
        case .couldNotConnect(let host), .didNotRespondInTime(let host): host
        }
    }

    /// Completes "Not deleted because …" and "…, so N sessions on it were not deleted".
    var explanation: String {
        switch self {
        case .couldNotConnect(let host): "\(host) could not be reached"
        case .didNotRespondInTime(let host): "\(host) did not respond in time"
        }
    }
}
