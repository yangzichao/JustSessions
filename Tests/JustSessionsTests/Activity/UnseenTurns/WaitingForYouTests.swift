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

    @Test func tellsWhyACLIWaitsOnYou() {
        #expect(
            WaitingForYou.reason(activity: .needsInput(reason: "input needed"), hasUnseenFinishedTurn: true)
                == .needsInput(reason: "input needed"))
        #expect(WaitingForYou.reason(activity: .idle, hasUnseenFinishedTurn: true) == .finishedTurn)
        #expect(WaitingForYou.reason(activity: nil, hasUnseenFinishedTurn: true) == .finishedTurn)
        #expect(WaitingForYou.reason(activity: .idle, hasUnseenFinishedTurn: false) == nil)
        #expect(WaitingForYou.reason(activity: .working, hasUnseenFinishedTurn: true) == nil)
    }
}
