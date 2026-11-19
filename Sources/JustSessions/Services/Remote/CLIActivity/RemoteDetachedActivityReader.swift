import Foundation

struct RemoteTmuxSessionKey: Hashable, Sendable {
    let host: String
    let tmuxSessionName: String
}

@MainActor
final class RemoteDetachedActivityReader {
    static let shared = RemoteDetachedActivityReader()

    static let interval: TimeInterval = 3
    static let retryAfterFailure: TimeInterval = 30
    static let longestUseOfAListing: TimeInterval = 15

    struct Listing: Equatable {
        let panes: RemoteTmuxPanes
        let askedAt: Date
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

    var now: Date { currentDate() }

    func listing(of host: String) -> Listing? {
        guard let listing = listings[host],
            currentDate().timeIntervalSince(listing.answeredAt) < Self.longestUseOfAListing
        else { return nil }
        return listing
    }

    @discardableResult
    func askIfDue(_ host: String) -> Task<Void, Never>? {
        let now = currentDate()
        guard !hostsBeingAsked.contains(host) else { return nil }
        if let failedAt = failedAt[host], now.timeIntervalSince(failedAt) < Self.retryAfterFailure { return nil }
        if let lastAskedAt = lastAskedAt[host], now.timeIntervalSince(lastAskedAt) < Self.interval { return nil }
        hostsBeingAsked.insert(host)
        lastAskedAt[host] = now
        let listPanes = listPanes
        return Task { [weak self] in
            let panes = await Task.detached(priority: .utility) { listPanes(host) }.value
            self?.take(panes, from: host, askedAt: now)
        }
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
