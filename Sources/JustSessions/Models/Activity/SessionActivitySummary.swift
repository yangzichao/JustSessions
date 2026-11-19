import Foundation

struct SessionActivitySummary: Equatable {
    private(set) var needsInputCount = 0
    private(set) var finishedUnseenCount = 0
    private(set) var workingCount = 0
    private(set) var idleCount = 0
    private(set) var otherRunningCount = 0

    init(activities: [CLIActivity?]) {
        self.init(statuses: activities.map(SessionRunStatus.running))
    }

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

    var mostPressingStatus: SessionRunStatus? {
        if needsInputCount > 0 { return .running(.needsInput(reason: nil)) }
        if finishedUnseenCount > 0 { return .finishedUnseen }
        if workingCount > 0 { return .running(.working) }
        if idleCount > 0 { return .running(.idle) }
        if otherRunningCount > 0 { return .running(nil) }
        return nil
    }

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
