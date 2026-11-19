import Foundation

@MainActor
final class LatestRemoteHostCopies {
    enum Outcome: Sendable {
        case copied(refreshedAt: Date, status: RemoteHostStatus?)
        case failed(any Error)
    }

    enum Turn: Sendable {
        case copy(number: UInt64)
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

    private var lastNumber: UInt64 = 0
    private var endedCopies: [CopyPlace: EndedCopy] = [:]

    func noteRefreshAsked() -> UInt64 {
        nextNumber()
    }

    func turn(on host: String, into mirror: RemoteSessionMirror, askedAt requestNumber: UInt64) -> Turn {
        if let ended = endedCopies[CopyPlace(host: host, mirror: mirror)], ended.number > requestNumber {
            return .take(ended.outcome)
        }
        return .copy(number: nextNumber())
    }

    func noteCopyEnded(on host: String, into mirror: RemoteSessionMirror, number: UInt64, outcome: Outcome) {
        let place = CopyPlace(host: host, mirror: mirror)
        if let ended = endedCopies[place], ended.number > number { return }
        endedCopies[place] = EndedCopy(number: number, outcome: outcome)
    }

    func forget(_ host: String) {
        endedCopies = endedCopies.filter { $0.key.host != host }
    }

    private func nextNumber() -> UInt64 {
        lastNumber &+= 1
        return lastNumber
    }
}
