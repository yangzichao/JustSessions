import Foundation

@MainActor
final class LatestRemoteHostCopies {
    enum Outcome: Sendable {
        case copied(refreshedAt: Date, status: RemoteHostStatus?)
        case failed(any Error)
    }

    struct Moment: Comparable, Sendable {
        fileprivate let tick: UInt64

        static func < (earlier: Moment, later: Moment) -> Bool { earlier.tick < later.tick }
    }

    enum Turn: Sendable {
        case copy(startedAt: Moment)
        case take(Outcome)
    }

    private struct CopyPlace: Hashable {
        let host: String
        let cacheRoot: URL

        init(host: String, mirror: RemoteSessionMirror) {
            self.host = host
            cacheRoot = mirror.cacheRoot
        }
    }

    private struct EndedCopy {
        let startedAt: Moment
        let outcome: Outcome
    }

    private var lastMoment = Moment(tick: 0)
    private var endedCopies: [CopyPlace: EndedCopy] = [:]

    func noteRefreshAsked() -> Moment {
        nextMoment()
    }

    func turn(on host: String, into mirror: RemoteSessionMirror, askedAt refreshAskedAt: Moment) -> Turn {
        if let ended = endedCopies[CopyPlace(host: host, mirror: mirror)], ended.startedAt > refreshAskedAt {
            return .take(ended.outcome)
        }
        return .copy(startedAt: nextMoment())
    }

    func noteCopyEnded(on host: String, into mirror: RemoteSessionMirror, startedAt: Moment, outcome: Outcome) {
        let place = CopyPlace(host: host, mirror: mirror)
        if let ended = endedCopies[place], ended.startedAt > startedAt { return }
        endedCopies[place] = EndedCopy(startedAt: startedAt, outcome: outcome)
    }

    func forget(_ host: String) {
        endedCopies = endedCopies.filter { $0.key.host != host }
    }

    private func nextMoment() -> Moment {
        lastMoment = Moment(tick: lastMoment.tick &+ 1)
        return lastMoment
    }
}
