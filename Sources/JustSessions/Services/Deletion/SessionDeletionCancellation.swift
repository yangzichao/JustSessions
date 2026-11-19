import Foundation

final class SessionDeletionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var hosts: Set<SessionHost> = []

    func cancel(on host: SessionHost) { lock.withLock { _ = hosts.insert(host) } }
    func isCancelled(on host: SessionHost) -> Bool { lock.withLock { hosts.contains(host) } }
}
