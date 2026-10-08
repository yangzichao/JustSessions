import Foundation
import Testing
@testable import JustSessions

struct UnseenFinishedTurnsTests {
    private static func finished(_ source: SessionAttentionSource) -> SessionAttentionEvent {
        SessionAttentionEvent(source: source, reason: .finishedTurn)
    }

    @Test func aTurnFinishedOutOfViewStaysUnseenUntilItsTerminalIsInView() {
        var unseen = UnseenFinishedTurns()
        let source = SessionAttentionSource.tab(id: UUID(), conversationID: "a")
        let idle = [SessionActivityObservation(source: source, activity: .idle)]

        unseen.update(after: idle, events: [Self.finished(source)], isInView: { _ in false })
        #expect(unseen.contains(source))
        unseen.update(after: idle, events: [], isInView: { _ in false })
        #expect(unseen.contains(source))
        unseen.update(after: idle, events: [], isInView: { _ in true })
        #expect(!unseen.contains(source))
        #expect(unseen.isEmpty)
    }

    @Test func aTurnFinishedInViewIsSeen() {
        var unseen = UnseenFinishedTurns()
        let source = SessionAttentionSource.tab(id: UUID(), conversationID: "a")

        unseen.update(
            after: [.init(source: source, activity: .idle)],
            events: [Self.finished(source)],
            isInView: { _ in true }
        )
        #expect(!unseen.contains(source))
    }

    @Test func aCLIStoppingForYourAnswerIsNotMarked() {
        var unseen = UnseenFinishedTurns()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")

        unseen.update(
            after: [.init(source: source, activity: .needsInput(reason: nil))],
            events: [SessionAttentionEvent(source: source, reason: .needsInput(reason: nil))],
            isInView: { _ in false }
        )
        #expect(!unseen.contains(source))
    }

    @Test func aNewTurnStartingOutOfViewKeepsTheMark() {
        var unseen = UnseenFinishedTurns()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")

        unseen.update(after: [.init(source: source, activity: .idle)], events: [Self.finished(source)], isInView: { _ in false })
        unseen.update(after: [.init(source: source, activity: .working)], events: [], isInView: { _ in false })
        #expect(unseen.contains(source))
    }

    @Test func aCLIThatStopsRunningIsForgotten() {
        var unseen = UnseenFinishedTurns()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")

        unseen.update(after: [.init(source: source, activity: .idle)], events: [Self.finished(source)], isInView: { _ in false })
        unseen.update(after: [], events: [], isInView: { _ in false })
        // A later CLI of the same session starts seen.
        unseen.update(after: [.init(source: source, activity: .idle)], events: [], isInView: { _ in false })
        #expect(!unseen.contains(source))
    }

    @Test func aTabStaysUnseenOnceItLearnsItsSessionAndAfterItClosesWithItsCLILeftInTmux() {
        var unseen = UnseenFinishedTurns()
        let tabID = UUID()
        let newSessionTab = SessionAttentionSource.tab(id: tabID, conversationID: nil)
        let linkedTab = SessionAttentionSource.tab(id: tabID, conversationID: "a")
        let detached = SessionAttentionSource.detachedTmux(conversationID: "a")

        unseen.update(
            after: [.init(source: newSessionTab, activity: .idle)],
            events: [Self.finished(newSessionTab)],
            isInView: { _ in false }
        )
        unseen.update(after: [.init(source: linkedTab, activity: .idle)], events: [], isInView: { _ in false })
        #expect(unseen.contains(linkedTab))
        unseen.update(after: [.init(source: detached, activity: .idle)], events: [], isInView: { _ in false })
        #expect(unseen.contains(detached))
    }

    @Test func reattachingAndLookingMarksTheSessionSeen() {
        var unseen = UnseenFinishedTurns()
        let detached = SessionAttentionSource.detachedTmux(conversationID: "a")
        let reattachedTab = SessionAttentionSource.tab(id: UUID(), conversationID: "a")

        unseen.update(after: [.init(source: detached, activity: .idle)], events: [Self.finished(detached)], isInView: { _ in false })
        #expect(unseen.contains(reattachedTab))
        unseen.markSeen(reattachedTab)
        #expect(!unseen.contains(detached))
    }

    @Test func marksEachCLIOnItsOwn() {
        var unseen = UnseenFinishedTurns()
        let first = SessionAttentionSource.tab(id: UUID(), conversationID: "a")
        let second = SessionAttentionSource.detachedTmux(conversationID: "b")
        let observations: [SessionActivityObservation] = [.init(source: first, activity: .idle), .init(source: second, activity: .idle)]

        unseen.update(after: observations, events: [Self.finished(first), Self.finished(second)], isInView: { _ in false })
        unseen.markSeen(first)
        #expect(!unseen.contains(first))
        #expect(unseen.contains(second))
    }
}
