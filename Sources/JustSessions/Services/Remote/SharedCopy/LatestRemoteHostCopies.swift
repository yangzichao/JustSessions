import Foundation

/// The latest copy of each SSH host made by any window, so a window's refresh asked for before that copy started takes
/// the copy as its own: it waits for the copy, then lists it or shows its failure, instead of copying the host again
/// (PERF-26). Connect, and Connect… logging in or closing, refresh the host in every window at once; only the first
/// window to reach the host copies it. A refresh asked for once a copy has started copies again after it, as the host
/// may have changed since. Only a copy into the same local folder, from the same source, stands for another; every
/// window copies into the same one, but tests may give windows folders of their own. One per window registry, shared
/// by its windows.
@MainActor
final class LatestRemoteHostCopies {
    enum Outcome: Sendable {
        case copied(refreshedAt: Date, status: RemoteHostStatus?)
        case failed(any Error)
    }

    /// What a refresh does once no other work on the host runs.
    enum Turn: Sendable {
        /// Copies the host; `number` tells which refreshes the copy stands for.
        case copy(number: UInt64)
        /// Takes the outcome of another window's copy that started after this refresh was asked for.
        case take(Outcome)
    }

    private struct CopyPlace: Hashable {
        let host: String
        let cacheRoot: URL
        let sourceHomeOverride: String?

        init(host: String, mirror: RemoteSessionMirror) {
            self.host = host
            cacheRoot = mirror.cacheRoot
            sourceHomeOverride = mirror.sourceHomeOverride
        }
    }

    private struct EndedCopy {
        let number: UInt64
        let outcome: Outcome
    }

    /// Counts refresh requests and copy starts together, on the main actor, so they compare in the order they happened.
    private var lastNumber: UInt64 = 0
    private var endedCopies: [CopyPlace: EndedCopy] = [:]

    /// When a refresh is asked for; its number is compared with the numbers of copies that start later.
    func noteRefreshAsked() -> UInt64 {
        nextNumber()
    }

    /// The turn of a refresh asked for at `requestNumber`, once no other work on the host runs: the host's last copy
    /// ended before then, so a copy that started after the request has ended.
    func turn(on host: String, into mirror: RemoteSessionMirror, askedAt requestNumber: UInt64) -> Turn {
        if let ended = endedCopies[CopyPlace(host: host, mirror: mirror)], ended.number > requestNumber {
            return .take(ended.outcome)
        }
        return .copy(number: nextNumber())
    }

    /// A copy that was canceled, or whose window's refresh no longer counts, isn't noted, so the refreshes waiting
    /// for it copy the host themselves.
    func noteCopyEnded(on host: String, into mirror: RemoteSessionMirror, number: UInt64, outcome: Outcome) {
        let place = CopyPlace(host: host, mirror: mirror)
        if let ended = endedCopies[place], ended.number > number { return }
        endedCopies[place] = EndedCopy(number: number, outcome: outcome)
    }

    /// When the host is removed.
    func forget(_ host: String) {
        endedCopies = endedCopies.filter { $0.key.host != host }
    }

    private func nextNumber() -> UInt64 {
        lastNumber &+= 1
        return lastNumber
    }
}
