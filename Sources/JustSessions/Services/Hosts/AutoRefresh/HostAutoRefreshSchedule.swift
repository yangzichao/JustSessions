import Foundation

struct HostAutoRefreshSchedule {
    static let thisMacInterval: TimeInterval = 60
    static let sshHostInterval: TimeInterval = 5 * 60
    static let longestSSHHostWait: TimeInterval = 60 * 60

    private var lastTryByFailingHost: [String: Date] = [:]
    private var failuresInARowByHost: [String: Int] = [:]

    func isThisMacDue(lastRefreshStartedAt: Date?, status: HostRefreshStatus?, now: Date) -> Bool {
        guard status != .refreshing, let lastRefreshStartedAt else { return false }
        return now.timeIntervalSince(lastRefreshStartedAt) >= Self.thisMacInterval
    }

    mutating func isSSHHostDue(_ host: String, status: HostRefreshStatus?, needsLogIn: Bool, now: Date) -> Bool {
        switch status {
        case nil, .refreshing?:
            return false
        case .refreshed(let refreshedAt)?:
            lastTryByFailingHost.removeValue(forKey: host)
            failuresInARowByHost.removeValue(forKey: host)
            return now.timeIntervalSince(refreshedAt) >= Self.sshHostInterval
        case .failed?:
            guard !needsLogIn else { return false }
            guard let lastTry = lastTryByFailingHost[host] else {
                lastTryByFailingHost[host] = now
                failuresInARowByHost[host] = 1
                return false
            }
            return now.timeIntervalSince(lastTry) >= Self.wait(afterFailuresInARow: failuresInARowByHost[host, default: 1])
        }
    }

    mutating func noteTry(on host: String, at date: Date) {
        lastTryByFailingHost[host] = date
    }

    mutating func noteResult(on host: String, status: HostRefreshStatus?) {
        if case .failed? = status {
            failuresInARowByHost[host, default: 0] += 1
        } else {
            lastTryByFailingHost.removeValue(forKey: host)
            failuresInARowByHost.removeValue(forKey: host)
        }
    }

    static func wait(afterFailuresInARow failures: Int) -> TimeInterval {
        min(sshHostInterval * pow(2, Double(min(max(failures - 1, 0), 10))), longestSSHHostWait)
    }
}
