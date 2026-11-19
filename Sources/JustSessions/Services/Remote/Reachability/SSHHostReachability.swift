import Foundation

final class SSHHostReachability: @unchecked Sendable {
    static let shared = SSHHostReachability()

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
