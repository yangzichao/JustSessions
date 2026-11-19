import Foundation

enum HostBackgroundCheckSchedule {
    static let dailyInterval: TimeInterval = 24 * 60 * 60
    static let shortestInterval: TimeInterval = 10 * 60
    static let unfinishedCheckInterval: TimeInterval = 60 * 60
    static let unfinishedCheckFindingIDs: Set<HostCheckFindingID> = [.connection, .loginShell, .script]

    enum Reason: Equatable, Sendable {
        case neverChecked
        case checkedByAnotherAppVersion
        case tabEndedSoonAfterStarting
        case tmuxServerUnreachable
        case tmuxServerReachableAgain
        case refreshWorkedSinceUnfinishedCheck
        case daily
    }

    struct Refresh: Equatable, Sendable {
        let refreshedAt: Date
        let tmuxServerProblem: String?
    }

    static func reason(
        keptCheck: KeptHostCheck?,
        appVersion: String,
        lastRefresh: Refresh,
        tabAskedForCheck: Bool,
        now: Date
    ) -> Reason? {
        guard let keptCheck else { return .neverChecked }
        if keptCheck.appVersion != appVersion { return .checkedByAnotherAppVersion }
        let checkedAt = keptCheck.report.checkedAt
        let age = now.timeIntervalSince(checkedAt)
        guard age >= shortestInterval else { return nil }
        if tabAskedForCheck { return .tabEndedSoonAfterStarting }
        if lastRefresh.refreshedAt > checkedAt {
            switch (lastRefresh.tmuxServerProblem != nil, keptCheck.report.foundTmuxServerUnreachable) {
            case (true, false): return .tmuxServerUnreachable
            case (false, true): return .tmuxServerReachableAgain
            default: break
            }
            let checkWasUnfinished = keptCheck.report.findings.contains {
                $0.status == .problem && unfinishedCheckFindingIDs.contains($0.id)
            }
            if checkWasUnfinished && age >= unfinishedCheckInterval { return .refreshWorkedSinceUnfinishedCheck }
        }
        return age >= dailyInterval ? .daily : nil
    }
}
