import Foundation

@testable import JustSessions

final class SimulatedSSHHosts: @unchecked Sendable {
    enum Reply: Sendable {
        case finished(exitStatus: Int32, output: String)
        case noResultWithinTheTimeout

        var runnerResult: (exitStatus: Int32, output: String)? {
            switch self {
            case .finished(let exitStatus, let output): (exitStatus, output)
            case .noResultWithinTheTimeout: nil
            }
        }
    }

    typealias Answer = @Sendable (_ host: String, _ attempt: Int) -> Reply

    static let connectionFailure = Reply.finished(
        exitStatus: RemoteHostCommandRunner.connectionFailureExitStatus,
        output: "ssh: Could not resolve hostname devbox: nodename nor servname provided, or not known\n"
    )
    static let connectionLost = Reply.finished(
        exitStatus: RemoteHostCommandRunner.connectionFailureExitStatus, output: "Timeout, server devbox not responding.\r\n")
    static let alreadyGone = Reply.finished(exitStatus: RemoteConversationDeletion.missingTranscriptExitStatus, output: "")
    static let deleted = Reply.finished(exitStatus: 0, output: "")

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
                return self.answer(host, attempt).runnerResult
            })
    }
}
