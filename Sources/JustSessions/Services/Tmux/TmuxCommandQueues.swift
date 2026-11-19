import Foundation

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
