import Foundation

/// What a session row or terminal tab shows about the CLI behind it. A session that nothing runs shows how long
/// ago it was active instead.
enum SessionRunStatus: Equatable {
    /// A CLI runs the session. `activity` is nil when the CLI does not tell what it is doing.
    case running(CLIActivity?)
    /// A CLI done with a turn that finished while its terminal was off screen, until you look; see
    /// `UnseenFinishedTurns`.
    case finishedUnseen
    /// The tab is still open after its CLI ended.
    case ended
    /// A tab reopened at launch that starts its CLI once you select it.
    case waitingToBeShown

    /// What the indicator means, for its tooltip and accessibility label.
    var summary: String {
        switch self {
        case .running(.working): "Working"
        case .running(.needsInput(let reason)): reason.map { "Needs your input (\($0))" } ?? "Needs your input"
        case .running(.idle): "Idle, waiting for your next prompt"
        case .running(nil): "Running"
        case .finishedUnseen: "Finished its turn, not seen yet"
        case .ended: "Ended"
        case .waitingToBeShown: "Reopened from last time; starts when you select its tab"
        }
    }

    /// A running CLI between turns shows the turn you have not seen; one at work, or stopped for your answer, shows
    /// that instead, as `WaitingForYou` counts it.
    func markingUnseenFinishedTurn(_ hasUnseenFinishedTurn: Bool) -> Self {
        guard hasUnseenFinishedTurn else { return self }
        switch self {
        case .running(.idle), .running(nil): return .finishedUnseen
        default: return self
        }
    }
}
