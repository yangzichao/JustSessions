import AppKit
import Network

@MainActor
final class SSHHostReachabilityResets {
    static let shared = SSHHostReachabilityResets()

    private let reachability: SSHHostReachability
    private let pathMonitor = NWPathMonitor()
    private var wakeObserver: (any NSObjectProtocol)?

    init(reachability: SSHHostReachability = .shared) {
        self.reachability = reachability
    }

    func start() {
        guard wakeObserver == nil else { return }
        let reachability = reachability
        pathMonitor.pathUpdateHandler = { _ in reachability.forgetAll() }
        pathMonitor.start(queue: DispatchQueue(label: "JustSessions.SSHHostReachabilityResets", qos: .utility))
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in reachability.forgetAll() }
    }
}
