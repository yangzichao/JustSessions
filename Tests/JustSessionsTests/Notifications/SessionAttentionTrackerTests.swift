import Foundation
import Testing
@testable import JustSessions

struct SessionAttentionTrackerTests {
    @Test func aCLIFirstSeenWaitingStaysQuietUntilItsNextTurnEnds() {
        var tracker = SessionAttentionTracker()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")

        #expect(tracker.events(after: [.init(source: source, activity: .needsInput(reason: nil))]).isEmpty)
        #expect(tracker.events(after: [.init(source: source, activity: .working)]).isEmpty)
        #expect(tracker.events(after: [.init(source: source, activity: .idle)])
            == [SessionAttentionEvent(source: source, reason: .finishedTurn)])
        #expect(tracker.events(after: [.init(source: source, activity: .idle)]).isEmpty)
    }

    @Test func aCLIThatTellsNothingForAMomentKeepsWhatItToldBefore() {
        var tracker = SessionAttentionTracker()
        let source = SessionAttentionSource.tab(id: UUID(), conversationID: "a")

        _ = tracker.events(after: [.init(source: source, activity: .working)])
        #expect(tracker.events(after: [.init(source: source, activity: nil)]).isEmpty)
        #expect(tracker.events(after: [.init(source: source, activity: .needsInput(reason: "input needed"))])
            == [SessionAttentionEvent(source: source, reason: .needsInput(reason: "input needed"))])
    }

    @Test func aCLIThatStopsRunningIsForgotten() {
        var tracker = SessionAttentionTracker()
        let source = SessionAttentionSource.detachedTmux(conversationID: "a")

        _ = tracker.events(after: [.init(source: source, activity: .working)])
        _ = tracker.events(after: [])
        // A later CLI of the same session starts out between turns; the earlier CLI's turn did not end.
        #expect(tracker.events(after: [.init(source: source, activity: .idle)]).isEmpty)
    }

    @Test func aTabClosedWithItsCLILeftRunningInTmuxStaysFollowed() {
        var tracker = SessionAttentionTracker()
        let tab = SessionAttentionSource.tab(id: UUID(), conversationID: "a")
        let detached = SessionAttentionSource.detachedTmux(conversationID: "a")

        _ = tracker.events(after: [.init(source: tab, activity: .working)])
        #expect(tracker.events(after: [.init(source: detached, activity: .idle)])
            == [SessionAttentionEvent(source: detached, reason: .finishedTurn)])
    }

    @Test func aNewSessionsTabStaysFollowedOnceItLearnsItsSession() {
        var tracker = SessionAttentionTracker()
        let tabID = UUID()

        _ = tracker.events(after: [.init(source: .tab(id: tabID, conversationID: nil), activity: .working)])
        let linkedTab = SessionAttentionSource.tab(id: tabID, conversationID: "a")
        #expect(tracker.events(after: [.init(source: linkedTab, activity: .idle)])
            == [SessionAttentionEvent(source: linkedTab, reason: .finishedTurn)])
    }

    @Test func followsEachCLIOnItsOwn() {
        var tracker = SessionAttentionTracker()
        let first = SessionAttentionSource.tab(id: UUID(), conversationID: "a")
        let second = SessionAttentionSource.detachedTmux(conversationID: "b")

        _ = tracker.events(after: [.init(source: first, activity: .working), .init(source: second, activity: .idle)])
        #expect(tracker.events(after: [.init(source: first, activity: .idle), .init(source: second, activity: .working)])
            == [SessionAttentionEvent(source: first, reason: .finishedTurn)])
    }
}
