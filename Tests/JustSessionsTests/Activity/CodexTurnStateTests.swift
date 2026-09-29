import Foundation
import Testing
@testable import JustSessions

struct CodexTurnStateTests {
    private static let startedAt = Date(timeIntervalSince1970: 1_790_000_000.5)

    @Test func aTurnStartsWithTaskStartedAndEndsWithTaskCompleteOrTurnAborted() {
        #expect(CodexTurnState(turnEventLine: Data(CodexRolloutLines.turnStarted(at: Self.startedAt).utf8)) == .inTurn(startedAt: Self.startedAt))
        #expect(CodexTurnState(turnEventLine: Data(CodexRolloutLines.turnCompleted().utf8)) == .betweenTurns)
        #expect(CodexTurnState(turnEventLine: Data(CodexRolloutLines.turnAborted().utf8)) == .betweenTurns)
        #expect(CodexTurnState(turnEventLine: Data(CodexRolloutLines.agentMessage.utf8)) == nil)
        #expect(CodexTurnState(turnEventLine: Data(CodexRolloutLines.otherLineWithATurnEventType.utf8)) == nil)
    }

    @Test func theLastTurnEventDecides() {
        let turnStarted = CodexRolloutLines.turnStarted(at: Self.startedAt)
        let turnCompleted = CodexRolloutLines.turnCompleted()

        #expect(Self.state(after: [turnStarted, CodexRolloutLines.agentMessage]) == .inTurn(startedAt: Self.startedAt))
        #expect(Self.state(after: [turnStarted, CodexRolloutLines.agentMessage, turnCompleted]) == .betweenTurns)
        #expect(Self.state(after: [turnCompleted, turnStarted]) == .inTurn(startedAt: Self.startedAt))
        #expect(Self.state(after: [turnStarted, CodexRolloutLines.turnAborted()]) == .betweenTurns)
    }

    @Test func textWithNoTurnEventTellsNothing() {
        #expect(Self.state(after: [CodexRolloutLines.sessionMeta, CodexRolloutLines.agentMessage]) == nil)
        #expect(CodexTurnState.afterLastTurnEvent(in: Data()) == nil)
    }

    @Test func linesThatOnlyLookLikeTurnEventsAreSkipped() {
        let turnStarted = CodexRolloutLines.turnStarted(at: Self.startedAt)

        #expect(Self.state(after: [turnStarted, CodexRolloutLines.outputMentioningATurnEvent]) == .inTurn(startedAt: Self.startedAt))
        #expect(Self.state(after: [turnStarted, CodexRolloutLines.otherLineWithATurnEventType]) == .inTurn(startedAt: Self.startedAt))
        #expect(Self.state(after: [turnStarted, #"{"type":"task_complete" cut short"#]) == .inTurn(startedAt: Self.startedAt))
    }

    private static func state(after lines: [String]) -> CodexTurnState? {
        CodexTurnState.afterLastTurnEvent(in: CodexRolloutLines.text(lines))
    }
}
