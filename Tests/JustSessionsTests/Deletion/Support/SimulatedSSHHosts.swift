import Foundation

@testable import JustSessions

final class SimulatedSSHHosts: @unchecked Sendable {
    typealias Answer = @Sendable (_ host: String, _ attempt: Int) -> (exitStatus: Int32, output: String)?

    static let connectionFailure: (exitStatus: Int32, output: String) = (
        RemoteHostCommandRunner.connectionFailureExitStatus,
        "ssh: Could not resolve hostname devbox: nodename nor servname provided, or not known\n"
    )
    static let connectionLost: (exitStatus: Int32, output: String) =
        (RemoteHostCommandRunner.connectionFailureExitStatus, "Timeout, server devbox not responding.\r\n")
    static let alreadyGone: (exitStatus: Int32, output: String) = (RemoteConversationDeletion.missingTranscriptExitStatus, "")
    static let deleted: (exitStatus: Int32, output: String) = (0, "")

    private let lock = NSLock()
    private var attemptsByHost: [String: Int] = [:]
    private let answer: Answer
    private let heldAttempt: Int?
    private let heldAttemptRelease = DispatchSemaphore(value: 0)

    init(holdingAttempt: Int? = nil, answer: @escaping Answer) {
        self.answer = answer
        heldAttempt = holdingAttempt
    }

    func attempts(on host: String) -> Int {
        lock.withLock { attemptsByHost[host] ?? 0 }
    }

    var totalAttempts: Int {
        lock.withLock { attemptsByHost.values.reduce(0, +) }
    }

    func releaseHeldAttempt() {
        heldAttemptRelease.signal()
    }

    var deletion: RemoteConversationDeletion {
        RemoteConversationDeletion(
            runner: RemoteHostCommandRunner { host, _, _ in
                let (attempt, totalAttempts) = self.lock.withLock {
                    self.attemptsByHost[host, default: 0] += 1
                    return (self.attemptsByHost[host] ?? 0, self.attemptsByHost.values.reduce(0, +))
                }
                if totalAttempts == self.heldAttempt { self.heldAttemptRelease.wait() }
                return self.answer(host, attempt)
            })
    }
}
