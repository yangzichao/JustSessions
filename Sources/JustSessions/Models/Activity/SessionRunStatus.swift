import Foundation

enum SessionRunStatus: Equatable {
    case running(CLIActivity?)
    case finishedUnseen
    case ended
    case waitingToBeShown

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

    func markingUnseenFinishedTurn(_ hasUnseenFinishedTurn: Bool) -> Self {
        guard hasUnseenFinishedTurn else { return self }
        switch self {
        case .running(.idle), .running(nil): return .finishedUnseen
        default: return self
        }
    }
}
