import Testing
@testable import JustSessions

@MainActor
struct TranscriptEntriesStackTests {
    /// Scrolling updates the reader's view with the same transcript, so the stack compares equal and SwiftUI leaves every
    /// entry's layout alone. A new page, provider, or reader must update it.
    @Test func comparesItsInputs() {
        let controller = TranscriptScrollPositionController(
            conversationID: "entries-stack", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom
        )
        let transcript = TranscriptScrollViewFixture.transcript(count: 3)
        let stack = TranscriptEntriesStack(transcript: transcript, provider: .codex, positionController: controller)

        #expect(stack == TranscriptEntriesStack(transcript: transcript, provider: .codex, positionController: controller))
        #expect(stack != TranscriptEntriesStack(transcript: TranscriptScrollViewFixture.transcript(count: 4), provider: .codex, positionController: controller))
        #expect(stack != TranscriptEntriesStack(transcript: transcript, provider: .claude, positionController: controller))
        #expect(stack != TranscriptEntriesStack(
            transcript: transcript, provider: .codex,
            positionController: TranscriptScrollPositionController(
                conversationID: "entries-stack", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom
            )
        ))
    }
}
