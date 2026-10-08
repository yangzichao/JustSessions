import Testing
@testable import JustSessions

struct SessionActivitySummaryTests {
    @Test func countsEachStateAndShowsTheMostPressing() {
        let summary = SessionActivitySummary(activities: [.idle, .working, nil, .needsInput(reason: "input needed"), .working])

        #expect(summary.runningCount == 5)
        #expect(summary.mostPressingStatus == .running(.needsInput(reason: nil)))
        #expect(summary.summary == "1 needs your input, 2 working, 1 idle, 1 running")
    }

    @Test func workComesBeforeIdleAndIdleBeforeUntold() {
        #expect(SessionActivitySummary(activities: [.idle, nil, .working]).mostPressingStatus == .running(.working))
        #expect(SessionActivitySummary(activities: [nil, .idle]).mostPressingStatus == .running(.idle))
        #expect(SessionActivitySummary(activities: [nil, nil]).mostPressingStatus == .running(nil))
    }

    @Test func aTurnYouHaveNotSeenComesAfterInputAndBeforeWork() {
        let summary = SessionActivitySummary(statuses: [.running(.working), .finishedUnseen, .running(.idle), .ended])

        #expect(summary.runningCount == 3)
        #expect(summary.mostPressingStatus == .finishedUnseen)
        #expect(summary.summary == "1 not seen yet, 1 working, 1 idle")
        #expect(SessionActivitySummary(statuses: [.finishedUnseen, .running(.needsInput(reason: nil))]).mostPressingStatus
            == .running(.needsInput(reason: nil)))
    }

    @Test func wordsSeveralCLIsThatNeedYou() {
        let summary = SessionActivitySummary(activities: [.needsInput(reason: nil), .needsInput(reason: "dialog open")])

        #expect(summary.summary == "2 need your input")
    }

    @Test func noneRunning() {
        let summary = SessionActivitySummary(activities: [])

        #expect(summary.runningCount == 0)
        #expect(summary.mostPressingStatus == nil)
        #expect(summary.summary.isEmpty)
    }
}
