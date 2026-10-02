import Foundation

/// Runs the tmux commands sent to each host one at a time, in the order they were sent, off the main thread.
/// Ending a session right after it was renamed then kills it under its new name, instead of the kill arriving
/// first, finding nothing, and the rename leaving its CLI running.
@MainActor
final class TmuxCommandQueues {
    private var queuesByHost: [SessionHost: DispatchQueue] = [:]

    func run(on host: SessionHost, _ command: @escaping @Sendable () -> Void) {
        queue(for: host).async(execute: command)
    }

    private func queue(for host: SessionHost) -> DispatchQueue {
        if let queue = queuesByHost[host] { return queue }
        let queue = DispatchQueue(label: "JustSessions.tmux-commands.\(host.displayName)", qos: .utility)
        queuesByHost[host] = queue
        return queue
    }
}
