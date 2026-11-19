import Foundation

struct RemoteHostCopies {
    struct Copies: Equatable {
        var lastStartedAt: Date?
        var lastEndedAt: Date?
        var failuresInARow = 0
    }

    private var copiesByHost: [String: Copies] = [:]
    private let currentDate: () -> Date

    init(currentDate: @escaping () -> Date = Date.init) {
        self.currentDate = currentDate
    }

    func copies(of host: String) -> Copies { copiesByHost[host] ?? Copies() }

    mutating func noteStart(of host: String) {
        copiesByHost[host, default: Copies()].lastStartedAt = currentDate()
    }

    mutating func noteEnd(of host: String, failed: Bool) {
        var copies = copiesByHost[host, default: Copies()]
        copies.lastEndedAt = currentDate()
        copies.failuresInARow = failed ? copies.failuresInARow + 1 : 0
        copiesByHost[host] = copies
    }

    mutating func forget(_ host: String) {
        copiesByHost.removeValue(forKey: host)
    }

    static func combined(_ windows: [Copies]) -> Copies {
        var combined = Copies()
        for copies in windows {
            if let started = copies.lastStartedAt, started > (combined.lastStartedAt ?? .distantPast) {
                combined.lastStartedAt = started
            }
            if let ended = copies.lastEndedAt, ended > (combined.lastEndedAt ?? .distantPast) {
                combined.lastEndedAt = ended
                combined.failuresInARow = copies.failuresInARow
            }
        }
        return combined
    }
}
