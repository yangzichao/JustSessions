import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TranscriptReadingPositionTests {
    @Test func positionsBelongToIndividualSessionsIncludingTheirHost() {
        let store = TranscriptReadingPositionStore()
        store.record(.entry(index: 42, offset: 173), for: "Codex:session")
        store.record(.entry(index: 8, offset: 29), for: "Codex:session@server")

        #expect(store.position(for: "Codex:session") == .entry(index: 42, offset: 173))
        #expect(store.position(for: "Codex:session@server") == .entry(index: 8, offset: 29))
        #expect(store.position(for: "Claude:session") == nil)
    }

    @Test func droppingEarlierEntriesKeepsTheOriginalMessageIndex() {
        let transcript = makeTranscript(omittedEntryCount: 20)

        #expect(TranscriptReadingPosition.entry(index: 42, offset: 173).resolved(in: transcript) == .entry(index: 42, offset: 173))
        #expect(TranscriptReadingPosition.entry(index: 8, offset: 29).resolved(in: transcript) == .entry(index: 20, offset: 0))
        #expect(TranscriptReadingPosition.entry(index: 200, offset: 29).resolved(in: transcript) == .entry(index: 69, offset: 0))
        #expect(TranscriptReadingPosition.bottom.resolved(in: transcript) == .bottom)
    }

    private func makeTranscript(omittedEntryCount: Int) -> TranscriptContent {
        TranscriptContent(entries: (0..<50).map { index in
            TranscriptEntry(id: index, content: .assistantMessage("Message \(index)"), timestamp: nil, startsTurn: true)
        }, omittedEntryCount: omittedEntryCount)
    }
}
