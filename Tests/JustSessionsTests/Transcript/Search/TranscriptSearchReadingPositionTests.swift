import Testing

@testable import JustSessions

@MainActor
struct TranscriptSearchReadingPositionTests {
    @Test func selectedOccurrenceSetsTheOffsetInsideATallEntry() async throws {
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let conversation = TranscriptScrollViewFixture.conversation("find-inside-tall-entry")
        let tallText =
            (0..<80).map { "Line \($0) before the selected occurrence." }.joined(separator: "\n")
            + "\nThe selected needle is here."
        let transcript = TranscriptContent(
            entries: TranscriptScrollViewFixture.transcript().entries.map { entry in
                guard entry.id == 40 else { return entry }
                return TranscriptEntry(id: entry.id, content: .userMessage(tallText), timestamp: nil, startsTurn: true)
            }, omittedEntryCount: 0)
        let searchState = TranscriptSearchState()
        searchState.reveal("needle", at: 40)
        let scrollView = try await fixture.show(conversation, transcript: transcript, searchState: searchState)

        try await fixture.waitUntil {
            guard searchState.selectedMatch?.entryIndex == 40,
                let expected = fixture.expectedPositionForSelectedSearchMatch(in: scrollView, entryIndex: 40),
                let visible = fixture.visiblePosition(in: scrollView),
                case .entry(let index, let offset) = visible,
                case .entry(_, let expectedOffset) = expected
            else { return false }
            return index == 40 && expectedOffset > scrollView.contentView.bounds.height
                && abs(offset - expectedOffset) < 1
        }

        let expected = try #require(fixture.expectedPositionForSelectedSearchMatch(in: scrollView, entryIndex: 40))
        #expect(fixture.visiblePosition(in: scrollView) == expected)
    }
}
