import Foundation

/// A tmux session on an SSH host.
struct RemoteTmuxSessionKey: Hashable, Sendable {
    let host: String
    let tmuxSessionName: String
}

/// Reads what the CLIs of the app's tmux sessions on SSH hosts do while no tab shows them; see `RemoteTmuxPanes`. Every
/// window's activity sync asks it, once a second, for the hosts whose sessions run with no tab in any window. It asks
/// each such host at most every `interval`, one command at a time, through the host's shared connection (SSH-22),
/// and answers each sync at once with the last listing, so a slow host never holds up the sync. A host that doesn't
/// answer is asked again after `retryAfterFailure`.
@MainActor
final class RemoteDetachedActivityReader {
    static let shared = RemoteDetachedActivityReader()

    static let interval: TimeInterval = 3
    static let retryAfterFailure: TimeInterval = 30
    /// A listing older than this, as from a host that stopped answering, tells nothing.
    static let longestUseOfAListing: TimeInterval = 15

    struct Listing: Equatable {
        let panes: RemoteTmuxPanes
        /// When the host was asked for it, so a session it leaves out ran with no tab before then; see
        /// `ConversationStore.remoteDetachedSince`.
        let askedAt: Date
        /// When the answer came, which may be much later while the app is busy; its age counts from then.
        let answeredAt: Date
    }

    private let listPanes: @Sendable (String) -> RemoteTmuxPanes?
    private let currentDate: () -> Date
    private var listings: [String: Listing] = [:]
    private var lastAskedAt: [String: Date] = [:]
    private var failedAt: [String: Date] = [:]
    private var hostsBeingAsked: Set<String> = []

    init(
        listPanes: @escaping @Sendable (String) -> RemoteTmuxPanes? = { host in
            guard let result = RemoteHostCommandRunner().run(host, RemoteTmuxPanes.command(on: host), 10),
                result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus
            else { return nil }
            return RemoteTmuxPanes.panes(inOutput: result.output)
        },
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.listPanes = listPanes
        self.currentDate = currentDate
    }

    /// The reader's clock, by which a listing's times are taken; the store notes sessions by it too, so they compare.
    var now: Date { currentDate() }

    /// The host's last listing, unless it is too old to tell anything.
    func listing(of host: String) -> Listing? {
        guard let listing = listings[host],
            currentDate().timeIntervalSince(listing.answeredAt) < Self.longestUseOfAListing
        else { return nil }
        return listing
    }

    /// Asks the host in the background when it is due and not being asked already.
    func askIfDue(_ host: String) {
        let now = currentDate()
        guard !hostsBeingAsked.contains(host) else { return }
        if let failedAt = failedAt[host], now.timeIntervalSince(failedAt) < Self.retryAfterFailure { return }
        if let lastAskedAt = lastAskedAt[host], now.timeIntervalSince(lastAskedAt) < Self.interval { return }
        hostsBeingAsked.insert(host)
        lastAskedAt[host] = now
        let listPanes = listPanes
        Task { [weak self] in
            let panes = await Task.detached(priority: .utility) { listPanes(host) }.value
            self?.take(panes, from: host, askedAt: now)
        }
    }

    /// Waits for the host's answer; for tests.
    func ask(_ host: String) async {
        let now = currentDate()
        lastAskedAt[host] = now
        let listPanes = listPanes
        let panes = await Task.detached(priority: .utility) { listPanes(host) }.value
        take(panes, from: host, askedAt: now)
    }

    private func take(_ panes: RemoteTmuxPanes?, from host: String, askedAt: Date) {
        hostsBeingAsked.remove(host)
        guard let panes else {
            failedAt[host] = currentDate()
            return
        }
        failedAt[host] = nil
        listings[host] = Listing(panes: panes, askedAt: askedAt, answeredAt: currentDate())
    }
}
