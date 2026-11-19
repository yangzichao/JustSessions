import Foundation
import Testing

@testable import JustSessions

/// A host with dropped tabs is asked 2 seconds after the event that started the tries, then less often after each
/// failure, up to once a minute, and given up 15 minutes after that event.
struct RemoteTabReconnectScheduleTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func aHostIsFirstAskedTwoSecondsAfterTheTriesStart() {
        var schedule = RemoteTabReconnectSchedule()
        schedule.startTrying("devbox", now: start)

        #expect(!schedule.isDue("devbox", now: start + 1.9))
        #expect(schedule.isDue("devbox", now: start + 2))
        #expect(!schedule.isDue("buildbox", now: start + 2))
        #expect(schedule.nextTryAt(excluding: []) == start + 2)
    }

    @Test func aHostThatCantBeAskedWaitsTwiceAsLongAfterEachFailureUpToAMinute() {
        var schedule = RemoteTabReconnectSchedule()
        schedule.startTrying("devbox", now: start)
        var lastTry = start + 2
        for expectedWait: TimeInterval in [5, 10, 20, 40, 60, 60] {
            let keepsTrying = schedule.noteFailure(on: "devbox", now: lastTry)
            #expect(keepsTrying)
            #expect(!schedule.isDue("devbox", now: lastTry + expectedWait - 0.1), "wait \(expectedWait)")
            #expect(schedule.isDue("devbox", now: lastTry + expectedWait), "wait \(expectedWait)")
            lastTry += expectedWait
        }
    }

    @Test func theTriesGiveUpFifteenMinutesAfterTheyStarted() {
        var schedule = RemoteTabReconnectSchedule()
        schedule.startTrying("devbox", now: start)

        let keepsTryingJustBefore = schedule.noteFailure(on: "devbox", now: start + 899)
        let keepsTryingAtFifteenMinutes = schedule.noteFailure(on: "devbox", now: start + 900)
        #expect(keepsTryingJustBefore)
        #expect(!keepsTryingAtFifteenMinutes)
        #expect(schedule.hostsBeingTried.isEmpty)
        #expect(schedule.nextTryAt(excluding: []) == nil)
    }

    /// The Mac waking or the app coming forward starts over: soon, without the failures before it.
    @Test func startingAgainForgetsTheFailures() {
        var schedule = RemoteTabReconnectSchedule()
        schedule.startTrying("devbox", now: start)
        for seconds: TimeInterval in [2, 7, 17, 37] { schedule.noteFailure(on: "devbox", now: start + seconds) }

        schedule.startTrying("devbox", now: start + 40)

        #expect(schedule.isDue("devbox", now: start + 42))
        schedule.noteFailure(on: "devbox", now: start + 42)
        #expect(schedule.isDue("devbox", now: start + 47))
    }

    /// A host stays due while it is asked, so the reconnector's next wake-up leaves it out.
    @Test func theNextTryLeavesOutHostsBeingAsked() {
        var schedule = RemoteTabReconnectSchedule()
        schedule.startTrying("devbox", now: start)
        schedule.startTrying("buildbox", now: start + 10)

        #expect(schedule.nextTryAt(excluding: ["devbox"]) == start + 12)
        #expect(schedule.nextTryAt(excluding: ["devbox", "buildbox"]) == nil)
    }
}
