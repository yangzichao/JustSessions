import Testing
@testable import JustSessions

struct WaitingForYouTests {
    @Test func aCLIStoppedForYourAnswerWaitsOnYouWhetherOrNotItsLastTurnWasSeen() {
        #expect(WaitingForYou.includes(activity: .needsInput(reason: "input needed"), hasUnseenFinishedTurn: false))
        #expect(WaitingForYou.includes(activity: .needsInput(reason: nil), hasUnseenFinishedTurn: true))
    }

    @Test func aCLIDoneWithATurnWaitsOnYouOnlyUntilYouSeeIt() {
        #expect(WaitingForYou.includes(activity: .idle, hasUnseenFinishedTurn: true))
        #expect(!WaitingForYou.includes(activity: .idle, hasUnseenFinishedTurn: false))
        #expect(WaitingForYou.includes(activity: nil, hasUnseenFinishedTurn: true))
        #expect(!WaitingForYou.includes(activity: nil, hasUnseenFinishedTurn: false))
    }

    @Test func aCLIAtWorkDoesNotWaitOnYou() {
        #expect(!WaitingForYou.includes(activity: .working, hasUnseenFinishedTurn: true))
        #expect(!WaitingForYou.includes(activity: .working, hasUnseenFinishedTurn: false))
    }
}
