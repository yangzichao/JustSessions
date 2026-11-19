import Foundation

struct SessionAttentionTracker {
    private var lastKnownActivities: [String: CLIActivity] = [:]

    mutating func events(after observations: [SessionActivityObservation]) -> [SessionAttentionEvent] {
        var nextActivities: [String: CLIActivity] = [:]
        var events: [SessionAttentionEvent] = []
        for observation in observations {
            let keys = observation.source.activityKeys
            let previous = keys.compactMap { lastKnownActivities[$0] }.first
            if let reason = SessionAttentionReason.reason(changingFrom: previous, to: observation.activity) {
                events.append(SessionAttentionEvent(source: observation.source, reason: reason))
            }
            guard let known = observation.activity ?? previous else { continue }
            for key in keys { nextActivities[key] = known }
        }
        lastKnownActivities = nextActivities
        return events
    }
}
