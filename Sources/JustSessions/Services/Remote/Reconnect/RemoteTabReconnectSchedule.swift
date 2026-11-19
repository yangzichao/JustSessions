import Foundation

struct RemoteTabReconnectSchedule {
    static let firstTryDelay: TimeInterval = 2
    static let shortestWait: TimeInterval = 5
    static let longestWait: TimeInterval = 60
    static let tryingPeriod: TimeInterval = 15 * 60

    private struct HostTries {
        var startedAt: Date
        var nextTryAt: Date
        var failuresInARow = 0
    }

    private var triesByHost: [String: HostTries] = [:]

    var hostsBeingTried: Set<String> { Set(triesByHost.keys) }

    func nextTryAt(excluding hostsBeingAsked: Set<String>) -> Date? {
        triesByHost.filter { !hostsBeingAsked.contains($0.key) }.values.map(\.nextTryAt).min()
    }

    mutating func startTrying(_ host: String, now: Date) {
        triesByHost[host] = HostTries(startedAt: now, nextTryAt: now + Self.firstTryDelay)
    }

    func isDue(_ host: String, now: Date) -> Bool {
        guard let tries = triesByHost[host] else { return false }
        return now >= tries.nextTryAt
    }

    @discardableResult
    mutating func noteFailure(on host: String, now: Date) -> Bool {
        guard var tries = triesByHost[host] else { return false }
        guard now.timeIntervalSince(tries.startedAt) < Self.tryingPeriod else {
            triesByHost.removeValue(forKey: host)
            return false
        }
        tries.failuresInARow += 1
        tries.nextTryAt = now + Self.wait(afterFailuresInARow: tries.failuresInARow)
        triesByHost[host] = tries
        return true
    }

    mutating func stopTrying(_ host: String) {
        triesByHost.removeValue(forKey: host)
    }

    static func wait(afterFailuresInARow failures: Int) -> TimeInterval {
        min(shortestWait * pow(2, Double(min(max(failures - 1, 0), 10))), longestWait)
    }
}
