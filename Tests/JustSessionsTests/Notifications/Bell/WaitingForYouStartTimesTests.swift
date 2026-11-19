import Foundation
import Testing

@testable import JustSessions

struct WaitingForYouStartTimesTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    /// The marks `UnseenFinishedTurns` leaves after `source` finished a turn out of view.
    private static func unseen(_ source: SessionAttentionSource) -> UnseenFinishedTurns {
        var unseen = UnseenFinishedTurns()
        unseen.update(
            after: [.init(source: source, activity: .idle)],
            events: [SessionAttentionEvent(source: source, reason: .finishedTurn)],
            isInView: { _ in false }
        )
        return unseen
    }

    @Test func aWaitKeepsTheTimeItStartedForAsLongAsItGoesOn() {
        var startTimes = WaitingForYouStartTimes()
        let source = SessionAttentionSource.tab(id: UUID(), conversationID: "a")

        startTimes.update(after: [.init(source: source, activity: .working)], unseenFinishedTurns: .init(), at: Self.at(0))
        #expect(startTimes.startTime(of: source) == nil)
        startTimes.update(
            after: [.init(source: source, activity: .needsInput(reason: "input needed"))],
            unseenFinishedTurns: .init(),
            at: Self.at(1)
        )
        #expect(startTimes.startTime(of: source) == Self.at(1))
        // The CLI words what it waits for differently, and still waits.
        startTimes.update(
            after: [.init(source: source, activity: .needsInput(reason: "permission prompt"))],
            unseenFinishedTurns: .init(),
            at: Self.at(2)
        )
        #expect(startTimes.startTime(of: source) == Self.at(1))

        startTimes.update(after: [.init(source: source, activity: .working)], unseenFinishedTurns: .init(), at: Self.at(3))
        #expect(startTimes.startTime(of: source) == nil)
    }

    @Test func aTurnFinishedOutOfViewWaitsUntilItIsSeen() {
        var startTimes = WaitingForYouStartTimes()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")
        let idle = [SessionActivityObservation(source: source, activity: .idle)]

        startTimes.update(after: idle, unseenFinishedTurns: Self.unseen(source), at: Self.at(1))
        startTimes.update(after: idle, unseenFinishedTurns: Self.unseen(source), at: Self.at(2))
        #expect(startTimes.startTime(of: source) == Self.at(1))

        startTimes.update(after: idle, unseenFinishedTurns: .init(), at: Self.at(3))
        #expect(startTimes.startTime(of: source) == nil)
    }

    @Test func aCLIThatStopsForYourAnswerAfterFinishingATurnStartsWaitingAgain() {
        var startTimes = WaitingForYouStartTimes()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")

        startTimes.update(after: [.init(source: source, activity: .idle)], unseenFinishedTurns: Self.unseen(source), at: Self.at(1))
        startTimes.update(
            after: [.init(source: source, activity: .needsInput(reason: nil))],
            unseenFinishedTurns: Self.unseen(source),
            at: Self.at(2)
        )
        #expect(startTimes.startTime(of: source) == Self.at(2))
    }

    @Test func aCLIThatTellsNothingForAMomentKeepsWaiting() {
        var startTimes = WaitingForYouStartTimes()
        let source = SessionAttentionSource.tab(id: UUID(), conversationID: "a")

        startTimes.update(
            after: [.init(source: source, activity: .needsInput(reason: nil))],
            unseenFinishedTurns: .init(),
            at: Self.at(1)
        )
        startTimes.update(after: [.init(source: source, activity: nil)], unseenFinishedTurns: .init(), at: Self.at(2))
        startTimes.update(
            after: [.init(source: source, activity: .needsInput(reason: nil))],
            unseenFinishedTurns: .init(),
            at: Self.at(3)
        )
        #expect(startTimes.startTime(of: source) == Self.at(1))
    }

    @Test func aCLIThatStopsRunningIsForgotten() {
        var startTimes = WaitingForYouStartTimes()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")
        let waiting = [SessionActivityObservation(source: source, activity: .needsInput(reason: nil))]

        startTimes.update(after: waiting, unseenFinishedTurns: .init(), at: Self.at(1))
        startTimes.update(after: [], unseenFinishedTurns: .init(), at: Self.at(2))
        #expect(startTimes.startTime(of: source) == nil)
        startTimes.update(after: waiting, unseenFinishedTurns: .init(), at: Self.at(3))
        #expect(startTimes.startTime(of: source) == Self.at(3))
    }

    @Test func aWaitKeepsItsTimeWhenItsTabLearnsItsSessionAndWhenTheTabClosesWithItsCLIInTmux() {
        var startTimes = WaitingForYouStartTimes()
        let tabID = UUID()
        let newSessionsTab = SessionAttentionSource.tab(id: tabID, conversationID: nil)
        let linkedTab = SessionAttentionSource.tab(id: tabID, conversationID: "a")
        let detached = SessionAttentionSource.detachedTmux(conversationID: "a")

        startTimes.update(
            after: [.init(source: newSessionsTab, activity: .needsInput(reason: nil))],
            unseenFinishedTurns: .init(),
            at: Self.at(1)
        )
        startTimes.update(
            after: [.init(source: linkedTab, activity: .needsInput(reason: nil))],
            unseenFinishedTurns: .init(),
            at: Self.at(2)
        )
        #expect(startTimes.startTime(of: linkedTab) == Self.at(1))
        startTimes.update(
            after: [.init(source: detached, activity: .needsInput(reason: nil))],
            unseenFinishedTurns: .init(),
            at: Self.at(3)
        )
        #expect(startTimes.startTime(of: detached) == Self.at(1))
    }
}
