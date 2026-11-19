import Foundation
import Testing

@testable import JustSessions

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

    @Test func startingAgainForgetsTheFailures() {
        var schedule = RemoteTabReconnectSchedule()
        schedule.startTrying("devbox", now: start)
        for seconds: TimeInterval in [2, 7, 17, 37] { schedule.noteFailure(on: "devbox", now: start + seconds) }

        schedule.startTrying("devbox", now: start + 40)

        #expect(schedule.isDue("devbox", now: start + 42))
        schedule.noteFailure(on: "devbox", now: start + 42)
        #expect(schedule.isDue("devbox", now: start + 47))
    }

    @Test func theNextTryLeavesOutHostsBeingAsked() {
        var schedule = RemoteTabReconnectSchedule()
        schedule.startTrying("devbox", now: start)
        schedule.startTrying("buildbox", now: start + 10)

        #expect(schedule.nextTryAt(excluding: ["devbox"]) == start + 12)
        #expect(schedule.nextTryAt(excluding: ["devbox", "buildbox"]) == nil)
    }
}
