import Foundation

/// Disconnect/removal cancels only the remaining deletions on that host. Cancel in the progress bar still cancels
/// the whole task between sessions. The worker reads this without hopping to the main actor for every file.
final class SessionDeletionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var hosts: Set<SessionHost> = []

    func cancel(on host: SessionHost) { lock.withLock { _ = hosts.insert(host) } }
    func isCancelled(on host: SessionHost) -> Bool { lock.withLock { hosts.contains(host) } }
}
