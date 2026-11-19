import Foundation

struct UnseenFinishedTurns: Equatable {
    private var unseenKeys: Set<String> = []

    var isEmpty: Bool { unseenKeys.isEmpty }

    func contains(_ source: SessionAttentionSource) -> Bool {
        source.activityKeys.contains(where: unseenKeys.contains)
    }

    mutating func update(
        after observations: [SessionActivityObservation],
        events: [SessionAttentionEvent],
        isInView: (SessionAttentionSource) -> Bool
    ) {
        let justFinished = Set(events.filter { $0.reason == .finishedTurn }.map(\.source))
        var nextKeys: Set<String> = []
        for observation in observations {
            let source = observation.source
            guard !isInView(source), justFinished.contains(source) || contains(source) else { continue }
            nextKeys.formUnion(source.activityKeys)
        }
        unseenKeys = nextKeys
    }

    mutating func markSeen(_ source: SessionAttentionSource) {
        unseenKeys.subtract(source.activityKeys)
    }
}
