import Foundation
import Testing

@testable import JustSessions

/// This Mac is refreshed a minute after its last refresh, an SSH host five minutes after its last copy, and a failing
/// host less often each time it fails again. `isSSHHostDue` notes what it sees, so its result is read before `#expect`.
struct HostAutoRefreshScheduleTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let failed = HostRefreshStatus.failed("Connection timed out")

    @Test func thisMacIsDueAMinuteAfterItsLastRefreshStarted() {
        let schedule = HostAutoRefreshSchedule()
        #expect(!schedule.isThisMacDue(lastRefreshStartedAt: start, status: .refreshed(start), now: start + 59))
        #expect(schedule.isThisMacDue(lastRefreshStartedAt: start, status: .refreshed(start), now: start + 60))
        #expect(!schedule.isThisMacDue(lastRefreshStartedAt: start, status: .refreshing, now: start + 600))
    }

    /// The window's own first refresh comes when it opens, so the schedule doesn't start one alongside it.
    @Test func aHostWithoutItsFirstRefreshIsLeftToItsWindow() {
        var schedule = HostAutoRefreshSchedule()
        #expect(!schedule.isThisMacDue(lastRefreshStartedAt: nil, status: nil, now: start))
        let isSSHHostDue = schedule.isSSHHostDue("devbox", status: nil, needsLogIn: false, now: start)
        #expect(!isSSHHostDue)
    }

    @Test func anSSHHostIsDueFiveMinutesAfterItsLastCopy() {
        var schedule = HostAutoRefreshSchedule()
        let isDueJustBefore = schedule.isSSHHostDue("devbox", status: .refreshed(start), needsLogIn: false, now: start + 299)
        let isDueAtFiveMinutes = schedule.isSSHHostDue("devbox", status: .refreshed(start), needsLogIn: false, now: start + 300)
        let isDueWhileRefreshing = schedule.isSSHHostDue("devbox", status: .refreshing, needsLogIn: false, now: start + 3_000)
        #expect(!isDueJustBefore)
        #expect(isDueAtFiveMinutes)
        #expect(!isDueWhileRefreshing)
    }

    @Test func aFailingHostWaitsTwiceAsLongAfterEachFailureUpToAnHour() {
        var schedule = HostAutoRefreshSchedule()
        // The first refresh failed: the failure counts from when the schedule sees it.
        let isDueWhenFirstSeen = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: false, now: start)
        #expect(!isDueWhenFirstSeen)
        var lastTry = start
        for expectedWait: TimeInterval in [300, 600, 1_200, 2_400, 3_600, 3_600] {
            let isDueJustBefore = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: false, now: lastTry + expectedWait - 1)
            let isDueOnTime = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: false, now: lastTry + expectedWait)
            #expect(!isDueJustBefore, "wait \(expectedWait)")
            #expect(isDueOnTime, "wait \(expectedWait)")
            lastTry += expectedWait
            schedule.noteTry(on: "devbox", at: lastTry)
            schedule.noteResult(on: "devbox", status: failed)
        }
    }

    @Test func aCopyStartsTheWaitOver() {
        var schedule = HostAutoRefreshSchedule()
        _ = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: false, now: start)
        for _ in 1...3 {
            schedule.noteTry(on: "devbox", at: start)
            schedule.noteResult(on: "devbox", status: failed)
        }
        let copiedAt = start + 100
        schedule.noteResult(on: "devbox", status: .refreshed(copiedAt))
        let isDueAfterCopy = schedule.isSSHHostDue("devbox", status: .refreshed(copiedAt), needsLogIn: false, now: copiedAt + 300)
        #expect(isDueAfterCopy)

        // A later failure waits five minutes again.
        _ = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: false, now: copiedAt + 400)
        let isDueAfterNewFailure = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: false, now: copiedAt + 700)
        #expect(isDueAfterNewFailure)
    }

    /// Refreshing without a login only fails again; the host waits for Connect….
    @Test func aHostWaitingForConnectIsLeftAlone() {
        var schedule = HostAutoRefreshSchedule()
        _ = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: true, now: start)
        let isDueADayLater = schedule.isSSHHostDue("devbox", status: failed, needsLogIn: true, now: start + 86_400)
        #expect(!isDueADayLater)
    }
}
