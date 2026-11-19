import Foundation
import Testing

@testable import JustSessions

struct HostBackgroundCheckScheduleTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func aHostNeverCheckedOrCheckedByAnotherVersionIsDue() {
        #expect(reason(keptCheck: nil) == .neverChecked)
        #expect(reason(keptCheck: check(minutesAgo: 1, appVersion: "1.2.10")) == .checkedByAnotherAppVersion)
    }

    @Test func aHostIsCheckedAgainOnceADay() {
        #expect(reason(keptCheck: check(minutesAgo: 23 * 60)) == nil)
        #expect(reason(keptCheck: check(minutesAgo: 24 * 60)) == .daily)
    }

    @Test func aTabEndingSoonAfterItStartedAsksForACheckButNotWithinTenMinutesOfTheLast() {
        #expect(reason(keptCheck: check(minutesAgo: 9), tabAskedForCheck: true) == nil)
        #expect(reason(keptCheck: check(minutesAgo: 10), tabAskedForCheck: true) == .tabEndedSoonAfterStarting)
    }

    @Test func aRefreshAfterTheCheckThatDisagreesAboutTheTmuxServerAsksForACheck() {
        let passedCheck = check(minutesAgo: 30)
        #expect(
            reason(keptCheck: passedCheck, refreshMinutesAgo: 1, tmuxServerProblem: "protocol version mismatch")
                == .tmuxServerUnreachable)
        #expect(reason(keptCheck: passedCheck, refreshMinutesAgo: 31, tmuxServerProblem: "protocol version mismatch") == nil)

        let tmuxProblemCheck = check(minutesAgo: 30, findings: [finding(.tmux, .problem)])
        #expect(reason(keptCheck: tmuxProblemCheck, refreshMinutesAgo: 1) == .tmuxServerReachableAgain)
        #expect(reason(keptCheck: tmuxProblemCheck, refreshMinutesAgo: 1, tmuxServerProblem: "server exited unexpectedly") == nil)
    }

    @Test func aCheckThatCouldntFinishIsCheckedAgainWithinTheHourOnceARefreshWorked() {
        let unfinishedCheck = { (minutesAgo: Double) in self.check(minutesAgo: minutesAgo, findings: [self.finding(.script, .problem)]) }
        #expect(reason(keptCheck: unfinishedCheck(59), refreshMinutesAgo: 1) == nil)
        #expect(reason(keptCheck: unfinishedCheck(60), refreshMinutesAgo: 1) == .refreshWorkedSinceUnfinishedCheck)
        #expect(reason(keptCheck: unfinishedCheck(60), refreshMinutesAgo: 61) == nil)
        #expect(reason(keptCheck: check(minutesAgo: 60, findings: [finding(.cli(.claude), .problem)]), refreshMinutesAgo: 1) == nil)
    }

    private func reason(
        keptCheck: KeptHostCheck?,
        refreshMinutesAgo: Double = 0,
        tmuxServerProblem: String? = nil,
        tabAskedForCheck: Bool = false
    ) -> HostBackgroundCheckSchedule.Reason? {
        HostBackgroundCheckSchedule.reason(
            keptCheck: keptCheck,
            appVersion: "1.2.11",
            lastRefresh: .init(refreshedAt: now.addingTimeInterval(-refreshMinutesAgo * 60), tmuxServerProblem: tmuxServerProblem),
            tabAskedForCheck: tabAskedForCheck,
            now: now
        )
    }

    private func check(minutesAgo: Double, appVersion: String = "1.2.11", findings: [HostCheckFinding] = []) -> KeptHostCheck {
        KeptHostCheck(
            report: HostCheckReport(
                host: "devbox",
                checkedAt: now.addingTimeInterval(-minutesAgo * 60),
                thisMacSummary: "",
                findings: [finding(.connection, .passed)] + findings
            ),
            appVersion: appVersion
        )
    }

    private func finding(_ id: HostCheckFindingID, _ status: HostCheckFinding.Status) -> HostCheckFinding {
        HostCheckFinding(id: id, status: status, title: id.rawValue, summary: "")
    }
}
