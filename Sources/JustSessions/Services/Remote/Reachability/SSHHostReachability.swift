import Foundation

/// SSH hosts the app's background commands couldn't reach lately: the host name didn't resolve, nothing answered, or
/// nothing took SSH connections. For `failureMemory` after such a failure, every background command to the host gets
/// that failure again at once instead of connecting, so a host that is off or out of reach doesn't hold each refresh,
/// check, and lookup for `ConnectTimeout` again. A command that reaches the host forgets the failure; so does a retry
/// you ask for, such as a heading's refresh, a login with Connect…, and the network changing or the Mac waking (see
/// `SSHHostReachabilityResets`).
final class SSHHostReachability: @unchecked Sendable {
    static let shared = SSHHostReachability()

    /// Longer than the shortest waits between the app's own tries, such as Reconnect's, so those come to one try
    /// a minute while the host is out of reach.
    static let failureMemory: TimeInterval = 60

    private struct Failure {
        let sshOutput: String
        let seenAt: Date
    }

    private let lock = NSLock()
    private let currentDate: @Sendable () -> Date
    private var failuresByHost: [String: Failure] = [:]

    init(currentDate: @escaping @Sendable () -> Date = Date.init) {
        self.currentDate = currentDate
    }

    /// What `ssh` printed when it last couldn't reach the host, while that failure is remembered.
    func recentFailureOutput(on host: String) -> String? {
        lock.withLock {
            guard let failure = failuresByHost[host] else { return nil }
            guard currentDate().timeIntervalSince(failure.seenAt) < Self.failureMemory else {
                failuresByHost.removeValue(forKey: host)
                return nil
            }
            return failure.sshOutput
        }
    }

    /// After a background command to the host ended: remembers that `ssh` couldn't reach it, and forgets that once
    /// any command gets through, even one the host refuses to log in.
    func noteResult(exitStatus: Int32, output: String, on host: String) {
        let couldNotReach =
            exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus
            && SSHConnectionProblem(sshOutput: output).meansHostIsOutOfReach
        lock.withLock {
            if couldNotReach {
                failuresByHost[host] = Failure(sshOutput: output, seenAt: currentDate())
            } else {
                failuresByHost.removeValue(forKey: host)
            }
        }
    }

    func forget(_ host: String) {
        _ = lock.withLock { failuresByHost.removeValue(forKey: host) }
    }

    func forgetAll() {
        lock.withLock { failuresByHost.removeAll() }
    }
}
