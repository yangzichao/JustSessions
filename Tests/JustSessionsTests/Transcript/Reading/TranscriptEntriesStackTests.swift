import Testing

@testable import JustSessions

@MainActor
struct TranscriptEntriesStackTests {
    @Test func comparesItsInputs() {
        let controller = TranscriptScrollPositionController(
            conversationID: "entries-stack", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom
        )
        let transcript = TranscriptScrollViewFixture.transcript(count: 3)
        let stack = TranscriptEntriesStack(transcript: transcript, provider: .codex, positionController: controller)

        #expect(stack == TranscriptEntriesStack(transcript: transcript, provider: .codex, positionController: controller))
        #expect(
            stack
                != TranscriptEntriesStack(
                    transcript: TranscriptScrollViewFixture.transcript(count: 4), provider: .codex, positionController: controller))
        #expect(stack != TranscriptEntriesStack(transcript: transcript, provider: .claude, positionController: controller))
        #expect(
            stack
                != TranscriptEntriesStack(
                    transcript: transcript, provider: .codex,
                    positionController: TranscriptScrollPositionController(
                        conversationID: "entries-stack", positionStore: TranscriptReadingPositionStore(), initialPosition: .bottom
                    )
                ))
    }
}
