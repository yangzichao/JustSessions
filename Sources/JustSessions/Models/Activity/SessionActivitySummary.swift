import Foundation

/// The CLIs running a project's sessions, summed up for the project's row: the most pressing status and how many
/// CLIs are in each state.
struct SessionActivitySummary: Equatable {
    private(set) var needsInputCount = 0
    /// CLIs done with a turn you have not seen.
    private(set) var finishedUnseenCount = 0
    private(set) var workingCount = 0
    private(set) var idleCount = 0
    /// CLIs that run without telling what they are doing.
    private(set) var otherRunningCount = 0

    /// One activity per running CLI.
    init(activities: [CLIActivity?]) {
        self.init(statuses: activities.map(SessionRunStatus.running))
    }

    /// One status per running CLI; those of tabs that run nothing are left out.
    init(statuses: [SessionRunStatus]) {
        for status in statuses {
            switch status {
            case .running(.needsInput): needsInputCount += 1
            case .finishedUnseen: finishedUnseenCount += 1
            case .running(.working): workingCount += 1
            case .running(.idle): idleCount += 1
            case .running(nil): otherRunningCount += 1
            case .ended, .waitingToBeShown: break
            }
        }
    }

    var runningCount: Int { needsInputCount + finishedUnseenCount + workingCount + idleCount + otherRunningCount }

    /// A CLI that needs you comes first, then one done with a turn you have not seen, then one at work, then any that
    /// runs; nil when none runs.
    var mostPressingStatus: SessionRunStatus? {
        if needsInputCount > 0 { return .running(.needsInput(reason: nil)) }
        if finishedUnseenCount > 0 { return .finishedUnseen }
        if workingCount > 0 { return .running(.working) }
        if idleCount > 0 { return .running(.idle) }
        if otherRunningCount > 0 { return .running(nil) }
        return nil
    }

    /// Such as "1 needs your input, 1 not seen yet, 2 working, 1 idle"; empty when none runs.
    var summary: String {
        [
            needsInputCount > 0 ? "\(needsInputCount) \(needsInputCount == 1 ? "needs" : "need") your input" : nil,
            finishedUnseenCount > 0 ? "\(finishedUnseenCount) not seen yet" : nil,
            workingCount > 0 ? "\(workingCount) working" : nil,
            idleCount > 0 ? "\(idleCount) idle" : nil,
            otherRunningCount > 0 ? "\(otherRunningCount) running" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
