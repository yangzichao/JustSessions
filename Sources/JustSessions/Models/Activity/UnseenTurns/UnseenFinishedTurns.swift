import Foundation

/// The CLIs on this Mac that finished a turn while their terminal was off screen, until you look at them. The
/// notification about such a turn may be gone from Notification Center; this mark stays while the CLI runs.
/// A CLI that stops for your answer needs no mark: its status shows that for as long as it waits.
struct UnseenFinishedTurns: Equatable {
    /// Every key each unseen CLI goes by, so a tab stays unseen once it learns its session, and after it closes with
    /// its CLI left running in tmux; see `SessionAttentionSource.activityKeys`.
    private var unseenKeys: Set<String> = []

    var isEmpty: Bool { unseenKeys.isEmpty }

    func contains(_ source: SessionAttentionSource) -> Bool {
        source.activityKeys.contains(where: unseenKeys.contains)
    }

    /// After an activity sync: a CLI that just finished a turn out of view becomes unseen, and one in view is seen.
    /// A CLI missing from `observations` no longer runs and is forgotten, so a later CLI of its session starts seen.
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

    /// You looked at the CLI's terminal.
    mutating func markSeen(_ source: SessionAttentionSource) {
        unseenKeys.subtract(source.activityKeys)
    }
}
