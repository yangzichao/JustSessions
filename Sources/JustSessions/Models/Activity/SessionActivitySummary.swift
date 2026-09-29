import Foundation

/// The CLIs running a project's sessions, summed up for the project's row: the most pressing status and how many
/// CLIs are in each state.
struct SessionActivitySummary: Equatable {
    private(set) var needsInputCount = 0
    private(set) var workingCount = 0
    private(set) var idleCount = 0
    /// CLIs that run without telling what they are doing.
    private(set) var otherRunningCount = 0

    /// One activity per running CLI.
    init(activities: [CLIActivity?]) {
        for activity in activities {
            switch activity {
            case .needsInput: needsInputCount += 1
            case .working: workingCount += 1
            case .idle: idleCount += 1
            case nil: otherRunningCount += 1
            }
        }
    }

    var runningCount: Int { needsInputCount + workingCount + idleCount + otherRunningCount }

    /// A CLI that needs you comes first, then one at work, then any that runs; nil when none runs.
    var mostPressingStatus: SessionRunStatus? {
        if needsInputCount > 0 { return .running(.needsInput(reason: nil)) }
        if workingCount > 0 { return .running(.working) }
        if idleCount > 0 { return .running(.idle) }
        if otherRunningCount > 0 { return .running(nil) }
        return nil
    }

    /// Such as "1 needs your input, 2 working, 1 idle"; empty when none runs.
    var summary: String {
        [
            needsInputCount > 0 ? "\(needsInputCount) \(needsInputCount == 1 ? "needs" : "need") your input" : nil,
            workingCount > 0 ? "\(workingCount) working" : nil,
            idleCount > 0 ? "\(idleCount) idle" : nil,
            otherRunningCount > 0 ? "\(otherRunningCount) running" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
