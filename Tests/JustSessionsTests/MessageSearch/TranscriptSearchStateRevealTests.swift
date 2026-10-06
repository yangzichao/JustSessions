import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TranscriptSearchStateRevealTests {
    private func match(record: Int, part: Int = 0) -> TranscriptSearchMatch {
        TranscriptSearchMatch(entryIndex: TranscriptPageIdentity.entryID(record: record, part: part), segmentIndex: 0, range: NSRange(location: 0, length: 5))
    }

    @Test func selectsTheMatchInTheRevealedEntry() {
        let state = TranscriptSearchState()
        state.reveal("cache", at: TranscriptPageIdentity.entryID(record: 5, part: 0))
        let revisionBefore = state.navigationRevision

        state.update(matches: [match(record: 1), match(record: 5), match(record: 9)], preservingSelection: false)

        #expect(state.isPresented)
        #expect(state.query == "cache")
        #expect(state.selectedMatch == match(record: 5))
        #expect(state.navigationRevision == revisionBefore + 1)
    }

    @Test func selectsTheNextMatchWhenTheRevealedEntryHasNone() {
        let state = TranscriptSearchState()
        state.reveal("cache", at: TranscriptPageIdentity.entryID(record: 5, part: 1))

        state.update(matches: [match(record: 1), match(record: 7)], preservingSelection: false)

        #expect(state.selectedMatch == match(record: 7))
    }

    /// The pages shown before can be searched before the pages around the entry arrive.
    @Test func theRevealedEntryIsPreferredUntilItsPagesAreSearched() {
        let state = TranscriptSearchState()
        state.reveal("cache", at: TranscriptPageIdentity.entryID(record: 50, part: 0))

        state.update(matches: [match(record: 1), match(record: 2)], preservingSelection: false)
        #expect(state.selectedMatch == match(record: 1))

        state.update(matches: [match(record: 48), match(record: 50), match(record: 60)], preservingSelection: true)
        #expect(state.selectedMatch == match(record: 50))
    }

    @Test func choosingAnotherMatchEndsThePreference() {
        let state = TranscriptSearchState()
        state.reveal("cache", at: TranscriptPageIdentity.entryID(record: 5, part: 0))
        state.update(matches: [match(record: 1), match(record: 5), match(record: 9)], preservingSelection: false)

        state.move(forward: true)
        state.update(matches: [match(record: 1), match(record: 5), match(record: 9)], preservingSelection: true)

        #expect(state.selectedMatch == match(record: 9))
    }

    @Test func aNewQueryEndsThePreference() {
        let state = TranscriptSearchState()
        state.reveal("cache", at: TranscriptPageIdentity.entryID(record: 5, part: 0))

        state.query = "cache key"
        state.update(matches: [match(record: 1), match(record: 5)], preservingSelection: false)

        #expect(state.selectedMatch == match(record: 1))
        #expect(state.preferredEntryID == nil)
    }

    @Test func aRevealLeavesTheKeyboardWhereItWasWhileFindOpensForTyping() {
        let revealed = TranscriptSearchState()
        revealed.reveal("cache", at: 0)
        #expect(!revealed.focusesFieldOnOpen)

        let opened = TranscriptSearchState()
        opened.show()
        opened.reveal("cache", at: 0)
        #expect(opened.focusesFieldOnOpen)

        revealed.close()
        revealed.show()
        #expect(revealed.focusesFieldOnOpen)
    }
}
