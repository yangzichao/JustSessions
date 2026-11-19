import Foundation

struct WaitingForYouStartTimes: Equatable {
    private enum WaitKind: Equatable {
        case needsInput
        case finishedTurn

        init(_ reason: SessionAttentionReason) {
            switch reason {
            case .needsInput: self = .needsInput
            case .finishedTurn: self = .finishedTurn
            }
        }
    }

    private struct Wait: Equatable {
        let kind: WaitKind
        let startTime: Date
    }

    private var waitsByActivityKey: [String: Wait] = [:]

    func startTime(of source: SessionAttentionSource) -> Date? {
        wait(of: source)?.startTime
    }

    mutating func update(
        after observations: [SessionActivityObservation],
        unseenFinishedTurns: UnseenFinishedTurns,
        at now: Date
    ) {
        var nextWaits: [String: Wait] = [:]
        for observation in observations {
            let previousWait = wait(of: observation.source)
            let reason = WaitingForYou.reason(
                activity: observation.activity,
                hasUnseenFinishedTurn: unseenFinishedTurns.contains(observation.source)
            )
            let nextWait: Wait?
            if let reason {
                let kind = WaitKind(reason)
                nextWait = previousWait?.kind == kind ? previousWait : Wait(kind: kind, startTime: now)
            } else {
                nextWait = observation.activity == nil ? previousWait : nil
            }
            guard let nextWait else { continue }
            for key in observation.source.activityKeys { nextWaits[key] = nextWait }
        }
        waitsByActivityKey = nextWaits
    }

    private func wait(of source: SessionAttentionSource) -> Wait? {
        source.activityKeys.lazy.compactMap { waitsByActivityKey[$0] }.first
    }
}
