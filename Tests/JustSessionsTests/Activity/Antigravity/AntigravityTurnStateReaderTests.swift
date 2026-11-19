import Foundation
import Testing

@testable import JustSessions

/// Replays the rows Antigravity CLI 1.3.3 wrote in a session that ran a command you allowed, answered a second
/// prompt, and was interrupted on a third.
struct AntigravityTurnStateReaderTests {
    private let firstPromptAt = Date(timeIntervalSince1970: 1_790_400_000.25)

    @Test func followsTurnsAndApprovalsAsAntigravityWritesThem() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // The prompt is the first step, written as you send it.
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        #expect(state(of: fixture) == .inTurn(startedAt: firstPromptAt, isWaitingForApproval: false))

        // A response that asks to run a command, which waits for you to allow it.
        try fixture.appendStep(type: 15, index: 1)
        try fixture.appendStep(type: 132, index: 2, status: 9)
        #expect(state(of: fixture) == .inTurn(startedAt: firstPromptAt, isWaitingForApproval: true))

        // You allow it; the command runs, the model answers, and the turn ends at its last step.
        try AntigravitySessionFixture.execute(["UPDATE steps SET status = 3 WHERE idx = 2"], at: fixture.databaseFile)
        #expect(state(of: fixture) == .inTurn(startedAt: firstPromptAt, isWaitingForApproval: false))
        try fixture.appendStep(type: 15, index: 3)
        try fixture.appendExecution(index: 0, endingAtStep: 3)
        #expect(state(of: fixture) == .betweenTurns)

        let secondPromptAt = firstPromptAt + 60
        try fixture.appendPrompt("Reply with the single word: beta", index: 4, createdAt: secondPromptAt)
        #expect(state(of: fixture) == .inTurn(startedAt: secondPromptAt, isWaitingForApproval: false))
        try fixture.appendStep(type: 15, index: 5)
        try fixture.appendExecution(index: 1, endingAtStep: 5)
        #expect(state(of: fixture) == .betweenTurns)

        // Interrupting a turn ends it too.
        try fixture.appendPrompt("Write a 400 word essay about tmux.", index: 6, createdAt: firstPromptAt + 120)
        try fixture.appendExecution(index: 2, endingAtStep: 6, termination: 2)
        #expect(state(of: fixture) == .betweenTurns)
    }

    @Test func aTurnThatGoesOnWithoutAPromptIsUnderWay() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        try fixture.appendStep(type: 15, index: 1)
        try fixture.appendExecution(index: 0, endingAtStep: 1)
        // Antigravity can start an execution with no prompt of yours; earlier conversations hold several in a row.
        let continuedAt = firstPromptAt + 30
        try fixture.appendStep(type: 15, index: 2, createdAt: continuedAt)

        #expect(state(of: fixture) == .inTurn(startedAt: continuedAt, isWaitingForApproval: false))
    }

    @Test func aTurnEndedAtTheFirstStepNamesNoLastStep() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        try fixture.appendExecution(index: 0, endingAtStep: 0, termination: 2)

        #expect(state(of: fixture) == .betweenTurns)
    }

    @Test func aConversationWithNoStepsIsBetweenTurns() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        try AntigravitySessionFixture.execute(["DELETE FROM steps"], at: fixture.databaseFile)

        #expect(state(of: fixture) == .betweenTurns)
    }

    @Test func tellsNothingWithoutTheTablesItReads() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        try AntigravitySessionFixture.execute(["DROP TABLE executor_metadata"], at: fixture.databaseFile)

        #expect(state(of: fixture) == nil)
        #expect(AntigravityTurnStateReader.turnState(ofConversationDatabase: directory.appendingPathComponent("missing.db")) == nil)
    }

    private func state(of fixture: AntigravitySessionFixture) -> AntigravityTurnState? {
        AntigravityTurnStateReader.turnState(ofConversationDatabase: fixture.databaseFile)
    }
}
