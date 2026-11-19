import Foundation
import Testing

@testable import JustSessions

struct WorkspaceNavigationHistoryTests {
    private let tabA = WorkspaceLocation.tab(UUID())
    private let tabB = WorkspaceLocation.tab(UUID())
    private let sessionC = WorkspaceLocation.conversation("claude:c")
    private let sessionD = WorkspaceLocation.conversation("codex:d")
    private let canShowAll: (WorkspaceLocation) -> Bool = { _ in true }

    @Test func backAndForwardMoveAlongTheHistoryWithoutChangingIt() {
        var history = WorkspaceNavigationHistory()
        for location in [tabA, sessionC, tabB] { history.record(location) }
        #expect(history.backEntryIndices(shown: tabB, canShow: canShowAll) == [1, 0])
        #expect(history.forwardEntryIndices(shown: tabB, canShow: canShowAll).isEmpty)

        history.move(to: 1)
        history.record(sessionC)
        #expect(history.entries == [tabA, sessionC, tabB])
        #expect(history.backEntryIndices(shown: sessionC, canShow: canShowAll) == [0])
        #expect(history.forwardEntryIndices(shown: sessionC, canShow: canShowAll) == [2])
    }

    @Test func showingANewPlaceAfterGoingBackDropsTheForwardEntries() {
        var history = WorkspaceNavigationHistory()
        for location in [tabA, sessionC, tabB] { history.record(location) }
        history.move(to: 0)
        history.record(tabA)

        history.record(sessionD)

        #expect(history.entries == [tabA, sessionD])
        #expect(history.currentIndex == 1)
        #expect(history.forwardEntryIndices(shown: sessionD, canShow: canShowAll).isEmpty)
    }

    @Test func showingThePlaceBeforeOtherThanByBackRecordsItAgain() {
        var history = WorkspaceNavigationHistory()
        for location in [tabA, tabB, tabA] { history.record(location) }
        #expect(history.entries == [tabA, tabB, tabA])
        history.record(tabA)
        #expect(history.entries == [tabA, tabB, tabA])
    }

    @Test func movingBetweenPlacesOnScreenTogetherReplacesTheCurrentEntryAndKeepsForward() {
        var history = WorkspaceNavigationHistory()
        history.replaceCurrent(with: tabA)
        #expect(history.entries == [tabA])

        history.record(sessionC)
        history.move(to: 0)
        history.replaceCurrent(with: tabB)

        #expect(history.entries == [tabB, sessionC])
        #expect(history.currentIndex == 0)
        #expect(history.forwardEntryIndices(shown: tabB, canShow: canShowAll) == [1])
    }

    @Test func passesOverPlacesThatCannotShowAndThePlaceShown() {
        var history = WorkspaceNavigationHistory()
        for location in [tabA, tabB, tabA, sessionC] { history.record(location) }
        let tabBClosed: (WorkspaceLocation) -> Bool = { $0 != tabB }

        #expect(history.backEntryIndices(shown: sessionC, canShow: tabBClosed) == [2, 0])

        history.move(to: 2)
        history.record(tabA)
        #expect(history.backEntryIndices(shown: tabA, canShow: tabBClosed).isEmpty)
        #expect(history.forwardEntryIndices(shown: tabA, canShow: tabBClosed) == [3])
    }

    @Test func withNothingShownBackGoesFirstToThePlaceShownLast() {
        var history = WorkspaceNavigationHistory()
        for location in [tabA, sessionC] { history.record(location) }

        #expect(history.backEntryIndices(shown: nil, canShow: canShowAll) == [1, 0])
    }

    @Test func emptyHistoryGoesNowhere() {
        var history = WorkspaceNavigationHistory()
        #expect(history.backEntryIndices(shown: nil, canShow: canShowAll).isEmpty)
        #expect(history.forwardEntryIndices(shown: nil, canShow: canShowAll).isEmpty)
        history.move(to: 0)
        #expect(history.currentIndex == nil)
    }

    @Test func keepsOnlyTheLatestEntries() {
        var history = WorkspaceNavigationHistory()
        let locations = (0..<(WorkspaceNavigationHistory.maximumEntryCount + 10)).map { WorkspaceLocation.conversation("s\($0)") }
        for location in locations { history.record(location) }

        #expect(history.entries == Array(locations.suffix(WorkspaceNavigationHistory.maximumEntryCount)))
        #expect(history.currentIndex == WorkspaceNavigationHistory.maximumEntryCount - 1)
    }

    @Test func theSelectedTabIsShownBeforeTheSelectedSession() {
        let tabID = UUID()
        #expect(WorkspaceLocation.shown(selectedTabID: tabID, onlySelectedConversationID: "claude:c") == .tab(tabID))
        #expect(WorkspaceLocation.shown(selectedTabID: nil, onlySelectedConversationID: "claude:c") == .conversation("claude:c"))
        #expect(WorkspaceLocation.shown(selectedTabID: nil, onlySelectedConversationID: nil) == nil)
    }
}
