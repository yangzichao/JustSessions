import Foundation

/// Compares what each CLI on this Mac does with what it did one activity sync earlier, and tells which ones just
/// finished a turn or stopped to wait on you.
struct SessionAttentionTracker {
    /// The last activity each running CLI told, under every key it goes by.
    private var lastKnownActivities: [String: CLIActivity] = [:]

    /// The CLIs in `observations` that just started wanting you back. A CLI missing from `observations` no longer
    /// runs and is forgotten, so a later CLI of the same session starts afresh.
    mutating func events(after observations: [SessionActivityObservation]) -> [SessionAttentionEvent] {
        var nextActivities: [String: CLIActivity] = [:]
        var events: [SessionAttentionEvent] = []
        for observation in observations {
            let keys = observation.source.activityKeys
            let previous = keys.compactMap { lastKnownActivities[$0] }.first
            if let reason = SessionAttentionReason.reason(changingFrom: previous, to: observation.activity) {
                events.append(SessionAttentionEvent(source: observation.source, reason: reason))
            }
            // A CLI that tells nothing for a moment keeps what it told before.
            guard let known = observation.activity ?? previous else { continue }
            for key in keys { nextActivities[key] = known }
        }
        lastKnownActivities = nextActivities
        return events
    }
}
