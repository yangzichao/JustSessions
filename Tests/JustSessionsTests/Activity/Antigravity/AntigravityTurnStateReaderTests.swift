import Foundation
import Testing

@testable import JustSessions

struct AntigravityTurnStateReaderTests {
    private let firstPromptAt = Date(timeIntervalSince1970: 1_790_400_000.25)

    @Test func followsTurnsAndApprovalsAsAntigravityWritesThem() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        #expect(state(of: fixture) == .inTurn(startedAt: firstPromptAt, isWaitingForApproval: false))

        try fixture.appendStep(type: 15, index: 1)
        try fixture.appendStep(type: 132, index: 2, status: 9)
        #expect(state(of: fixture) == .inTurn(startedAt: firstPromptAt, isWaitingForApproval: true))

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
