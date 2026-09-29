import Foundation
import Testing
@testable import JustSessions

struct CodexRolloutTurnTrackerTests {
    private static let startedAt = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func followsTurnsAsCodexAppendsThem() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rollout.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.sessionMeta], to: file)
        let tracker = CodexRolloutTurnTracker()

        // The whole file was read, and no turn has started.
        #expect(tracker.turnState(ofRolloutFile: file) == .betweenTurns)

        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnStarted(at: Self.startedAt)]), to: file)
        #expect(tracker.turnState(ofRolloutFile: file) == .inTurn(startedAt: Self.startedAt))

        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.agentMessage]), to: file)
        #expect(tracker.turnState(ofRolloutFile: file) == .inTurn(startedAt: Self.startedAt))

        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnCompleted()]), to: file)
        #expect(tracker.turnState(ofRolloutFile: file) == .betweenTurns)
    }

    @Test func completesALineCodexWasStillWriting() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rollout.jsonl")
        let turnCompleted = Data(CodexRolloutLines.turnCompleted().utf8)
        let half = turnCompleted.count / 2
        try (CodexRolloutLines.text([CodexRolloutLines.turnStarted(at: Self.startedAt)]) + turnCompleted.prefix(half)).write(to: file)
        let tracker = CodexRolloutTurnTracker()

        #expect(tracker.turnState(ofRolloutFile: file) == .inTurn(startedAt: Self.startedAt))

        try CodexRolloutLines.append(turnCompleted.dropFirst(half) + Data("\n".utf8), to: file)
        #expect(tracker.turnState(ofRolloutFile: file) == .betweenTurns)
    }

    @Test func looksAfreshAtAFileThatWasReplaced() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rollout.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.turnCompleted(), CodexRolloutLines.agentMessage], to: file)
        let tracker = CodexRolloutTurnTracker()
        #expect(tracker.turnState(ofRolloutFile: file) == .betweenTurns)

        // A shorter file in its place: what was read so far no longer lines up with it.
        try FileManager.default.removeItem(at: file)
        try CodexRolloutLines.write([CodexRolloutLines.turnStarted(at: Self.startedAt)], to: file)
        #expect(tracker.turnState(ofRolloutFile: file) == .inTurn(startedAt: Self.startedAt))
    }

    @Test func findsATurnThatStartedFurtherBackThanTheFirstLookReads() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rollout.jsonl")
        let firstStep = Int(try #require(CodexRolloutTurnTracker.firstLookByteCounts.first))
        let messagesAfterTheStart = Array(repeating: CodexRolloutLines.agentMessage, count: firstStep / CodexRolloutLines.agentMessage.utf8.count + 10)
        try CodexRolloutLines.write([CodexRolloutLines.turnStarted(at: Self.startedAt)] + messagesAfterTheStart, to: file)

        #expect(CodexRolloutTurnTracker().turnState(ofRolloutFile: file) == .inTurn(startedAt: Self.startedAt))
    }

    @Test func aFileThatCannotBeReadTellsNothing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(CodexRolloutTurnTracker().turnState(ofRolloutFile: directory.appendingPathComponent("missing.jsonl")) == nil)
    }
}
