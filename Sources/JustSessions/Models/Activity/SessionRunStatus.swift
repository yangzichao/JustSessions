import Foundation

/// What a session row or terminal tab shows about the CLI behind it. A session that nothing runs shows how long
/// ago it was active instead.
enum SessionRunStatus: Equatable {
    /// A CLI runs the session. `activity` is nil when the CLI does not tell what it is doing.
    case running(CLIActivity?)
    /// The tab is still open after its CLI ended.
    case ended

    /// What the indicator means, for its tooltip and accessibility label.
    var summary: String {
        switch self {
        case .running(.working): "Working"
        case .running(.needsInput(let reason)): reason.map { "Needs your input (\($0))" } ?? "Needs your input"
        case .running(.idle): "Idle, waiting for your next prompt"
        case .running(nil): "Running"
        case .ended: "Ended"
        }
    }
}
