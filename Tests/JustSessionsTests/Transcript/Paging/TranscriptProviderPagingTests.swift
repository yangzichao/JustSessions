import Foundation
import Testing
@testable import JustSessions

struct TranscriptProviderPagingTests {
    @Test func claudeAndKiroRetainTheirExistingFilteringAndToolSummaries() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try Data(KiroTranscriptSamples.lines.joined(separator: "\n").utf8).write(to: fixture.file)
        let kiro = try await TranscriptPageSource(file: fixture.file, provider: .kiro).read(.latest)
        #expect(kiro.entries.map(\.content) == (try KiroTranscriptReader().read(fixture.file)).entries.map(\.content))
        let lines = [
            #"{"type":"user","message":{"content":"Hello"}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"First"},{"type":"tool_use","name":"read","input":{"path":"a.swift"}},{"type":"text","text":"Second"}]}}"#,
            #"{"type":"user","message":{"content":[{"type":"tool_result","content":"hidden"}]}}"#,
        ]
        try Data(lines.joined(separator: "\n").utf8).write(to: fixture.file)
        var limits = TranscriptPageLimits()
        limits.targetEntryCount = 1
        let source = TranscriptPageSource(file: fixture.file, provider: .claude, limits: limits)
        let latest = try await source.read(.latest)
        #expect(latest.entries.count == 3) // All parts of one record stay together.
        let first = try await source.read(.before(latest.records.lowerBound))
        #expect((first.entries + latest.entries).map(\.content) == (try ClaudeTranscriptReader().read(fixture.file)).entries.map(\.content))
    }

    /// A subagent's own transcript is all sidechain records, which a session's transcript leaves out.
    @Test func aClaudeSubagentsTranscriptShowsItsSidechainRecords() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let lines = [
            #"{"type":"user","isSidechain":true,"message":{"content":"Fix the refund bug"}}"#,
            #"{"type":"assistant","isSidechain":true,"message":{"content":[{"type":"text","text":"Fixed"}]}}"#,
        ]
        try Data(lines.joined(separator: "\n").utf8).write(to: fixture.file)
        let subagent = Conversation.fixture(provider: .claude, sourceFile: fixture.file, parentSessionID: UUID().uuidString)

        let paged = try await TranscriptPageSource(file: fixture.file, provider: .claude, isSubagentTranscript: true).read(.latest)
        let loaded = try await TranscriptLoader.load(subagent)
        let asSession = try await TranscriptPageSource(file: fixture.file, provider: .claude).read(.latest)

        #expect(paged.entries.map(\.content) == [.userMessage("Fix the refund bug"), .assistantMessage("Fixed")])
        #expect(loaded.entries.map(\.content) == paged.entries.map(\.content))
        #expect(asSession.entries.isEmpty)
    }

    /// A turn's label depends on the entry before it in the session, not on whether the page holding that entry is
    /// loaded, so no entry gains or loses its label, and moves what is below it, as pages load and leave.
    @Test func turnLabelsDoNotDependOnWhichPagesAreLoaded() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let lines = [
            #"{"type":"user","message":{"content":"Question"}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"First"}]}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"Second"}]}}"#,
            #"{"type":"system","content":"Hidden between pages"}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"Third"}]}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"Fourth"}]}}"#,
        ]
        try Data(lines.joined(separator: "\n").utf8).write(to: fixture.file)
        var limits = TranscriptPageLimits()
        limits.targetEntryCount = 2
        let source = TranscriptPageSource(file: fixture.file, provider: .claude, limits: limits)

        let latest = try await source.read(.latest)
        let earlier = try await source.read(.before(latest.records.lowerBound))

        // The record just before the latest page shows nothing, so its speaker comes from the one before that.
        #expect(latest.precedingSpeaker == 1)
        #expect(earlier.precedingSpeaker == 0)
        let alone = TranscriptPageAssembler.transcript(pages: [latest])
        let joined = TranscriptPageAssembler.transcript(pages: [earlier, latest])
        #expect(alone.entries.map(\.startsTurn) == [false, false])
        #expect(joined.entries.map(\.startsTurn) == [true, false, false, false])
        #expect(TranscriptPageAssembler.transcript(pages: [earlier]).entries.map(\.startsTurn) == [true, false])
    }

    @Test func piPagesOnlyTheActiveBranchIncludingReorderedJSON() async throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let lines = [
            #"{"type":"session","version":3}"#,
            #"{"type":"message","id":"a","parentId":null,"timestamp":"2026-10-02T12:00:00Z","message":{"role":"user","content":"Start"}}"#,
            #"{"type":"message","id":"abandoned","parentId":"a","message":{"role":"user","content":"Not on active branch"}}"#,
            #"{"message":{"role":"user","content":"New branch"},"parentId":"a","id":"b","type":"message"}"#,
            #"{"type":"message","id":"c","parentId":"b","message":{"role":"assistant","content":[{"type":"text","text":"Reply"}]}}"#,
        ]
        try Data(lines.joined(separator: "\n").utf8).write(to: fixture.file)
        var limits = TranscriptPageLimits()
        limits.targetEntryCount = 1
        let source = TranscriptPageSource(file: fixture.file, provider: .pi, limits: limits)
        let last = try await source.read(.latest)
        let middle = try await source.read(.before(last.records.lowerBound))
        let first = try await source.read(.before(middle.records.lowerBound))
        #expect((first.entries + middle.entries + last.entries).map(\.content) == [.userMessage("Start"), .userMessage("New branch"), .assistantMessage("Reply")])
        #expect(first.hasEarlier == false)
        #expect(last.hasLater == false)
        #expect(try await source.read(.around(middle.entries[0].id)).entries[0].id == middle.entries[0].id)
    }

    @Test func antigravityPagesSparseStepIDsWithoutShowingClearedPrompts() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: directory)
        try fixture.appendPrompt("Second", index: 10)
        try fixture.appendPrompt("Cleared", index: 20, status: 5)
        try fixture.appendPrompt("Latest", index: 30)
        var limits = TranscriptPageLimits()
        limits.targetEntryCount = 1
        let source = TranscriptPageSource(file: fixture.databaseFile, provider: .antigravity, limits: limits)
        let latest = try await source.read(.latest)
        let previous = try await source.read(.before(latest.records.lowerBound))
        #expect(latest.entries.map(\.content) == [.userMessage("Latest")])
        #expect(previous.entries.map(\.content) == [.userMessage("Second")])
        #expect(try await source.read(.around(previous.entries[0].id)).entries[0].id == previous.entries[0].id)
    }
}
