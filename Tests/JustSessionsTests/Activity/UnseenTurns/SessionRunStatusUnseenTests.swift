import Testing
@testable import JustSessions

struct SessionRunStatusUnseenTests {
    @Test func aCLIBetweenTurnsShowsTheTurnYouHaveNotSeen() {
        #expect(SessionRunStatus.running(.idle).markingUnseenFinishedTurn(true) == .finishedUnseen)
        #expect(SessionRunStatus.running(nil).markingUnseenFinishedTurn(true) == .finishedUnseen)
        #expect(SessionRunStatus.running(.idle).markingUnseenFinishedTurn(false) == .running(.idle))
    }

    @Test func workAnAnswerYouOweOrAnEndedCLIShowsInstead() {
        #expect(SessionRunStatus.running(.working).markingUnseenFinishedTurn(true) == .running(.working))
        #expect(SessionRunStatus.running(.needsInput(reason: nil)).markingUnseenFinishedTurn(true) == .running(.needsInput(reason: nil)))
        #expect(SessionRunStatus.ended.markingUnseenFinishedTurn(true) == .ended)
        #expect(SessionRunStatus.waitingToBeShown.markingUnseenFinishedTurn(true) == .waitingToBeShown)
    }
}
